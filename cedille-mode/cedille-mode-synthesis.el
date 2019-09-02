;;; cedille-mode-synthesis.el --- description -*- lexical-binding: t; -*-

;;; Code:

(defun get-span-type(data)
  "Filter out special attributes from the data in a span"
  (cdr (assoc 'expected-type data)))

(defun get-span-name(data)
  (cdr (assoc 'name data)))

(defun synth-foralls(type)
  (setq type (replace-regexp-in-string "∀" "Λ" type))
  (setq type (replace-regexp-in-string "Π" "λ" type))
  (while (string-match "\\. \\([^\\.➔]*\\) ➔" type)
    (setq s0 (downcase (match-string 1 type)))
    (setq s (concatenate 'string ". λ " s0))
    (setq s1 (concatenate 'string s " : \\1 ."))
    (setq type (replace-match s1 nil nil type))
    )
  (replace-regexp-in-string "\\.[^\\.]*$" ". " type)
  ;; (setq type (replace-regexp-in-string "[\\.➔] \\([^\\.➔]*?\\) [➔]" ". λ ?\\1 ." type))
  ;; (replace-regexp-in-string "\\..*?$" "asdf" type)
  ;; (match-string )
  )

(defun cedille-mode-synth-quantifiers ()
  "This function will synthesize the proper lambdas that match
the quantifiers at the given hole"
  (interactive)
  (when se-mode-selected
    (let* ((term (se-mode-selected))
           (d (se-term-to-json term))
           (name (se-term-name term))
           (type (get-span-type d))
           (synth-type (synth-foralls type))
           )
      (when (string= name 'Hole)
        (insert-before-markers synth-type))
      )))

(provide 'cedille-mode-synthesis)
;;; cedille-mode-synthesis.el ends here

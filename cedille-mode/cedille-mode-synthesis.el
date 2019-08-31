;;; cedille-mode-synthesis.el --- description -*- lexical-binding: t; -*-

;;; Code:

(defun get-span-type(data)
  "Filter out special attributes from the data in a span"
  ;; FIXME: Change this loop with a proper filter
  (loop for (key . value) in data
        if (eq 'expected-type key)
        collecting value))

(defun cedille-mode-synth-quantifiers ()
  "This function will syntehsize the proper lambdas that match
the quantifiers at the given hole"
  (interactive)
  (when se-mode-selected
    (let* (
           (span (se-mode-selected))
           (d (se-term-to-json span))
           (txt (get-span-type d))
           )
      (while txt
        (insert (car txt))
        (setq txt (cdr txt)))
      )
  ))

(provide 'cedille-mode-synthesis)
;;; cedille-mode-synthesis.el ends here

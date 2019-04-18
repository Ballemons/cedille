import cedille-options

module interactive-cmds (options : cedille-options.options) where

open import lib
open import functions
open import cedille-types
open import conversion
open import constants
open import ctxt
open import general-util
open import is-free
open import monad-instances
open import spans options {id}
open import subst
open import syntax-util
open import to-string options
open import toplevel-state options {IO}
open import untyped-spans options {id} -- {IO}
open import parser
open import rewriting
open import rename
open import classify options {id}
import spans options {IO} as io-spans
open import datatype-functions
open import elaboration (record options {during-elaboration = ff})
open import elaboration-helpers (record options {during-elaboration = ff})
open import templates
open import erase
open import json

private

  {- Parsing -}
  
  ll-ind : ∀ {X : language-level → Set} → X ll-term → X ll-type → X ll-kind →
             (ll : language-level) → X ll
  ll-ind t T k ll-term = t
  ll-ind t T k ll-type = T
  ll-ind t T k ll-kind = k
  
  ll-lift : language-level → Set
  ll-lift = ⟦_⟧ ∘ ll-ind TERM TYPE KIND

  ll-ind' : ∀ {X : Σ language-level ll-lift → Set} → (s : Σ language-level ll-lift) → ((t : term) → X (ll-term , t)) → ((T : type) → X (ll-type , T)) → ((k : kind) → X (ll-kind , k)) → X s
  ll-ind' (ll-term , t) tf Tf kf = tf t
  ll-ind' (ll-type , T) tf Tf kf = Tf T
  ll-ind' (ll-kind , k) tf Tf kf = kf k

  ll-disambiguate : ctxt → term → maybe type
  ll-disambiguate Γ (Var pi x) = ctxt-lookup-type-var Γ x ≫=maybe λ _ → just (TpVar pi x)
  ll-disambiguate Γ (App t NotErased t') = ll-disambiguate Γ t ≫=maybe λ T →
    just (TpAppt T t')
  ll-disambiguate Γ (AppTp t T') = ll-disambiguate Γ t ≫=maybe λ T → just (TpApp T T')
  ll-disambiguate Γ (Lam pi KeptLambda pi' x (SomeClass atk) t) =
    ll-disambiguate (ctxt-tk-decl pi' x atk Γ) t ≫=maybe λ T →
    just (TpLambda pi pi' x atk T)
  ll-disambiguate Γ (Parens pi t pi') = ll-disambiguate Γ t
  ll-disambiguate Γ (Let pi _ d t) =
    ll-disambiguate (Γ' d) t ≫=maybe λ T → just (TpLet pi d T)
    where
    Γ' : defTermOrType → ctxt
    Γ' (DefTerm pi' x (SomeType T) t) = ctxt-term-def pi' localScope OpacTrans x (just t) T Γ
    Γ' (DefTerm pi' x NoType t) = ctxt-term-udef pi' localScope OpacTrans x t Γ
    Γ' (DefType pi' x k T) = ctxt-type-def pi' localScope OpacTrans x (just T) k Γ
  ll-disambiguate Γ t = nothing
  
  parse-string : (ll : language-level) → string → maybe (ll-lift ll)
  parse-string ll s = case ll-ind {λ ll → string → Either string (ll-lift ll)}
    parseTerm parseType parseKind ll s of λ {(Left e) → nothing; (Right e) → just e}
  
  ttk = "term, type, or kind"
  
  parse-err-msg : (failed-to-parse : string) → (as-a : string) → string
  parse-err-msg failed-to-parse "" =
    "Failed to parse \\\\\"" ^ failed-to-parse ^ "\\\\\""
  parse-err-msg failed-to-parse as-a =
    "Failed to parse \\\\\"" ^ failed-to-parse ^ "\\\\\" as a " ^ as-a
  
  infixr 7 _≫nothing_ _-_!_≫parse_ _!_≫error_
  _≫nothing_ : ∀{ℓ}{A : Set ℓ} → maybe A → maybe A → maybe A
  (nothing ≫nothing m₂) = m₂
  (m₁ ≫nothing m₂) = m₁
  
  _-_!_≫parse_ : ∀{A B : Set} → (string → maybe A) → string →
                  (error-msg : string) → (A → string ⊎ B) → string ⊎ B
  (f - s ! e ≫parse f') = maybe-else (inj₁ (parse-err-msg s e)) f' (f s)
  
  _!_≫error_ : ∀{E A B : Set} → maybe A → E → (A → E ⊎ B) → E ⊎ B
  (just a ! e ≫error f) = f a
  (nothing ! e ≫error f) = inj₁ e
  
  parse-try : ∀ {X : Set} → ctxt → string → maybe
                (((ll : language-level) → ll-lift ll → X) → X)
  parse-try Γ s =
    maybe-map (λ t f → maybe-else (f ll-term t) (f ll-type) (ll-disambiguate Γ t))
      (parse-string ll-term s) ≫nothing
    maybe-map (λ T f → f ll-type T) (parse-string ll-type s) ≫nothing
    maybe-map (λ k f → f ll-kind k) (parse-string ll-kind s)
  
  string-to-𝔹 : string → maybe 𝔹
  string-to-𝔹 "tt" = just tt
  string-to-𝔹 "ff" = just ff
  string-to-𝔹 _ = nothing
  
  parse-ll : string → maybe language-level
  parse-ll "term" = just ll-term
  parse-ll "type" = just ll-type
  parse-ll "kind" = just ll-kind
  parse-ll _ = nothing
  
  
  {- Local Context -}
  
  record lci : Set where
    constructor mk-lci
    field ll : string; x : var; t : string; T : string; fn : string; pi : posinfo

  data 𝕃ₛ {ℓ} (A : Set ℓ) : Set ℓ where
    [_]ₛ : A → 𝕃ₛ A
    _::ₛ_ : A → 𝕃ₛ A → 𝕃ₛ A

  headₛ : ∀ {ℓ} {A : Set ℓ} → 𝕃ₛ A → A
  headₛ [ a ]ₛ = a
  headₛ (a ::ₛ as) = a

  𝕃ₛ-to-𝕃 : ∀ {ℓ} {A : Set ℓ} → 𝕃ₛ A → 𝕃 A
  𝕃ₛ-to-𝕃 [ a ]ₛ = [ a ]
  𝕃ₛ-to-𝕃 (a ::ₛ as) = a :: 𝕃ₛ-to-𝕃 as
  
  merge-lcis-ctxt : ctxt → 𝕃 string → ctxt
  merge-lcis-ctxt c = foldl merge-lcis-ctxt' c ∘ (sort-lcis ∘ strings-to-lcis) where
    strings-to-lcis : 𝕃 string → 𝕃 lci
    strings-to-lcis ss = strings-to-lcis-h ss [] where
      strings-to-lcis-h : 𝕃 string → 𝕃 lci → 𝕃 lci
      strings-to-lcis-h (ll :: x :: t :: T :: fn :: pi :: tl) items =
        strings-to-lcis-h tl (mk-lci ll x t T fn pi :: items)
      strings-to-lcis-h _ items = items

    -- TODO: Local context information does not pass Δ information!
    -- When users are using BR-explorer to rewrite with the rec function,
    -- if they call it upon "μ' [SUBTERM] {...}", it won't work unless they say
    -- "μ'<rec/mu> [SUBTERM] {...}".
    decl-lci : posinfo → var → ctxt → ctxt
    decl-lci pi x (mk-ctxt (fn , mn , ps , q) ss is os Δ) =
      mk-ctxt (fn , mn , ps , trie-insert q x (pi % x , [])) ss is os Δ

    language-level-type-of : language-level → language-level
    language-level-type-of ll-term = ll-type
    language-level-type-of _ = ll-kind    

    merge-lci-ctxt : lci → ctxt → ctxt
    merge-lci-ctxt (mk-lci ll v t T fn pi) Γ =
      maybe-else Γ (λ Γ → Γ) (parse-ll ll ≫=maybe λ ll →
        parse-string (language-level-type-of ll) T ≫=maybe h ll (parse-string ll t)) where
      h : (ll : language-level) → maybe (ll-lift ll) →
          ll-lift (language-level-type-of ll) → maybe ctxt
      h ll-term (just t) T =
        just (ctxt-term-def pi localScope OpacTrans v (just t) (qualif-type Γ T) Γ)
      h ll-type (just T) k =
        just (ctxt-type-def pi localScope OpacTrans v (just T) (qualif-kind Γ k) Γ)
      h ll-term nothing T = just (ctxt-term-decl pi v T Γ)
      h ll-type nothing k = just (ctxt-type-decl pi v k Γ)
      h _ _ _ = nothing

    merge-lcis-ctxt' : 𝕃ₛ lci → ctxt → ctxt
    merge-lcis-ctxt' ls Γ =
      let ls' = 𝕃ₛ-to-𝕃 ls in
      foldr (merge-lci-ctxt) (foldr (λ l → decl-lci (lci.pi l) (lci.x l)) Γ ls') ls'
    
    sort-eq : ∀ {ℓ} {A : Set ℓ} → (A → A → compare-t) → 𝕃 A → 𝕃 (𝕃ₛ A)
    sort-eq {_} {A} c = foldr insert [] where
      insert : A → 𝕃 (𝕃ₛ A) → 𝕃 (𝕃ₛ A)
      insert n [] = [ [ n ]ₛ ]
      insert n (a :: as) with c (headₛ a) n
      ...| compare-eq = n ::ₛ a :: as
      ...| compare-gt = [ n ]ₛ :: a :: as
      ...| compare-lt = a :: insert n as
    
    sort-lcis : 𝕃 lci → 𝕃 (𝕃ₛ lci) -- 𝕃 lci
    sort-lcis = sort-eq λ l₁ l₂ →
      compare (posinfo-to-ℕ $ lci.pi l₁) (posinfo-to-ℕ $ lci.pi l₂)
    {-
    sort-lcis = list-merge-sort.merge-sort lci λ l l' →
                posinfo-to-ℕ (lci.pi l) > posinfo-to-ℕ (lci.pi l')
      where import list-merge-sort
    -}

  
  get-local-ctxt : ctxt → (pos : ℕ) → (local-ctxt : 𝕃 string) → ctxt
  get-local-ctxt Γ @ (mk-ctxt (fn , mn , _) _ is _ Δ) pi =
    merge-lcis-ctxt (foldr (flip ctxt-clear-symbol ∘ fst) Γ
      (flip filter (trie-mappings is) λ {(x , ci , fn' , pi') →
        fn =string fn' && posinfo-to-ℕ pi' > pi}))
  
  
  {- Helpers -}
  
  qualif-ed : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧
  qualif-ed{TERM} = qualif-term
  qualif-ed{TYPE} = qualif-type
  qualif-ed{KIND} = qualif-kind
  qualif-ed Γ e = e

  step-reduce : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧
  step-reduce Γ t =
    let t' = erase t in maybe-else t' id (step-reduceh Γ t') where
    step-reduceh : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → maybe ⟦ ed ⟧
    step-reduceh{TERM} Γ (Var pi x) = ctxt-lookup-term-var-def Γ (qualif-var Γ x)
    step-reduceh{TYPE} Γ (TpVar pi x) = ctxt-lookup-type-var-def Γ (qualif-var Γ x)
    step-reduceh{TERM} Γ (App (Lam pi b pi' x oc t) me t') = just (subst Γ t' x t)
    step-reduceh{TYPE} Γ (TpApp (TpLambda pi pi' x (Tkk _) T) T') = just (subst Γ T' x T)
    step-reduceh{TYPE} Γ (TpAppt (TpLambda pi pi' x (Tkt _) T) t) = just (subst Γ t x T)
    step-reduceh{TERM} Γ (App t me t') = step-reduceh Γ t ≫=maybe λ t → just (App t me t')
    step-reduceh{TYPE} Γ (TpApp T T') = step-reduceh Γ T ≫=maybe λ T → just (TpApp T T')
    step-reduceh{TYPE} Γ (TpAppt T t) = step-reduceh Γ T ≫=maybe λ T → just (TpAppt T t)
    step-reduceh{TERM} Γ (Lam pi b pi' x oc t) = step-reduceh (ctxt-var-decl x Γ) t ≫=maybe λ t → just (Lam pi b pi' x oc t)
    step-reduceh{TYPE} Γ (TpLambda pi pi' x atk T) = step-reduceh (ctxt-var-decl x Γ) T ≫=maybe λ T → just (TpLambda pi pi' x atk T)
    step-reduceh{TERM} Γ (Let pi _ (DefTerm pi' x ot t') t) = just (subst Γ t' x t)
    step-reduceh{TYPE} Γ (TpLet pi (DefTerm pi' x ot t) T) = just (subst Γ t x T)
    step-reduceh{TYPE} Γ (TpLet pi (DefType pi' x k T') T) = just (subst Γ T' x T)
    step-reduceh{TERM} Γ t @ (Mu _ _ _ _ _ _ _ _) = just $ hnf Γ unfold-head-one t tt
    step-reduceh{TERM} Γ t @ (Mu' _ _ _ _ _ _ _) = just $ hnf Γ unfold-head-one t tt
    step-reduceh Γ t = nothing

  parse-norm : maybeErased → string → maybe (∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧)
  parse-norm me "all" = just λ Γ t → hnf Γ (unfolding-set-erased unfold-all me) t tt
  parse-norm me "head" = just λ Γ t → hnf Γ (unfolding-set-erased unfold-head me) t tt
  parse-norm me "once" = just λ Γ → step-reduce Γ ∘ erase
  parse-norm _ _ = nothing

  parse-norm-err = "normalization method (all, head, once)"


  {- Command Executors -}
  
  normalize-cmd : ctxt → (str ll pi norm : string) → 𝕃 string → string ⊎ tagged-val
  normalize-cmd Γ str ll pi norm ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    string-to-ℕ - pi ! "natural number" ≫parse λ sp →
    parse-norm tt - norm ! parse-norm-err ≫parse λ norm →
    parse-string ll' - str ! ll ≫parse λ t →
      let Γ' = get-local-ctxt Γ sp ls in
    inj₂ (to-string-tag "" Γ' (norm Γ' (qualif-ed Γ' t)))
  
  normalize-prompt : ctxt → (str norm : string) → 𝕃 string → string ⊎ tagged-val
  normalize-prompt Γ str norm ls =
    parse-norm tt - norm ! parse-norm-err ≫parse λ norm →
    let Γ' = merge-lcis-ctxt Γ ls in
    parse-try Γ' - str ! ttk ≫parse λ f → f λ ll t →
    inj₂ (to-string-tag "" Γ' (norm Γ' (qualif-ed Γ' t)))
  
  erase-cmd : ctxt → (str ll pi : string) → 𝕃 string → string ⊎ tagged-val
  erase-cmd Γ str ll pi ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    string-to-ℕ - pi ! "natural number" ≫parse λ sp →
    parse-string ll' - str ! ll ≫parse λ t →
    let Γ' = get-local-ctxt Γ sp ls in
    inj₂ (to-string-tag "" Γ' (erase (qualif-ed Γ' t)))
  
  erase-prompt : ctxt → (str : string) → 𝕃 string → string ⊎ tagged-val
  erase-prompt Γ str ls =
    let Γ' = merge-lcis-ctxt Γ ls in
    parse-try Γ' - str ! ttk ≫parse λ f → f λ ll t →
    inj₂ (to-string-tag "" Γ' (erase (qualif-ed Γ' t)))

  private
    cmds-to-escaped-string : cmds → strM
    cmds-to-escaped-string (c :: cs) = cmd-to-string c $ strAdd "\\n\\n" ≫str cmds-to-escaped-string cs
    cmds-to-escaped-string [] = strEmpty

  data-cmd : ctxt → (encoding name ps is cs : string) → string ⊎ tagged-val
  data-cmd Γ encodingₛ x psₛ isₛ csₛ =
    string-to-𝔹 - encodingₛ ! "boolean" ≫parse λ encoding →
    parse-string ll-kind - psₛ ! "kind" ≫parse λ psₖ →
    parse-string ll-kind - isₛ ! "kind" ≫parse λ isₖ →
    parse-string ll-kind - csₛ ! "kind" ≫parse λ csₖ →
    let ps = map (λ {(Index x atk) → Decl posinfo-gen posinfo-gen Erased x atk posinfo-gen}) $ kind-to-indices Γ psₖ
        cs = map (λ {(Index x (Tkt T)) → Ctr posinfo-gen x T; (Index x (Tkk k)) → Ctr posinfo-gen x $ mtpvar "ErrorExpectedTypeNotKind"}) $ kind-to-indices empty-ctxt csₖ
        is = kind-to-indices (add-ctrs-to-ctxt cs $ add-params-to-ctxt ps Γ) isₖ
        picked-encoding = if encoding then mendler-encoding else mendler-simple-encoding
        defs = datatype-encoding.mk-defs picked-encoding Γ $ Data x ps is cs in
    inj₂ $ strRunTag "" Γ $ cmds-to-escaped-string $ fst defs

{-
  br-cmd : ctxt → (str qed : string) → 𝕃 string → IO ⊤
  br-cmd Γ str qed ls =
    let Γ' = merge-lcis-ctxt Γ ls in
    maybe-else
      (return (io-spans.spans-to-rope (io-spans.global-error "Parse error" nothing)))
      (λ s → s >>= return ∘ io-spans.spans-to-rope)
      (parse-try {maybe (IO io-spans.spans)} Γ' str ≫=maybe λ f → f λ where
         ll-term t → just (untyped-term-spans t Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
         ll-type T →
           parse-string ll-term qed ≫=maybe λ q →
           case check-term q (just $ qualif-type Γ' T) Γ' empty-spans of λ where
             (triv , _ , ss @ (regular-spans nothing _)) →
               just (putStrLn "inhabited: Type inhabited" >> untyped-type-spans T Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
             (triv , _ , _) →
               just (untyped-type-spans T Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
         ll-kind k →
           just (untyped-kind-spans k Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd)))
      >>= putRopeLn

  conv-cmd : ctxt → (ll str1 str2 : string) → 𝕃 string → string ⊎ tagged-val
  conv-cmd Γ ll s1 s2 ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    parse-string ll' - s1 ! ll ≫parse λ t1 →
    parse-string ll' - s2 ! ll ≫parse λ t2 →
    let Γ' = merge-lcis-ctxt Γ ls; t2 = erase (qualif-ed Γ' t2) in
    if ll-ind {λ ll → ctxt → ll-lift ll → ll-lift ll → 𝔹}
         conv-term conv-type conv-kind ll' Γ' (qualif-ed Γ' t1) t2
      then inj₂ (to-string-tag "" Γ' t2)
      else inj₁ "Inconvertible"

  rewrite-cmd : ctxt → (span-str : string) → (input-str : string) →
                (use-hnf : string) → (local-ctxt : 𝕃 string) → string ⊎ tagged-val
  rewrite-cmd Γ ss is hd ls =
    string-to-𝔹 - hd ! "boolean" ≫parse λ use-hnf →
    let Γ = merge-lcis-ctxt Γ ls in
    parse-try Γ - ss ! ttk ≫parse λ f → f λ ll ss →
    parse-try Γ - is ! ttk ≫parse λ f → (f λ where
      ll-term t → (case check-term t nothing Γ empty-spans of λ
          {(just T , _ , regular-spans nothing _) → just T; _ → nothing})
        ! "Error when synthesizing a type for the input term" ≫error λ where
          (TpEq _ t₁ t₂ _) → inj₂ (t₁ , t₂)
          _ → inj₁ "Synthesized a non-equational type from the input term"
      ll-type (TpEq _ t₁ t₂ _) → inj₂ (t₁ , t₂)
      ll-type _ → inj₁ "Expected the input expression to be a term, but got a type"
      ll-kind _ → inj₁ "Expected the input expression to be a term, but got a kind")
    ≫=⊎ uncurry λ t₁ t₂ →
    let x = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt
        f = ll-ind {λ ll → ctxt → term → var → ll-lift ll → ll-lift ll}
              subst subst subst ll Γ t₂ x in
    case (ll-ind {λ ll → ll-lift ll → ctxt → 𝔹 → maybe stringset →
                         maybe term → term → var → ℕ → ll-lift ll × ℕ × ℕ}
      rewrite-term rewrite-type rewrite-kind ll (qualif-ed Γ ss) Γ
      use-hnf nothing (just (Beta posinfo-gen NoTerm NoTerm)) t₁ x 0) of λ where
        (e , 0 , _) → inj₁ "No rewrites could be performed"
        (e , _ , _) → inj₂ (strRunTag "" Γ
          (to-stringe (erase (f e)) ≫str strAdd "§" ≫str strAdd x ≫str strAdd "§" ≫str to-stringe (erase e)))
-}
  pretty-cmd : filepath → filepath → IO string
  pretty-cmd src-fn dest-fn =
    readFiniteFile src-fn >>= λ src →
    case parseStart src of λ where
      (Left (Left p)) → return ("Lexical error at position " ^ p)
      (Left (Right p)) → return ("Parse error at position " ^ p)
      (Right file) → writeFile dest-fn "" >> writeRopeToFile dest-fn (to-string.strRun empty-ctxt (to-string.file-to-string file)) >> return "Finished"
    where import to-string (record options {pretty-print = tt}) as to-string
  
  
  {- Commands -}
  
  tv-to-rope : string ⊎ tagged-val → rope
  tv-to-rope (inj₁ s) = [[ "{\"error\":\"" ]] ⊹⊹ [[ s ]] ⊹⊹ [[ "\"}" ]]
  tv-to-rope (inj₂ (_ , v , ts)) =
    [[ "{" ]] ⊹⊹ tagged-val-to-rope 0 ("value" , v , ts) ⊹⊹ [[ "}" ]]
  
  interactive-cmd-h : ctxt → 𝕃 string → string ⊎ tagged-val
  interactive-cmd-h Γ ("normalize" :: input :: ll :: sp :: norm :: lc) =
    normalize-cmd Γ input ll sp norm lc
  interactive-cmd-h Γ ("erase" :: input :: ll :: sp :: lc) =
    erase-cmd Γ input ll sp lc
  interactive-cmd-h Γ ("normalizePrompt" :: input :: norm :: lc) =
    normalize-prompt Γ input norm lc
  interactive-cmd-h Γ ("erasePrompt" :: input :: lc) =
    erase-prompt Γ input lc
--  interactive-cmd-h Γ ("conv" :: ll :: ss :: is :: lc) =
--    conv-cmd Γ ll ss is lc
--  interactive-cmd-h Γ ("rewrite" :: ss :: is :: head :: lc) =
--    rewrite-cmd Γ ss is head lc
  interactive-cmd-h Γ ("data" :: encoding :: x :: ps :: is :: cs :: []) =
    data-cmd Γ encoding x ps is cs
  interactive-cmd-h Γ cs =
    inj₁ ("Unknown interactive cmd: " ^ 𝕃-to-string (λ s → s) ", " cs)

  record br-history : Set where
    inductive
    constructor mk-br-history
    field
      Γ : ctxt
      t : term
      Tₗₗ : language-level
      T : ll-lift Tₗₗ
      Tᵤ : string
      f : term → 𝕃 (ctr × term) → term
      undo : 𝕃 br-history
      redo : 𝕃 br-history

  data br-history2 : Set where
    br-node : br-history → 𝕃 (ctr × br-history2) → br-history2
  
  br-get-h : br-history2 → br-history
  br-get-h (br-node h hs) = h

  br-lookup : 𝕃 ℕ → br-history2 → maybe br-history
  br-lookup xs h = maybe-map br-get-h $
    foldl (λ x h? → h? ≫=maybe λ {(br-node h hs) → maybe-map snd $ head2 (nthTail x hs)}) (just h) xs

  {-# TERMINATING #-}
  br-cmd2 : ctxt → string → string → string → 𝕃 string → IO ⊤
  br-cmd2 Γ Tₛ tₛ sp ls =
    (string-to-ℕ - sp ! "natural number" ≫parse inj₂) ≫parseIO λ sp →
    let Γ = get-local-ctxt Γ sp ls in
    (parse-try Γ - Tₛ ! ttk ≫parse inj₂) ≫parseIO λ Tf → Tf λ Tₗₗ T →
    (parse-string ll-term - tₛ ! "term" ≫parse inj₂) ≫parseIO λ t →
    let T = qualif-ed Γ T
        Tₑ = erase T in
    putRopeLn (tv-to-rope $ inj₂ $ ts-tag Γ Tₑ) >>
    await (br-node (mk-br-history Γ t Tₗₗ T (rope-to-string $ ts2.to-string Γ Tₑ) const [] []) [])
    where

    import to-string (record options {erase-types = ff}) as ts2
    import to-string (record options {erase-types = ff; pretty-print = tt}) as pretty2s

    ts-tag : ∀ {ed} → ctxt → ⟦ ed ⟧ → tagged-val
    ts-tag = ts2.to-string-tag ""

    infixr 6 _≫parseIO_
    _≫parseIO_ : ∀ {A : Set} → string ⊎ A → (A → IO ⊤) → IO ⊤
    inj₁ e ≫parseIO f = putRopeLn (tv-to-rope $ inj₁ e)
    inj₂ a ≫parseIO f = f a

    replace-substring : string → string → ℕ → ℕ → string × string
    replace-substring sₒ sᵣ fm to with string-to-𝕃char sₒ | string-to-𝕃char sᵣ
    ...| csₒ | csᵣ =
      𝕃char-to-string (take fm csₒ ++ csᵣ ++ drop to csₒ) ,
      𝕃char-to-string (take (to ∸ fm) $ drop fm csₒ)

    replace : string → string → ℕ → ℕ → string
    replace sₒ sᵣ fm to = fst $ replace-substring sₒ sᵣ fm to
    
    substring : string → ℕ → ℕ → string
    substring s fm to = snd $ replace-substring s "" fm to

    set-Γ-file-missing : ctxt → ctxt
    set-Γ-file-missing (mk-ctxt (fn , mod) ss is os μ) = mk-ctxt ("missing" , mod) ss is os μ
    
    escape-rope : rope → rope
    escape-rope [[ s ]] = [[ escape-string s ]]
    escape-rope (r₁ ⊹⊹ r₂) = escape-rope r₁ ⊹⊹ escape-rope r₂

    parse-path : string → maybe (𝕃 ℕ)
    parse-path "" = just []
    parse-path s with string-split s ' ' | foldr (λ n ns →  ns ≫=maybe λ ns → string-to-ℕ n ≫=maybe λ n → just (n :: ns)) (just [])
    ...| "" :: ss | f = f ss
    ...| path | f = f path

    
    write-history : 𝕃 ℕ → br-history → br-history2 → br-history2
    write-history [] h (br-node _ hs) = br-node h hs
    write-history (n :: ns) h (br-node hₒ hs) = br-node hₒ $ writeh n hs where
      writeh : ℕ → 𝕃 (ctr × br-history2) → 𝕃 (ctr × br-history2)
      writeh _ [] = []
      writeh zero ((c , h') :: hs) = (c , write-history ns h h') :: hs
      writeh (suc n) (h' :: hs) = h' :: writeh n hs

    write-children : 𝕃 ℕ → 𝕃 (ctr × br-history) → br-history2 → br-history2
    write-children [] hs (br-node h _) = br-node h (map (uncurry λ c h → c , br-node h []) hs)
    write-children (n :: ns) hs (br-node h hsₒ) = br-node h $ writeh n hsₒ where
      writeh : ℕ → 𝕃 (ctr × br-history2) → 𝕃 (ctr × br-history2)
      writeh _ [] = []
      writeh zero ((c , h') :: hs') = (c , write-children ns hs h') :: hs'
      writeh (suc n) (h' :: hs) = h' :: writeh n hs

    outline : br-history2 → term
    outline (br-node (mk-br-history Γ t ll-type T Tₛ f undo redo) []) = f (Chi pi-gen (SomeType T) t) []
    outline (br-node (mk-br-history Γ t Tₗₗ T Tₛ f undo redo) []) = f t []
    outline (br-node (mk-br-history Γ t Tₗₗ T Tₛ f undo redo) hs) = f t (map (uncurry λ c h → c , outline h) hs)
{-      f $ Mu' pi-gen NoTerm t NoType pi-gen (map (λ {(Ctr _ x T , h) → case decompose-ctr-type Γ (hnf Γ (unfolding-elab unfold-head) T tt) of λ {(Tₕ , ps , as) → Case pi-gen x (map (λ {(Decl _ _ me x atk _) → if tk-is-type atk then CaseTermArg pi-gen me x else CaseTypeArg pi-gen x}) ps) $ params-to-apps ps $ outline h}}) hs) pi-gen-}

    await : br-history2 → IO ⊤
    awaith : br-history2 → 𝕃 string → IO ⊤
    await his =
      getLine >>= λ input →
      let input = undo-escape-string input
          as = string-split input delimiter in
      awaith his as
    
    awaith his as =
      let put = putRopeLn ∘ tv-to-rope
          err = (_>> await his) ∘' put ∘' inj₁ in
      case as of λ where -- TODO: for these commands, do not add TYPES/KINDS of local decls to context, as they are probably just bound by foralls/pis/lambdas, not _really_ in scope!
        ("br" :: path :: as) →
          maybe-else' (parse-path path) (err ("Could not parse " ^ path ^ " as a list of space-delimited natural numbers")) λ path →
          let await-with = await ∘ flip (write-history path) his in
          maybe-else' (br-lookup path his) (err "Beta-reduction pointer does not exist") λ where
            this @ (mk-br-history Γ t Tₗₗ T Tᵤ f undo redo) → case as of λ where
             
              ("undo" :: []) → case undo of λ where
                [] → err "No undo history"
                (u :: us) →
                  put (inj₂ $ "" , [[ "Undo" ]] , []) >>
                  await-with (record u {undo = us; redo = this :: redo})
                  --u (await Γ t Tₗₗ T Tᵤ f undo redo :: redo)
             
              ("redo" :: []) → case redo of λ where
                [] → err "No redo history"
                (r :: rs) →
                  put (inj₂ $ "" , [[ "Redo" ]] , []) >>
                  await-with (record r {undo = this :: undo; redo = rs})
                  --r
             
              ("get" :: []) →
                put (inj₂ $ "" , [[ Tᵤ ]] , []) >>
                await his
             
              ("parse" :: []) →
                (_>> await his) $
                maybe-else' (parse-string Tₗₗ Tᵤ)
                  (putRopeLn (spans-to-rope (global-error "Parse error" nothing)))
                  λ T → putRopeLn $ spans-to-rope $ snd $ snd $ ll-ind' {λ _ → spanM ⊤} (Tₗₗ , T)
                          untyped-term-spans untyped-type-spans untyped-kind-spans (set-Γ-file-missing Γ) empty-spans
             
              ("check" :: t?) →
                let await-set = maybe-else (await his) λ t → await-with $ record this
                                  {t = qualif-term Γ t; undo = this :: undo; redo = []} in
                (λ e → either-else' e
                  (uncurry λ t? e → put (inj₁ e) >> await-set t?)
                  (uncurry λ t? m → put (inj₂ $ "value" , [[ m ]] , []) >> await-set t?)) $
                ll-ind' {λ T → (maybe term × string) ⊎ (maybe term × string)} (Tₗₗ , T)
                  (λ _ → inj₁ $ nothing , "Expression must be a type, not a term!")
                  (λ T →
                    (case t? of λ where
                      [] → inj₂ nothing
                      (t :: []) → maybe-else' (parse-string ll-term t)
                        (inj₁ $ nothing , parse-err-msg t "term")
                        (inj₂ ∘ just)
                      _ → inj₁ $ nothing ,
                        "To many arguments given to beta-reduction command 'check'")
                  ≫=⊎ λ t? →
                    if (spans-have-error (snd $ snd $ check-term (maybe-else' t? t id) (just T) Γ empty-spans))
                      then inj₁ (t? , "Type error")
                      else inj₂ (t? , "Type inhabited"))
                  (λ _ → inj₁ $ nothing , "Expression must be a type, not a kind!")
             
              ("rewrite" :: fm :: to :: eq :: ρ+? :: lc) →
                let Γ' = merge-lcis-ctxt Γ lc in
                either-else'
                  (parse-string ll-term - eq ! "term" ≫parse λ eqₒ →
                   string-to-𝔹 - ρ+? ! "boolean" ≫parse λ ρ+? →
                   string-to-ℕ - fm ! "natural number" ≫parse λ fm →
                   string-to-ℕ - to ! "natural number" ≫parse λ to →
                   parse-try Γ' - substring Tᵤ fm to ! ttk ≫parse λ Tf → Tf λ ll Tₗ →
                   fst (check-term eqₒ nothing Γ' empty-spans) !
                     "Could not synthesize a type from the input term" ≫error λ Tₑ →
                   is-eq-tp? Tₑ
                     ! "Synthesized a non-equational type from the input term" ≫error λ Tₑ →
                   let mk-eq-tp! t₁ t₂ _ _ = Tₑ
                       x = fresh-var-new Γ' ignored-var
                       eq = qualif-term Γ' eqₒ
                       Tₗ = qualif-ed Γ' Tₗ in
                   elim-pair (map-snd snd $ rewrite-ed Tₗ Γ' ρ+? nothing (just eq) t₁ x 0) λ Tᵣ n →
                   err⊎-guard (iszero n) "No rewrites could be performed" ≫=⊎ λ _ →
                   parse-string Tₗₗ - replace Tᵤ
                     (rope-to-string $ [[ "(" ]] ⊹⊹ ts2.to-string Γ' Tᵣ ⊹⊹ [[ ")" ]]) fm to
                     ! ll-ind "term" "type" "kind" Tₗₗ ≫parse λ Tᵤ →
                   let Tᵤ = qualif-ed (ctxt-var-decl x Γ) Tᵤ in
                   ll-ind' {λ {(ll , T) → ll-lift ll → string ⊎ ll-lift ll × (term → term)}}
                     (Tₗₗ , Tᵤ)
                     (λ t T → inj₂ $ rewrite-mk-phi x eq T (subst Γ t₂ x t) , id)
                     (λ Tᵤ _ → inj₂ $ post-rewrite (ctxt-var-decl x Γ) x eq t₂ Tᵤ ,
                                      Rho pi-gen RhoPlain NoNums eqₒ (Guide pi-gen x Tᵤ))
                     (λ k _ → inj₂ $ subst Γ t₂ x k , id)
                     T) err $ uncurry λ T' fₜ →
                  put (inj₂ $ ts-tag Γ $ erase T') >>
                  await-with (record this {T = T'; Tᵤ = rope-to-string $ ts2.to-string Γ $ erase T'; f = f ∘ fₜ; undo = this :: undo; redo = []})
             
              ("normalize" :: fm :: to :: norm :: lc) →
                either-else'
                  (let Γ' = merge-lcis-ctxt Γ lc in
                   string-to-ℕ - fm ! "natural number" ≫parse λ fm →
                   string-to-ℕ - to ! "natural number" ≫parse λ to →
                   let tₛ = substring Tᵤ fm to in
                   parse-try Γ' - tₛ ! ttk ≫parse λ t → t λ ll t →
                   parse-norm ff - norm ! parse-norm-err ≫parse λ norm →
                   let s = norm Γ' $ qualif-ed Γ' t
                       rs = rope-to-string $ [[ "(" ]] ⊹⊹ ts2.to-string Γ' s ⊹⊹ [[ ")" ]]
                       Tᵤ' = replace Tᵤ rs fm to in
                   parse-string Tₗₗ - Tᵤ' ! ll-ind "term" "type" "kind" Tₗₗ ≫parse λ Tᵤ' →
                   let Tᵤ' = qualif-ed Γ Tᵤ' in
                   inj₂ Tᵤ')
                  err λ Tᵤ' →
                  put (inj₂ $ ts-tag Γ Tᵤ') >>
                  await-with (record this {T = Tᵤ' {-Checks?-}; Tᵤ = rope-to-string $ ts2.to-string Γ $ erase Tᵤ'; undo = this :: undo; redo = []})
             
              ("conv" :: ll :: fm :: to :: t' :: ls) →
                let Γ' = merge-lcis-ctxt Γ ls in
                either-else'
                  (parse-ll - ll ! "language level" ≫parse λ ll →
                   string-to-ℕ - fm ! "natural number" ≫parse λ fm →
                   string-to-ℕ - to ! "natural number" ≫parse λ to →
                   let t = substring Tᵤ fm to in
                   parse-string ll - t  ! ll-ind "term" "type" "kind" ll ≫parse λ t  →
                   parse-string ll - t' ! ll-ind "term" "type" "kind" ll ≫parse λ t' →
                   let t = qualif-ed Γ' t; t' = qualif-ed Γ' t' in
                   err⊎-guard (~ ll-ind {λ ll → ctxt → ll-lift ll → ll-lift ll → 𝔹}
                     conv-term conv-type conv-kind ll Γ' t t') "Inconvertible" ≫⊎
                   let rs = [[ "(" ]] ⊹⊹ ts2.to-string Γ' (erase t') ⊹⊹ [[ ")" ]]
                       Tᵤ = replace Tᵤ (rope-to-string rs) fm to in
                   parse-string Tₗₗ - Tᵤ ! ll-ind "term" "type" "kind" Tₗₗ ≫parse λ Tᵤ →
                   inj₂ (qualif-ed Γ Tᵤ)) err λ Tᵤ' →
                  put (inj₂ $ ts-tag Γ $ erase Tᵤ') >>
                  await-with (record this {Tᵤ = rope-to-string $ ts2.to-string Γ $ erase Tᵤ'; undo = this :: undo; redo = []})
             
              ("bind" :: xᵤ :: []) →
                either-else'
                  (ll-ind' {λ {(ll , _) → string ⊎ ctxt × ll-lift ll × (term → term)}} (Tₗₗ , T)
                    (λ t' →
                      let R = string ⊎ ctxt × term × (term → term) in
                      (case_of_ {B = (maybeErased → var → optClass → term → R) → R}
                        (t' , hnf Γ unfold-head t' tt) $ uncurry λ where
                          (Lam _ me _ x oc body) _ f → f me x oc body
                          _ (Lam _ me _ x oc body) f → f me x oc body
                          _ _ _ → inj₁ "Not a term abstraction") λ me x oc body →
                      inj₂ $ ctxt-var-decl x Γ , rename-var (ctxt-var-decl x Γ) x xᵤ body ,
                               Lam pi-gen me "missing" x oc)
                      --inj₂ $ ctxt-var-decl x Γ , rename-var (ctxt-var-decl x Γ) x xᵤ , Lam
                    (λ T → to-abs (hnf Γ (unfolding-elab unfold-head) T tt)
                      ! "Not a type abstraction" ≫error λ where
                        (mk-abs me x dom free cod) →
                          tk-elim dom
                            (λ dom f → f $ ctxt-term-decl-no-qualif "missing" xᵤ dom Γ)
                            (λ dom f → f $ ctxt-type-decl-no-qualif "missing" xᵤ dom Γ) λ Γ' →
                          inj₂ $ Γ' , rename-var Γ' x ("missing" % xᵤ) cod ,
                            Lam pi-gen me "missing" xᵤ (SomeClass dom))
                    (λ k → inj₁ "Expression must be a term or a type"))
                  err $ uncurry λ Γ' → uncurry λ T' fₜ →
                  put (inj₂ $ ts-tag Γ' T') >>
                  await-with (record this
                      {Γ = Γ' ;
                       T = T';
                       Tᵤ = rope-to-string $ ts2.to-string Γ' $ erase T';
                       f = f ∘ fₜ;
                       undo = this :: undo;
                       redo = []})
             
              ("case" :: scrutinee :: rec :: motive?) → -- TODO: Motive?
                either-else'
                  (parse-string ll-term - scrutinee ! "term" ≫parse λ scrutinee →
                   maybe-else' (fst $ check-term scrutinee nothing Γ empty-spans)
                     (inj₁ "Error synthesizing a type from the input term") inj₂ ≫=⊎ λ Tₛ →
                   let Tₛ = hnf Γ (unfolding-elab unfold-head) Tₛ ff in
                   case decompose-ctr-type Γ Tₛ of λ where
                     (TpVar _ Xₛ , [] , as) →
                       ll-ind' {λ T → string ⊎ (term × 𝕃 (ctr × type) × type × ctxt)} (Tₗₗ , T)
                         (λ t → inj₁ "Expression must be a type to case split")
                         (λ T → maybe-else' (data-lookup Γ Xₛ as)
                           (inj₁ "The synthesized type of the input term is not a datatype")
                           λ d → let mk-data-info X mu asₚ asᵢ ps kᵢ k cs σ = d
                                     is' = kind-to-indices (add-params-to-ctxt ps Γ) kᵢ
                                     is = drop-last 1 is'
                                     Tₘ = refine-motive Γ (qualif-term Γ scrutinee) X is
                                            (args-to-ttys asₚ) asᵢ T
                                     Γ' = if iszero (string-length rec)
                                            then Γ
                                            else fst (snd (ctxt-mu-decls is Tₘ [] d
                                                pi-gen pi-gen pi-gen rec Γ empty-spans)) in
                             if spans-have-error (snd $ snd $
                                  check-type Tₘ (just kᵢ) (qualified-ctxt Γ) empty-spans)
                               then inj₁ "Computed an ill-typed motive"
                               else inj₂ (scrutinee , map (λ {(Ctr pi x T) →
                                 let T' = hnf Γ' (unfolding-elab unfold-head) T tt in
                                 Ctr pi x T ,
                                 (case decompose-ctr-type Γ' T' of λ {(Tₕ , ps' , as) →
                                   params-to-alls ps' $ hnf Γ' (unfolding-elab unfold-head) (TpAppt
                                     (recompose-tpapps (drop (length ps) as) Tₘ)
                                     (recompose-apps (params-to-args ps') $
                                       recompose-apps asₚ (mvar x))) ff})})
                                   (σ (mu-Type/ rec)) ,
                                 Tₘ ,
                                 Γ'))
                         (λ k → inj₁ "Expression must be a type to case split")
                     (Tₕ , [] , as) → inj₁ "Synthesized a non-datatype from the input term"
                     (Tₕ , ps , as) →
                       inj₁ "Case splitting is currently restricted to datatypes")
                  err $ uncurry λ scrutinee → uncurry λ cs → uncurry λ Tₘ Γ →
                let json = json-object $ trie-single "value" $ json-array $ json-nat 0 ::
                             [ (json-new (map
                                 (λ {(Ctr _ x _ , T) → unqual-all (ctxt-get-qualif Γ) x ,
                                   json-raw ([[ "\"" ]] ⊹⊹
                                   to-string Γ (erase T) ⊹⊹
                                   [[ "\"" ]])})
                                 cs)) ] in
                putRopeLn (json-to-rope json) >>
                let shallow = iszero (string-length rec)
                    mk-cs = map λ where
                      (Ctr _ x T , t) →
                        let T' = hnf Γ (unfolding-elab unfold-head) T tt in
                        case decompose-ctr-type Γ T' of λ where
                          (Tₕ , ps , as) →
                            let mf = map λ where
                                       (Decl _ _ me x atk _) →
                                         if tk-is-type atk
                                           then CaseTermArg pi-gen me x
                                           else CaseTypeArg pi-gen x in
                            Case pi-gen x (mf ps) $ params-to-apps ps t
                    f'' = λ t cs → if shallow
                      then Mu' pi-gen NoTerm t (SomeType Tₘ) pi-gen (mk-cs cs) pi-gen
                      else Mu pi-gen pi-gen rec t (SomeType Tₘ) pi-gen (mk-cs cs) pi-gen
                    f' = λ t cs → f (f'' t cs) cs
                    mk-hs = map $ map-snd λ T'' →
                              mk-br-history Γ t ll-type T''
                                (rope-to-string $ to-string Γ $ erase T'')
                                (λ t cs → t) [] [] in
                await (write-children path (mk-hs cs) $
                         write-history path (record this
                           {f = f';
                            Γ = Γ;
                            t = scrutinee;
                            undo = this :: undo;
                            redo = []})
                           his)
             
              ("print" :: tab :: []) →
                either-else' (string-to-ℕ - tab ! "natural number" ≫parse inj₂) err λ tab →
                putRopeLn (escape-rope (tv-to-rope (inj₂ $ pretty2s.strRunTag "" Γ $ pretty2s.strNest (suc {-left paren-} tab) (pretty2s.to-stringh $ outline his)))) >> await his
              
              ("quit" :: []) → put $ inj₂ $ strRunTag "" Γ $ strAdd "Quitting beta-reduction mode..."
             
              _ → err $ foldl (λ a s → s ^ char-to-string delimiter ^ a)
                      "Unknown beta-reduction command: " as
        _ → err "A beta-reduction buffer is still open"




interactive-cmd : 𝕃 string → toplevel-state → IO ⊤
interactive-cmd ("br2" :: T :: t :: sp :: lc) ts = br-cmd2 (toplevel-state.Γ ts) T t sp lc
interactive-cmd ("pretty" :: src :: dest :: []) ts = pretty-cmd src dest >>= putStrLn
interactive-cmd ls ts = putRopeLn (tv-to-rope (interactive-cmd-h (toplevel-state.Γ ts) ls))

interactive-not-br-cmd-msg = tv-to-rope $ inj₁ "Beta-reduction mode has been terminated"

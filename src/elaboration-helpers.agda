{-# OPTIONS --allow-unsolved-metas #-}
import cedille-options
module elaboration-helpers (options : cedille-options.options) where

open import lib
open import monad-instances
open import general-util
open import cedille-types
open import syntax-util
open import ctxt
open import conversion
open import constants
open import to-string options
open import subst
open import rename
open import is-free
open import toplevel-state options {id}
open import spans options {id}


uncurry' : ∀ {A B C D : Set} → (A → B → C → D) → (A × B × C) → D
uncurry' f (a , b , c) = f a b c

uncurry'' : ∀ {A B C D E : Set} → (A → B → C → D → E) → (A × B × C × D) → E
uncurry'' f (a , b , c , d) = f a b c d

uncurry''' : ∀ {A B C D E F : Set} → (A → B → C → D → E → F) → (A × B × C × D × E) → F
uncurry''' f (a , b , c , d , e) = f a b c d e

ctxt-term-decl' : posinfo → var → type → ctxt → ctxt
ctxt-term-decl' pi x T (mk-ctxt (fn , mn , ps , q) ss is os d) =
  mk-ctxt (fn , mn , ps , trie-insert q x (x , ArgsNil)) ss
    (trie-insert is x (term-decl T , fn , pi)) os d

ctxt-type-decl' : posinfo → var → kind → ctxt → ctxt
ctxt-type-decl' pi x k (mk-ctxt (fn , mn , ps , q) ss is os d) =
  mk-ctxt (fn , mn , ps , trie-insert q x (x , ArgsNil)) ss
    (trie-insert is x (type-decl k , fn , pi)) os d

ctxt-tk-decl' : posinfo → var → tk → ctxt → ctxt
ctxt-tk-decl' pi x (Tkt T) = ctxt-term-decl' pi x T
ctxt-tk-decl' pi x (Tkk k) = ctxt-type-decl' pi x k

ctxt-param-decl : var → var → tk → ctxt → ctxt
ctxt-param-decl x x' atk Γ @ (mk-ctxt (fn , mn , ps , q) ss is os ds) =
  let d = case atk of λ {(Tkt T) → term-decl T; (Tkk k) → type-decl k} in
  mk-ctxt
  (fn , mn , ps , trie-insert q x (x , ArgsNil)) ss
  (trie-insert is x' (d , fn , posinfo-gen)) os ds

ctxt-term-def' : var → var → term → type → opacity → ctxt → ctxt
ctxt-term-def' x x' t T op Γ @ (mk-ctxt (fn , mn , ps , q) ss is os d) = mk-ctxt
  (fn , mn , ps , qualif-insert-params q (mn # x) x ps) ss
  (trie-insert is x' (term-def (just ps) op (hnf Γ unfold-head t tt) T , fn , x)) os d

ctxt-type-def' : var → var → type → kind → opacity → ctxt → ctxt
ctxt-type-def' x x' T k op Γ @ (mk-ctxt (fn , mn , ps , q) ss is os d) = mk-ctxt
  (fn , mn , ps , qualif-insert-params q (mn # x) x ps) ss
  (trie-insert is x' (type-def (just ps) op (hnf Γ (unfolding-elab unfold-head) T tt) k , fn , x)) os d

ctxt-let-term-def : posinfo → var → term → type → ctxt → ctxt
ctxt-let-term-def pi x t T (mk-ctxt (fn , mn , ps , q) ss is os d) =
  mk-ctxt (fn , mn , ps , trie-insert q x (x , ArgsNil)) ss
    (trie-insert is x (term-def nothing OpacTrans t T , fn , pi)) os d

ctxt-let-type-def : posinfo → var → type → kind → ctxt → ctxt
ctxt-let-type-def pi x T k (mk-ctxt (fn , mn , ps , q) ss is os d) =
  mk-ctxt (fn , mn , ps , trie-insert q x (x , ArgsNil)) ss
    (trie-insert is x (type-def nothing OpacTrans T k , fn , pi)) os d

ctxt-kind-def' : var → var → params → kind → ctxt → ctxt
ctxt-kind-def' x x' ps2 k Γ @ (mk-ctxt (fn , mn , ps1 , q) ss is os d) = mk-ctxt
  (fn , mn , ps1 , qualif-insert-params q (mn # x) x ps1) ss
  (trie-insert is x' (kind-def ps1 (h Γ ps2) k' , fn , posinfo-gen)) os d
  where
    k' = hnf Γ unfold-head k tt
    h : ctxt → params → params
    h Γ (ParamsCons (Decl pi pi' me x atk pi'') ps) =
      ParamsCons (Decl pi pi' me (pi' % x) (qualif-tk Γ atk) pi'') (h (ctxt-tk-decl pi' localScope x atk Γ) ps)
    h _ ps = ps

ctxt-lookup-term-var' : ctxt → var → maybe type
ctxt-lookup-term-var' Γ @ (mk-ctxt (fn , mn , ps , q) ss is os d) x =
  env-lookup Γ x ≫=maybe λ where
    (term-decl T , _) → just T
    (term-def ps _ _ T , _ , x') →
      let ps = maybe-else ParamsNil id ps in
      just $ abs-expand-type ps T
    _ → nothing

-- TODO: Could there be parameter/argument clashes if the same parameter variable is defined multiple times?
-- TODO: Could variables be parameter-expanded multiple times?
ctxt-lookup-type-var' : ctxt → var → maybe kind
ctxt-lookup-type-var' Γ @ (mk-ctxt (fn , mn , ps , q) ss is os d) x =
  env-lookup Γ x ≫=maybe λ where
    (type-decl k , _) → just k
    (type-def ps _ _ k , _ , x') →
      let ps = maybe-else ParamsNil id ps in
      just $ abs-expand-kind ps k
    _ → nothing

subst-qualif : ∀ {ed : exprd} → ctxt → renamectxt → ⟦ ed ⟧ → ⟦ ed ⟧
subst-qualif{TERM} Γ ρ = subst-renamectxt Γ ρ ∘ qualif-term Γ
subst-qualif{TYPE} Γ ρ = subst-renamectxt Γ ρ ∘ qualif-type Γ
subst-qualif{KIND} Γ ρ = subst-renamectxt Γ ρ ∘ qualif-kind Γ
subst-qualif Γ ρ = id

rename-validify : string → string
rename-validify = 𝕃char-to-string ∘ (h ∘ string-to-𝕃char) where
  validify-char : char → 𝕃 char
  validify-char c with
    (c =char 'a')  ||
    (c =char 'z')  ||
    (c =char 'A')  ||
    (c =char 'Z')  ||
    (c =char '\'') ||
    (c =char '-')  ||
    (c =char '_')  ||
    is-digit c     ||
    (('a' <char c) && (c <char 'z')) ||
    (('A' <char c) && (c <char 'Z'))
  ...| tt = [ c ]
  ...| ff = 'Z' :: string-to-𝕃char (ℕ-to-string (toNat c)) ++ [ 'Z' ]
  h : 𝕃 char → 𝕃 char
  h [] = []
  h (c :: cs) = validify-char c ++ h cs

-- Returns a fresh variable name by adding primes and replacing invalid characters
fresh-var' : string → (string → 𝔹) → renamectxt → string
fresh-var' = fresh-var ∘ rename-validify

rename-new_from_for_ : ∀ {X : Set} → var → ctxt → (var → X) → X
rename-new "_" from Γ for f = f $ fresh-var' "x" (ctxt-binds-var Γ) empty-renamectxt
rename-new x from Γ for f = f $ fresh-var' x (ctxt-binds-var Γ) empty-renamectxt

rename_from_for_ : ∀ {X : Set} → var → ctxt → (var → X) → X
rename "_" from Γ for f = f "_"
rename x from Γ for f = f $ fresh-var' x (ctxt-binds-var Γ) empty-renamectxt

fresh-id-term : ctxt → term
fresh-id-term Γ = rename "x" from Γ for λ x → mlam x $ mvar x

get-renaming : renamectxt → var → var → var × renamectxt
get-renaming ρ xₒ x = let x' = fresh-var' x (renamectxt-in-range ρ) ρ in x' , renamectxt-insert ρ xₒ x'

rename_-_from_for_ : ∀ {X : Set} → var → var → renamectxt → (var → renamectxt → X) → X
rename xₒ - "_" from ρ for f = f "_" ρ
rename xₒ - x from ρ for f = uncurry f $ get-renaming ρ xₒ x

rename_-_lookup_for_ : ∀ {X : Set} → var → var → renamectxt → (var → renamectxt → X) → X
rename xₒ - x lookup ρ for f with renamectxt-lookup ρ xₒ
...| nothing = rename xₒ - x from ρ for f
...| just x' = f x' ρ

qualif-new-var : ctxt → var → var
qualif-new-var Γ x = ctxt-get-current-modname Γ # x

mbeta : term → term → term
mrho : term → var → type → term → term
mtpeq : term → term → type
mbeta t t' = Beta posinfo-gen (SomeTerm t posinfo-gen) (SomeTerm t' posinfo-gen)
mrho t x T t' = Rho posinfo-gen RhoPlain NoNums t (Guide posinfo-gen x T) t'
mtpeq t1 t2 = TpEq posinfo-gen t1 t2 posinfo-gen

subst-args-params : ctxt → args → params → kind → kind
subst-args-params Γ (ArgsCons (TermArg _ t) ys) (ParamsCons (Decl _ _ _ x _ _) ps) k =
  subst-args-params Γ ys ps $ subst Γ t x k
subst-args-params Γ (ArgsCons (TypeArg t) ys) (ParamsCons (Decl _ _ _ x _ _) ps) k =
  subst-args-params Γ ys ps $ subst Γ t x k
subst-args-params Γ ys ps k = k

data indx : Set where
  Index : var → tk → indx

data ctr : Set where
  Ctr : var → type → ctr

parameters = 𝕃 decl
indices = 𝕃 indx
constructors = 𝕃 ctr

data datatype : Set where
  Data : var → parameters → indices → constructors → datatype

params-to-parameters : params → parameters
params-to-parameters ParamsNil = []
params-to-parameters (ParamsCons p ps) = p :: params-to-parameters ps

{-# TERMINATING #-}
decompose-arrows : ctxt → type → parameters × type
decompose-arrows Γ (Abs pi me pi' x atk T) =
  rename-new x from Γ for λ x' →
  case decompose-arrows (ctxt-var-decl x' Γ) (rename-var Γ x x' T) of λ where
    (ps , T') → Decl posinfo-gen posinfo-gen me x' atk posinfo-gen :: ps , T'
decompose-arrows Γ (TpArrow T me T') =
  rename-new "_" from Γ for λ x →
  case decompose-arrows (ctxt-var-decl x Γ) T' of λ where
    (ps , T'') → Decl posinfo-gen posinfo-gen me x (Tkt T) posinfo-gen :: ps , T''
decompose-arrows Γ (TpParens pi T pi') = decompose-arrows Γ T
decompose-arrows Γ T = [] , T

decompose-ctr-type : ctxt → type → type × parameters × 𝕃 tty
decompose-ctr-type Γ T with decompose-arrows Γ T
...| ps , Tᵣ with decompose-tpapps Tᵣ
...| Tₕ , as = Tₕ , ps , as

{-# TERMINATING #-}
kind-to-indices : ctxt → kind → indices
kind-to-indices Γ (KndArrow k k') =
  rename "x" from Γ for λ x' →
  Index x' (Tkk k) :: kind-to-indices (ctxt-var-decl x' Γ) k'
kind-to-indices Γ (KndParens pi k pi') = kind-to-indices Γ k
kind-to-indices Γ (KndPi pi pi' x atk k) =
  rename x from Γ for λ x' →
  Index x' atk :: kind-to-indices (ctxt-var-decl x' Γ) k
kind-to-indices Γ (KndTpArrow T k) =
  rename "x" from Γ for λ x' →
  Index x' (Tkt T) :: kind-to-indices (ctxt-var-decl x' Γ) k
kind-to-indices Γ (KndVar pi x as) with ctxt-lookup-kind-var-def Γ x
...| nothing = []
...| just (ps , k) = kind-to-indices Γ $ subst-args-params Γ as ps k
kind-to-indices Γ (Star pi) = []

dataConsts-to-ctrs : dataConsts → constructors
dataConsts-to-ctrs DataNull = []
dataConsts-to-ctrs (DataCons (DataConst _ x T) cs) = Ctr x T :: dataConsts-to-ctrs cs

defDatatype-to-datatype : ctxt → defDatatype → datatype
defDatatype-to-datatype Γ (Datatype _ _ x ps k dcs _) =
  Data x (params-to-parameters ps) (kind-to-indices Γ k) (dataConsts-to-ctrs dcs)

indices-to-kind : indices → kind → kind
indices-to-kind = flip $ foldr λ {(Index x atk) → KndPi posinfo-gen posinfo-gen x atk}

parameters-to-kind : parameters → kind → kind
parameters-to-kind = flip $ foldr λ {(Decl pi pi' me x atk pi'') → KndPi pi pi' x atk}

indices-to-tplams : indices → (body : type) → type
indices-to-tplams = flip $ foldr λ where
  (Index x atk) → TpLambda posinfo-gen posinfo-gen x atk

parameters-to-tplams : parameters → (body : type) → type
parameters-to-tplams = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → TpLambda pi pi' x atk

indices-to-alls : indices → (body : type) → type
indices-to-alls = flip $ foldr λ where
  (Index x atk) → Abs posinfo-gen Erased posinfo-gen x atk

parameters-to-alls : parameters → (body : type) → type
parameters-to-alls = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Abs pi me pi' x atk

indices-to-lams : indices → (body : term) → term
indices-to-lams = flip $ foldr λ where
  (Index x atk) → Lam posinfo-gen Erased posinfo-gen x (SomeClass atk)

indices-to-lams' : indices → (body : term) → term
indices-to-lams' = flip $ foldr λ where
  (Index x atk) → Lam posinfo-gen Erased posinfo-gen x NoClass

parameters-to-lams : parameters → (body : term) → term
parameters-to-lams = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Lam pi me pi' x (SomeClass atk)

parameters-to-lams' : parameters → (body : term) → term
parameters-to-lams' = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Lam pi me pi' x NoClass

indices-to-apps : indices → (body : term) → term
indices-to-apps = flip $ foldl λ where
  (Index x (Tkt T)) t → App t Erased (mvar x)
  (Index x (Tkk k)) t → AppTp t (mtpvar x)

parameters-to-apps : parameters → (body : term) → term
parameters-to-apps = flip $ foldl λ where
  (Decl pi pi' me x (Tkt T) pi'') t → App t me (mvar x)
  (Decl pi pi' me x (Tkk k) pi'') t → AppTp t (mtpvar x)

indices-to-tpapps : indices → (body : type) → type
indices-to-tpapps = flip $ foldl λ where
  (Index x (Tkt T)) T' → TpAppt T' (mvar x)
  (Index x (Tkk k)) T  → TpApp  T  (mtpvar x)

parameters-to-tpapps : parameters → (body : type) → type
parameters-to-tpapps = flip $ foldl λ where
  (Decl pi pi' me x (Tkt T) pi'') T' → TpAppt T' (mvar x)
  (Decl pi pi' me x (Tkk k) pi'') T  → TpApp  T  (mtpvar x)

constructors-to-lams' : constructors → (body : term) → term
constructors-to-lams' = flip $ foldr λ where
  (Ctr x T) → Lam posinfo-gen NotErased posinfo-gen x NoClass

constructors-to-lams : ctxt → var → parameters → constructors → (body : term) → term
constructors-to-lams Γ x ps cs t = foldr
  (λ {(Ctr y T) f Γ → Lam posinfo-gen NotErased posinfo-gen y
    (SomeClass $ Tkt $ subst Γ (parameters-to-tpapps ps $ mtpvar y) y T)
    $ f $ ctxt-var-decl y Γ})
  (λ Γ → t) cs Γ

add-indices-to-ctxt : indices → ctxt → ctxt
add-indices-to-ctxt = flip $ foldr λ {(Index x atk) → ctxt-var-decl x}

add-parameters-to-ctxt : parameters → ctxt → ctxt
add-parameters-to-ctxt = flip $ foldr λ {(Decl _ _ _ x'' _ _) → ctxt-var-decl x''}

add-constructors-to-ctxt : constructors → ctxt → ctxt
add-constructors-to-ctxt = flip $ foldr λ where
  (Ctr x T) → ctxt-var-decl x

module reindexing (Γ : ctxt) (isₒ : indices) where

  reindex-fresh-var : renamectxt → trie indices → var → var
  reindex-fresh-var ρ is "_" = "_"
  reindex-fresh-var ρ is x =
    fresh-var x (λ x' → ctxt-binds-var Γ x' || trie-contains is x') ρ

  rename-indices : renamectxt → trie indices → indices
  rename-indices ρ is = foldr {B = renamectxt → indices}
    (λ {(Index x atk) f ρ →
       let x' = reindex-fresh-var ρ is x in
       Index x' (substh-tk {TERM} Γ ρ empty-trie atk) :: f (renamectxt-insert ρ x x')})
    (λ ρ → []) isₒ ρ
  
  reindex-t : Set → Set
  reindex-t X = renamectxt → trie indices → X → X
  
  reindex : ∀ {ed} → reindex-t ⟦ ed ⟧
  reindex-term : reindex-t term
  reindex-type : reindex-t type
  reindex-kind : reindex-t kind
  reindex-tk : reindex-t tk
  reindex-liftingType : reindex-t liftingType
  reindex-optTerm : reindex-t optTerm
  reindex-optType : reindex-t optType
  reindex-optGuide : reindex-t optGuide
  reindex-optClass : reindex-t optClass
  reindex-lterms : reindex-t lterms
  reindex-args : reindex-t args
  reindex-arg : reindex-t arg
  reindex-theta : reindex-t theta
  reindex-vars : reindex-t (maybe vars)
  reindex-defTermOrType : renamectxt → trie indices → defTermOrType → defTermOrType × renamectxt
  
  reindex{TERM} = reindex-term
  reindex{TYPE} = reindex-type
  reindex{KIND} = reindex-kind
  reindex{TK}   = reindex-tk
  reindex       = λ ρ is x → x

  rc-is : renamectxt → indices → renamectxt
  rc-is = foldr λ {(Index x atk) ρ → renamectxt-insert ρ x x}
  
  index-var = "indices"
  index-type-var = "Indices"
  is-index-var = isJust ∘ is-pfx index-var
  is-index-type-var = isJust ∘ is-pfx index-type-var
  
  reindex-term ρ is (App t me (Var pi x)) with trie-lookup is x
  ...| nothing = App (reindex-term ρ is t) me (reindex-term ρ is (Var pi x))
  ...| just is' = indices-to-apps is' $ reindex-term ρ is t
  reindex-term ρ is (App t me t') =
    App (reindex-term ρ is t) me (reindex-term ρ is t')
  reindex-term ρ is (AppTp t T) =
    AppTp (reindex-term ρ is t) (reindex-type ρ is T)
  reindex-term ρ is (Beta pi ot ot') =
    Beta pi (reindex-optTerm ρ is ot) (reindex-optTerm ρ is ot')
  reindex-term ρ is (Chi pi oT t) =
    Chi pi (reindex-optType ρ is oT) (reindex-term ρ is t)
  reindex-term ρ is (Delta pi oT t) =
    Delta pi (reindex-optType ρ is oT) (reindex-term ρ is t)
  reindex-term ρ is (Epsilon pi lr m t) =
    Epsilon pi lr m (reindex-term ρ is t)
  reindex-term ρ is (Hole pi) =
    Hole pi
  reindex-term ρ is (IotaPair pi t t' g pi') =
    IotaPair pi (reindex-term ρ is t) (reindex-term ρ is t') (reindex-optGuide ρ is g) pi'
  reindex-term ρ is (IotaProj t n pi) =
    IotaProj (reindex-term ρ is t) n pi
  reindex-term ρ is (Lam pi me pi' x oc t) with is-index-var x
  ...| ff = let x' = reindex-fresh-var ρ is x in
    Lam pi me pi' x' (reindex-optClass ρ is oc) (reindex-term (renamectxt-insert ρ x x') is t)
  ...| tt with rename-indices ρ is | oc
  ...| isₙ | NoClass = indices-to-lams' isₙ $ reindex-term (rc-is ρ isₙ) (trie-insert is x isₙ) t
  ...| isₙ | SomeClass atk = indices-to-lams isₙ $ reindex-term (rc-is ρ isₙ) (trie-insert is x isₙ) t
  reindex-term ρ is (Let pi d t) =
    elim-pair (reindex-defTermOrType ρ is d) λ d' ρ' → Let pi d' (reindex-term ρ' is t)
  reindex-term ρ is (Open pi x t) =
    Open pi x (reindex-term ρ is t)
  reindex-term ρ is (Parens pi t pi') =
    reindex-term ρ is t
  reindex-term ρ is (Phi pi t₌ t₁ t₂ pi') =
    Phi pi (reindex-term ρ is t₌) (reindex-term ρ is t₁) (reindex-term ρ is t₂) pi'
  reindex-term ρ is (Rho pi op on t og t') =
    Rho pi op on (reindex-term ρ is t) (reindex-optGuide ρ is og) (reindex-term ρ is t')
  reindex-term ρ is (Sigma pi t) =
    Sigma pi (reindex-term ρ is t)
  reindex-term ρ is (Theta pi θ t ts) =
    Theta pi (reindex-theta ρ is θ) (reindex-term ρ is t) (reindex-lterms ρ is ts)
  reindex-term ρ is (Var pi x) =
    Var pi $ renamectxt-rep ρ x
  reindex-term ρ is (Mu pi x t oT pi' cs pi'') = Var posinfo-gen "template-mu-not-allowed"
  reindex-term ρ is (Mu' pi t oT pi' cs pi'') = Var posinfo-gen "template-mu-not-allowed" 
  
  reindex-type ρ is (Abs pi me pi' x atk T) with is-index-var x
  ...| ff = let x' = reindex-fresh-var ρ is x in
    Abs pi me pi' x' (reindex-tk ρ is atk) (reindex-type (renamectxt-insert ρ x x') is T)
  ...| tt = let isₙ = rename-indices ρ is in
    indices-to-alls isₙ $ reindex-type (rc-is ρ isₙ) (trie-insert is x isₙ) T
  reindex-type ρ is (Iota pi pi' x T T') =
    let x' = reindex-fresh-var ρ is x in
    Iota pi pi' x' (reindex-type ρ is T) (reindex-type (renamectxt-insert ρ x x') is T')
  reindex-type ρ is (Lft pi pi' x t lT) =
    let x' = reindex-fresh-var ρ is x in
    Lft pi pi' x' (reindex-term (renamectxt-insert ρ x x') is t) (reindex-liftingType ρ is lT)
  reindex-type ρ is (NoSpans T pi) =
    NoSpans (reindex-type ρ is T) pi
  reindex-type ρ is (TpLet pi d T) =
    elim-pair (reindex-defTermOrType ρ is d) λ d' ρ' → TpLet pi d' (reindex-type ρ' is T)
  reindex-type ρ is (TpApp T T') =
    TpApp (reindex-type ρ is T) (reindex-type ρ is T')
  reindex-type ρ is (TpAppt T (Var pi x)) with trie-lookup is x
  ...| nothing = TpAppt (reindex-type ρ is T) (reindex-term ρ is (Var pi x))
  ...| just is' = indices-to-tpapps is' $ reindex-type ρ is T
  reindex-type ρ is (TpAppt T t) =
    TpAppt (reindex-type ρ is T) (reindex-term ρ is t)
  reindex-type ρ is (TpArrow (TpVar pi x) Erased T) with is-index-type-var x
  ...| ff = TpArrow (reindex-type ρ is (TpVar pi x)) Erased (reindex-type ρ is T)
  ...| tt = let isₙ = rename-indices ρ is in
    indices-to-alls isₙ $ reindex-type (rc-is ρ isₙ) (trie-insert is x isₙ) T
  reindex-type ρ is (TpArrow T me T') =
    TpArrow (reindex-type ρ is T) me (reindex-type ρ is T')
  reindex-type ρ is (TpEq pi t t' pi') =
    TpEq pi (reindex-term ρ is t) (reindex-term ρ is t') pi'
  reindex-type ρ is (TpHole pi) =
    TpHole pi
  reindex-type ρ is (TpLambda pi pi' x atk T) with is-index-var x
  ...| ff = let x' = reindex-fresh-var ρ is x in
    TpLambda pi pi' x' (reindex-tk ρ is atk) (reindex-type (renamectxt-insert ρ x x') is T)
  ...| tt = let isₙ = rename-indices ρ is in
    indices-to-tplams isₙ $ reindex-type (rc-is ρ isₙ) (trie-insert is x isₙ) T
  reindex-type ρ is (TpParens pi T pi') =
    reindex-type ρ is T
  reindex-type ρ is (TpVar pi x) =
    TpVar pi $ renamectxt-rep ρ x
  
  reindex-kind ρ is (KndParens pi k pi') =
    reindex-kind ρ is k
  reindex-kind ρ is (KndArrow k k') =
    KndArrow (reindex-kind ρ is k) (reindex-kind ρ is k')
  reindex-kind ρ is (KndPi pi pi' x atk k) with is-index-var x
  ...| ff = let x' = reindex-fresh-var ρ is x in
    KndPi pi pi' x' (reindex-tk ρ is atk) (reindex-kind (renamectxt-insert ρ x x') is k)
  ...| tt = let isₙ = rename-indices ρ is in
    indices-to-kind isₙ $ reindex-kind (rc-is ρ isₙ) (trie-insert is x isₙ) k
  reindex-kind ρ is (KndTpArrow (TpVar pi x) k) with is-index-type-var x
  ...| ff = KndTpArrow (reindex-type ρ is (TpVar pi x)) (reindex-kind ρ is k)
  ...| tt = let isₙ = rename-indices ρ is in
    indices-to-kind isₙ $ reindex-kind (rc-is ρ isₙ) is k
  reindex-kind ρ is (KndTpArrow T k) =
    KndTpArrow (reindex-type ρ is T) (reindex-kind ρ is k)
  reindex-kind ρ is (KndVar pi x as) =
    KndVar pi (renamectxt-rep ρ x) (reindex-args ρ is as)
  reindex-kind ρ is (Star pi) =
    Star pi
  
  reindex-tk ρ is (Tkt T) = Tkt $ reindex-type ρ is T
  reindex-tk ρ is (Tkk k) = Tkk $ reindex-kind ρ is k
  
  -- Can't reindex large indices in a lifting type (LiftPi requires a type, not a tk),
  -- so for now we will just ignore reindexing lifting types.
  -- Types withing lifting types will still be reindexed, though.
  reindex-liftingType ρ is (LiftArrow lT lT') =
    LiftArrow (reindex-liftingType ρ is lT) (reindex-liftingType ρ is lT')
  reindex-liftingType ρ is (LiftParens pi lT pi') =
    reindex-liftingType ρ is lT
  reindex-liftingType ρ is (LiftPi pi x T lT) =
    let x' = reindex-fresh-var ρ is x in
    LiftPi pi x' (reindex-type ρ is T) (reindex-liftingType (renamectxt-insert ρ x x') is lT)
  reindex-liftingType ρ is (LiftStar pi) =
    LiftStar pi
  reindex-liftingType ρ is (LiftTpArrow T lT) =
    LiftTpArrow (reindex-type ρ is T) (reindex-liftingType ρ is lT)
  
  reindex-optTerm ρ is NoTerm = NoTerm
  reindex-optTerm ρ is (SomeTerm t pi) = SomeTerm (reindex-term ρ is t) pi
  
  reindex-optType ρ is NoType = NoType
  reindex-optType ρ is (SomeType T) = SomeType (reindex-type ρ is T)
  
  reindex-optClass ρ is NoClass = NoClass
  reindex-optClass ρ is (SomeClass atk) = SomeClass (reindex-tk ρ is atk)
  
  reindex-optGuide ρ is NoGuide = NoGuide
  reindex-optGuide ρ is (Guide pi x T) =
    let x' = reindex-fresh-var ρ is x in
    Guide pi x' (reindex-type (renamectxt-insert ρ x x') is T)
  
  reindex-lterms ρ is (LtermsNil pi) = LtermsNil pi
  reindex-lterms ρ is (LtermsCons me t ts) =
    LtermsCons me (reindex-term ρ is t) (reindex-lterms ρ is ts)

  reindex-theta ρ is (AbstractVars xs) = maybe-else Abstract AbstractVars $ reindex-vars ρ is $ just xs
  reindex-theta ρ is θ = θ

  reindex-vars''' : vars → vars → vars
  reindex-vars''' (VarsNext x xs) xs' = VarsNext x $ reindex-vars''' xs xs'
  reindex-vars''' (VarsStart x) xs = VarsNext x xs
  reindex-vars'' : vars → maybe vars
  reindex-vars'' (VarsNext x (VarsStart x')) = just $ VarsStart x
  reindex-vars'' (VarsNext x xs) = maybe-map (VarsNext x) $ reindex-vars'' xs
  reindex-vars'' (VarsStart x) = nothing
  reindex-vars' : renamectxt → trie indices → var → maybe vars
  reindex-vars' ρ is x = maybe-else (just $ VarsStart $ renamectxt-rep ρ x)
    (reindex-vars'' ∘ flip foldr (VarsStart "") λ {(Index x atk) → VarsNext x}) (trie-lookup is x)
  reindex-vars ρ is (just (VarsStart x)) = reindex-vars' ρ is x
  reindex-vars ρ is (just (VarsNext x xs)) = maybe-else (reindex-vars ρ is $ just xs)
    (λ xs' → maybe-map (reindex-vars''' xs') $ reindex-vars ρ is $ just xs) $ reindex-vars' ρ is x
  reindex-vars ρ is nothing = nothing
  
  reindex-arg ρ is (TermArg me t) = TermArg me (reindex-term ρ is t)
  reindex-arg ρ is (TypeArg T) = TypeArg (reindex-type ρ is T)
  
  reindex-args ρ is ArgsNil = ArgsNil
  reindex-args ρ is (ArgsCons a as) = ArgsCons (reindex-arg ρ is a) (reindex-args ρ is as)
  
  reindex-defTermOrType ρ is (DefTerm pi x oT t) =
    let x' = reindex-fresh-var ρ is x in
    DefTerm pi x' (reindex-optType ρ is oT) (reindex-term ρ is t) , renamectxt-insert ρ x x'
  reindex-defTermOrType ρ is (DefType pi x k T) =
    let x' = reindex-fresh-var ρ is x in
    DefType pi x (reindex-kind ρ is k) (reindex-type ρ is T) , renamectxt-insert ρ x x'

  reindex-cmds : renamectxt → trie indices → cmds → cmds × renamectxt
  reindex-cmds ρ is CmdsStart = CmdsStart , ρ
  reindex-cmds ρ is (CmdsNext (ImportCmd i) cs) =
    elim-pair (reindex-cmds ρ is cs) $ _,_ ∘ CmdsNext (ImportCmd i)
  reindex-cmds ρ is (CmdsNext (DefTermOrType op d pi) cs) =
    elim-pair (reindex-defTermOrType ρ is d) λ d' ρ' →
    elim-pair (reindex-cmds ρ' is cs) $ _,_ ∘ CmdsNext (DefTermOrType op d' pi)
  reindex-cmds ρ is (CmdsNext (DefKind pi x ps k pi') cs) =
    let x' = reindex-fresh-var ρ is x in
    elim-pair (reindex-cmds (renamectxt-insert ρ x x') is cs) $ _,_ ∘ CmdsNext
      (DefKind pi x' ps (reindex-kind ρ is k) pi')
  reindex-cmds ρ is (CmdsNext (DefDatatype dt pi) cs) =
    reindex-cmds ρ is cs -- Templates can't use datatypes!

reindex-file : ctxt → indices → start → cmds × renamectxt
reindex-file Γ is (File pi csᵢ pi' pi'' x ps cs pi''') =
  reindex-cmds empty-renamectxt empty-trie cs
  where open reindexing Γ is




mk-erased-ctr : ctxt → ℕ → constructors → 𝕃 term → maybe term
mk-erased-ctr Γ n cs as = mk-erased-ctrh Γ (inj₁ n) cs as [] where
  mk-erased-ctrh : ctxt → ℕ ⊎ var → constructors → 𝕃 term → 𝕃 var → maybe term
  mk-erased-ctrh Γ (inj₁ zero) (Ctr x _ :: cs) as xs = rename x from Γ for λ x' →
    mk-erased-ctrh (ctxt-var-decl x' Γ) (inj₂ x') cs as (x' :: xs)
  mk-erased-ctrh Γ (inj₁ (suc n)) (Ctr x _ :: cs) as xs = rename x from Γ for λ x' →
    mk-erased-ctrh (ctxt-var-decl x' Γ) (inj₁ n) cs as (x' :: xs)
  mk-erased-ctrh Γ (inj₂ xₕ) (Ctr x _ :: cs) as xs = rename x from Γ for λ x' →
    mk-erased-ctrh (ctxt-var-decl x' Γ) (inj₂ xₕ) cs as (x' :: xs)
  mk-erased-ctrh Γ (inj₁ _) [] as xs = nothing
  mk-erased-ctrh Γ (inj₂ xₕ) [] as xs =
    just $ foldl mlam (foldr (flip mapp) (mvar xₕ) as) $ xs

get-ctr-in-ctrs : var → constructors → maybe ℕ
get-ctr-in-ctrs x cs = h zero cs where
  h : ℕ → constructors → maybe ℕ
  h n [] = nothing
  h n (Ctr y _ :: cs) = if x =string y then just n else h (suc n) cs

mk-ctr-untyped-beta : ctxt → var → constructors → parameters → term
mk-ctr-untyped-beta Γ x cs ps =
  maybe-else
    (mvar "error-making-untyped-beta")
    (λ t → Beta posinfo-gen NoTerm $ SomeTerm t posinfo-gen) $
    get-ctr-in-ctrs x cs ≫=maybe λ n → mk-erased-ctr Γ n cs $
      foldl (λ {(Decl pi pi' NotErased x (Tkt T) pi'') ts → mvar x :: ts; p ts → ts}) [] ps

mk-ctr-type : ctxt → ctr → (head : var) → constructors → type
mk-ctr-type Γ (Ctr x T) Tₕ cs with decompose-ctr-type Γ T
...| Tₓ , ps , is =
  foldr
    (λ {(Decl pi pi' NotErased y atk pi'') f as →
          Abs pi NotErased pi' y atk $ f (mvar y :: as);
        (Decl pi pi' Erased y atk pi'') f as →
          Abs pi Erased pi' y atk $ f as})
    (λ as → curry recompose-tpapps
      (TpAppt (mtpvar Tₕ) $ maybe-else
        (mvar "error-making-ctr-type-beta")
        (λ t → Beta posinfo-gen NoTerm $ SomeTerm t posinfo-gen)
        (get-ctr-in-ctrs x cs ≫=maybe λ n → mk-erased-ctr Γ n cs as)) is) ps []

record encoded-datatype : Set where
  constructor mk-encoded-datatype
  field
    data-def : datatype
    data-functor : var
    data-fmap : var
    functor : var
    cast : var
    fixed-point : var
    in-fix : var
    induction-principle : var
  x  = case data-def of λ where (Data x ps is cs) → x
  ps = case data-def of λ where (Data x ps is cs) → ps
  is = case data-def of λ where (Data x ps is cs) → is
  cs = case data-def of λ where (Data x ps is cs) → cs

record datatype-encoding : Set where
  constructor mk-datatype-encoding
  field
    template : start
    functor : var
    cast : var
    fixed-point : var
    in-fix : var
    induction-principle : var
    elab-check-mu : ctxt → var → term → optType → cases → type → maybe term
    elab-check-mu' : ctxt → term → optType → cases → type → maybe term
    elab-synth-mu : ctxt → var → term → optType → cases → maybe (term × type)
    elab-synth-mu' : ctxt → term → optType → cases → maybe (term × type)

  mk-defs : ctxt → datatype → cmds × encoded-datatype
  mk-defs Γ' (Data x ps is cs) = append-cmds tcs
    (csn functor-cmd $ csn fmap-cmd $ csn type-cmd $ foldr (csn ∘ ctr-cmd) CmdsStart cs) ,
    record {
      data-def = Data x ps is cs;
      data-functor = data-functorₓ;
      data-fmap = data-fmapₓ;
      functor = functorₓ;
      cast = castₓ;
      fixed-point = fixed-pointₓ;
      in-fix = in-fixₓ;
      induction-principle = induction-principleₓ}
    where
    csn = CmdsNext ∘ flip (DefTermOrType OpacTrans) posinfo-gen
    k = indices-to-kind is $ Star posinfo-gen
    
    Γ = add-parameters-to-ctxt ps $ add-constructors-to-ctxt cs $ ctxt-var-decl x Γ'
    
    tcs-ρ = reindex-file Γ is template
    tcs = fst tcs-ρ
    ρ' = snd tcs-ρ

    data-functorₓ = fresh-var (x ^ "F") (ctxt-binds-var Γ) ρ'
    data-fmapₓ = fresh-var (x ^ "Fmap") (ctxt-binds-var Γ) ρ'
    functorₓ = renamectxt-rep ρ' functor
    castₓ = renamectxt-rep ρ' cast
    fixed-pointₓ = renamectxt-rep ρ' fixed-point
    in-fixₓ = renamectxt-rep ρ' in-fix
    induction-principleₓ = renamectxt-rep ρ' induction-principle
    ρ = renamectxt-insert (renamectxt-insert ρ' (x ^ "F") data-functorₓ) (x ^ "Fmap") data-fmapₓ
    
    new-var : ∀ {ℓ} {X : Set ℓ} → var → (var → X) → X
    new-var x f = f $ fresh-var x (ctxt-binds-var $ add-indices-to-ctxt is Γ) ρ

    functor-cmd = DefType posinfo-gen data-functorₓ (parameters-to-kind ps $ KndArrow k k) $
      parameters-to-tplams ps $
      TpLambda posinfo-gen posinfo-gen x (Tkk $ k) $
      indices-to-tplams is $
      new-var "x" λ xₓ →
      Iota posinfo-gen posinfo-gen xₓ (mtpeq id-term id-term) $
      new-var "X" λ Xₓ →
      Abs posinfo-gen Erased posinfo-gen Xₓ
        (Tkk $ KndTpArrow (mtpeq id-term id-term) $ indices-to-kind is star) $
      foldr (λ c → flip TpArrow NotErased $ mk-ctr-type (ctxt-var-decl Xₓ Γ) c Xₓ cs)
        (indices-to-tpapps is $ TpAppt (mtpvar Xₓ) (mvar xₓ)) cs
    
    fmap-cmd : defTermOrType
    fmap-cmd with new-var "A" id | new-var "B" id | new-var "c" id
    ...| Aₓ | Bₓ | cₓ = DefTerm posinfo-gen data-fmapₓ (SomeType $
        parameters-to-alls ps $
        TpApp (mtpvar functorₓ) $
        parameters-to-tpapps ps $
        mtpvar data-functorₓ) $
      parameters-to-lams ps $
      Mlam Aₓ $ Mlam Bₓ $ Mlam cₓ $
      IotaPair posinfo-gen
        (indices-to-lams is $
         new-var "x" λ xₓ → mlam xₓ $
         IotaPair posinfo-gen (IotaProj (mvar xₓ) "1" posinfo-gen)
           (new-var "X" λ Xₓ → Mlam Xₓ $
             constructors-to-lams' cs $
             foldl
               (flip mapp ∘ eta-expand-fmap)
               (AppTp (IotaProj (mvar xₓ) "2" posinfo-gen) $ mtpvar Xₓ) cs)
          NoGuide posinfo-gen)
        (Beta posinfo-gen NoTerm NoTerm) NoGuide posinfo-gen
      where
      eta-expand-fmaph-type : ctxt → var → type → term
      eta-expand-fmaph-type Γ x' T with decompose-ctr-type Γ T
      ...| Tₕ , ps , as with add-parameters-to-ctxt ps Γ
      ...| Γ' =
        parameters-to-lams' ps $
        flip mapp (parameters-to-apps ps $ mvar x') $
        recompose-apps Erased as $
        flip mappe (mvar cₓ) $
        flip AppTp (mtpvar Bₓ) $
        AppTp (mvar castₓ) (mtpvar Aₓ)

      eta-expand-fmap : ctr → term
      eta-expand-fmap (Ctr x' T) with
        ctxt-var-decl Aₓ $ ctxt-var-decl Bₓ $ ctxt-var-decl cₓ Γ
      ...| Γ' with decompose-ctr-type Γ' T
      ...| Tₕ , ps , as with foldr (λ {(Decl _ _ _ x'' _ _) → ctxt-var-decl x''}) Γ' ps
      ...| Γ'' = parameters-to-lams' ps $ foldl
        (λ {(Decl pi pi' me x'' (Tkt T) pi'') t → App t me $
              if ~ is-free-in tt x T then mvar x'' else eta-expand-fmaph-type Γ'' x'' T;
            (Decl pi pi' me x'' (Tkk k) pi'') t → AppTp t $ mtpvar x''})
        (mvar x') $ ps

    type-cmd = DefType posinfo-gen x (parameters-to-kind ps $ k) $
      parameters-to-tplams ps $ TpAppt
        (TpApp (mtpvar fixed-pointₓ) $ parameters-to-tpapps ps $ mtpvar data-functorₓ)
        (parameters-to-apps ps $ mvar data-fmapₓ)

    ctr-cmd : ctr → defTermOrType
    ctr-cmd (Ctr x' T) with
        decompose-ctr-type Γ (subst Γ (parameters-to-tpapps ps $ mtpvar x) x T)
    ...| Tₕ , ps' , as' = DefTerm posinfo-gen x' NoType $
      parameters-to-lams ps $
      parameters-to-lams ps' $
      mapp (recompose-apps Erased (take (length as' ∸ length ps) as') $
            mappe (AppTp (mvar in-fixₓ) $
              parameters-to-tpapps ps $ mtpvar data-functorₓ) $
        parameters-to-apps ps $ mvar data-fmapₓ) $
      let Γ' = add-parameters-to-ctxt ps' Γ
          Xₓ = rename "X" from Γ' for id in
      IotaPair posinfo-gen
        (mk-ctr-untyped-beta Γ' x' cs ps')
        (Mlam Xₓ $
         constructors-to-lams' cs $
         parameters-to-apps ps' $
         mvar x')
        NoGuide posinfo-gen

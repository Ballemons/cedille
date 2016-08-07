module classify where

open import lib

open import cedille-types
open import constants
open import conversion
open import ctxt
open import is-free
open import lift
open import rename
open import rewriting-new
open import spans
open import subst
open import syntax-util
open import to-string

check-ret : ∀{A : Set} → maybe A → Set
check-ret{A} nothing = maybe A
check-ret (just _) = ⊤

infixl 2 _≫=spanr_ 
_≫=spanr_ : ∀{A : Set}{m : maybe A} → spanM (maybe A) → (A → spanM (check-ret m)) → spanM (check-ret m)
_≫=spanr_{m = nothing} = _≫=spanm_
_≫=spanr_{m = just _} = _≫=spanj_

check-fail : ∀{A : Set} → (m : maybe A) → spanM (check-ret m)
check-fail nothing = spanMr nothing
check-fail (just _) = spanMok

unimplemented-check : spanM ⊤
unimplemented-check = spanMok

unimplemented-synth : ∀{A : Set} → spanM (maybe A)
unimplemented-synth = spanMr nothing

unimplemented-if : ∀{A : Set} → (m : maybe A) → spanM (check-ret m)
unimplemented-if nothing = unimplemented-synth
unimplemented-if (just _) = unimplemented-check

-- return the second maybe kind
return-when : ∀{A : Set} → (m : maybe A) → maybe A → spanM (check-ret m)
return-when nothing u = spanMr u
return-when (just _) u = spanMr triv

return-star-when : (m : maybe kind) → spanM (check-ret m)
return-star-when m = return-when m (just star)

if-check-against-star-data : string → maybe kind → 𝕃 tagged-val
if-check-against-star-data desc nothing = [ kind-data star ]
if-check-against-star-data desc (just (Star _)) = [ kind-data star ]
if-check-against-star-data desc (just k) = error-data (desc ^ " is being checked against a kind other than ★")
                                        :: expected-kind k
                                        :: []

check-term-app-erased-error : checking-mode → maybeErased → term → term → type → spanM (maybe type)
check-term-app-erased-error c m t t' head-tp =
  spanM-add (App-span t t' c
               (error-data (msg m) 
                 :: term-app-head t 
                 :: head-type head-tp
                 :: [])) ≫span
  spanMr nothing
  where msg : maybeErased → string
        msg Erased = ("The type computed for the head requires" 
                    ^ " an explicit (non-erased) argument, but the application"
                    ^ " is marked as erased")
        msg NotErased = ("The type computed for the head requires" 
                    ^ " an implicit (erased) argument, but the application"
                    ^ " is marked as not erased")

check-term-app-matching-erasures : maybeErased → binder → 𝔹
check-term-app-matching-erasures Erased All = tt
check-term-app-matching-erasures NotErased Pi = tt
check-term-app-matching-erasures _ _ = ff

hnf-from : ctxt → maybeMinus → term → term
hnf-from Γ EpsHnf t = hnf Γ unfold-head t
hnf-from Γ EpsHanf t = hanf Γ t

check-term-update-eq : ctxt → leftRight → maybeMinus → term → term → type
check-term-update-eq Γ Left m t1 t2 = TpEq (hnf-from Γ m t1) t2
check-term-update-eq Γ Right m t1 t2 = TpEq t1 (hnf-from Γ m t2) 
check-term-update-eq Γ Both m t1 t2 = TpEq (hnf-from Γ m t1) (hnf-from Γ m t2) 

-- a simple incomplete check for beta-inequivalence
{-# NO_TERMINATION_CHECK #-}
check-beta-inequivh : stringset → stringset → renamectxt → term → term → 𝔹
check-beta-inequivh local-left local-right m (Lam _ _ _ x1 _ t1) (Lam _ _ _ x2 _ t2) = 
  check-beta-inequivh (stringset-insert local-left x1) (stringset-insert local-right x2) (renamectxt-insert m x1 x2) t1 t2
check-beta-inequivh local-left local-right m (Lam _ _ _ x1 _ t1) t2 = 
  check-beta-inequivh (stringset-insert local-left x1) (stringset-insert local-right x1) m t1 (mapp t2 (mvar x1))
check-beta-inequivh local-left local-right m t1 (Lam _ _ _ x2 _ t2) = 
  check-beta-inequivh (stringset-insert local-left x2) (stringset-insert local-right x2) m (mapp t1 (mvar x2)) t2
check-beta-inequivh local-left local-right m t1 t2 with decompose-apps t1 | decompose-apps t2 
check-beta-inequivh local-left local-right m t1 t2 | Var _ x1 , args1 | Var _ x2 , args2 = 
  (~ eq-var m x1 x2) && (stringset-contains local-left x1) && (stringset-contains local-right x2)
check-beta-inequivh local-left local-right m t1 t2 | _ | _ = ff 

-- t1 and t2 should be in normal form
check-beta-inequiv : term → term → 𝔹
check-beta-inequiv t1 t2 = check-beta-inequivh empty-trie empty-trie empty-renamectxt t1 t2

PiInj-err1 : string → ℕ → type ⊎ string
PiInj-err1 s n =
 inj₂ ("The lhs and rhs are headed by the same bound variable, but the " 
       ^ s ^ " does not have an argument in position " ^ (ℕ-to-string n) ^ ".")
PiInj-err2 : string → term → type ⊎ string
PiInj-err2 s t =
  inj₂ ("The body of the " ^ s ^ ", which is " ^ (term-to-string tt t) ^ ", is not headed by a bound variable.")

{- we will drop the list of vars (the ones bound in the head-normal form we are considering)
   from the context, because decompose-var-headed is going to check
   that the head is not a variable declared in the context. -}
PiInj-decompose-app : ctxt → 𝕃 var → term → maybe (var × 𝕃 term)
PiInj-decompose-app Γ vs t with decompose-var-headed (ctxt-binds-var (ctxt-clear-symbols Γ vs)) t
PiInj-decompose-app Γ _ t | just (x , args) = just (x , reverse args)
PiInj-decompose-app Γ _ t | nothing = nothing

PiInj-try-project : ctxt → ℕ → term → term → type ⊎ string
PiInj-try-project Γ n t1 t2 with decompose-lams t1 | decompose-lams t2
PiInj-try-project Γ n t1 t2 | vs1 , body1 | vs2 , body2 with renamectxt-insert* empty-renamectxt vs1 vs2 
PiInj-try-project Γ n t1 t2 | vs1 , body1 | vs2 , body2 | nothing = 
  inj₂ ("The lhs and rhs bind different numbers of variables.")
PiInj-try-project Γ n t1 t2 | vs1 , body1 | vs2 , body2 | just ρ 
  with PiInj-decompose-app Γ vs1 body1 | PiInj-decompose-app Γ vs2 body2
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , args1) | just (h2 , args2) with eq-var ρ h1 h2
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , args1) | just (h2 , args2) | ff =
  inj₂ "The lhs and rhs are headed by different bound variables."
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , args1) | just (h2 , args2) | tt 
  with nth n args1 | nth n args2 
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , args1) | just (h2 , args2) | tt | nothing | _ =
  PiInj-err1 "lhs" n
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , args1) | just (h2 , args2) | tt | _ | nothing =
  PiInj-err1 "rhs" n
PiInj-try-project Γ n t1 t2 | vs1 , _ | vs2 , _ | just ρ | just (h1 , _) | just (h2 , _) | tt | just a1 | just a2 =
  let rebuild : 𝕃 var → term → term
      -- the call to hnf with no-unfolding will have the effect of eta-contracting the new lambda abstraction
      rebuild vs a = (hnf Γ no-unfolding (Lam* (reverse vs) a)) in
  inj₁ (TpEq (rebuild vs1 a1) (rebuild vs2 a2))
PiInj-try-project Γ n t1 t2 | vs1 , body1 | vs2 , body2 | just ρ | nothing | _ = 
  PiInj-err2 "lhs" body1
PiInj-try-project Γ n t1 t2 | vs1 , body1 | vs2 , body2 | just ρ | _ | nothing =
  PiInj-err2 "rhs" body2

{- if the hnf of the type is a Iota type, then instantiate it with the given term.
   We assume types do not reduce with normalization and instantiation to further iota
   types.  Also, if allow-typed-iota is true, we will instantiate a iota type where the
   iota-bound variable has a type; otherwise, we won't-}
hnf-instantiate-iota : ctxt → term → type → (allow-typed-iota : 𝔹) → type
hnf-instantiate-iota Γ subject tp allow with hnf Γ unfold-head-rec-defs tp
hnf-instantiate-iota Γ subject _ tt | Iota _ x _ t = hnf Γ unfold-head (subst-type Γ subject x t)
hnf-instantiate-iota Γ subject _ ff | Iota _ x NoClass t = hnf Γ unfold-head (subst-type Γ subject x t)
hnf-instantiate-iota Γ subject _ _ | tp = tp

add-tk : posinfo → var → tk → spanM ⊤
add-tk pi x atk =
  get-ctxt (λ Γ → 
    spanM-add (var-span Γ pi x checking atk) ≫span  
    (if (x =string ignored-var) then spanMok else set-ctxt (helper Γ atk)))
  where helper : ctxt → tk → ctxt
        helper Γ (Tkk k) = ctxt-type-decl pi x k Γ
        helper Γ (Tkt t) = ctxt-term-decl pi x t Γ

check-type-return : ctxt → kind → spanM (maybe kind)
check-type-return Γ k = spanMr (just (hnf Γ unfold-head k))

check-termi-return : ctxt → (subject : term) → type → spanM (maybe type)
check-termi-return Γ subject tp = spanMr (just (hnf Γ unfold-head tp))

lambda-bound-var-conv-error : var → tk → tk → 𝕃 tagged-val → 𝕃 tagged-val
lambda-bound-var-conv-error x atk atk' tvs = 
    ( error-data "The classifier given for a λ-bound variable is not the one we expected"
 :: ("the variable" , x)
 :: ("its declared classifier" , tk-to-string atk')
 :: [ "the expected classifier" , tk-to-string atk ]) ++ tvs

lambda-bound-class-if : optClass → tk → tk
lambda-bound-class-if NoClass atk = atk
lambda-bound-class-if (SomeClass atk') atk = atk'

var-spans-term : ctxt → term → spanM ⊤
var-spans-term Γ (App t x t') = var-spans-term Γ t ≫span var-spans-term Γ t'
var-spans-term Γ (AppTp t x) = var-spans-term Γ t 
var-spans-term Γ (Beta x) = spanMok
var-spans-term Γ (Chi x x₁ t) = var-spans-term Γ t
var-spans-term Γ (Delta x t) = var-spans-term Γ t
var-spans-term Γ (Epsilon x x₁ x₂ t) = var-spans-term Γ t
var-spans-term Γ (Hole x) = spanMok
var-spans-term Γ (Lam _ _ pi' x _ t) = var-spans-term (ctxt-var-decl pi' x Γ) t
var-spans-term Γ (Parens x t x₁) = var-spans-term Γ t
var-spans-term Γ (PiInj x x₁ t) = var-spans-term Γ t
var-spans-term Γ (Rho _ _ t t') = var-spans-term Γ t ≫span var-spans-term Γ t'
var-spans-term Γ (Sigma x t) = var-spans-term Γ t
var-spans-term Γ (Theta x x₁ t x₂) = var-spans-term Γ t
var-spans-term Γ (Var pi x) = spanM-add (Var-span Γ pi x untyped [])

{- for check-term and check-type, if the optional classifier is given, we will check against it.
   Otherwise, we will try to synthesize a type.  

   check-termi does not have to worry about normalizing the type it is given or the one it
   produces, nor about instantiating with the subject.  This will be handled by interleaved 
   calls to check-term.

   check-type should return kinds in hnf using check-type-return.

   Use add-tk above to add declarations to the ctxt, since these should be normalized
   and with self-types instantiated.
 -}
{-# NO_TERMINATION_CHECK #-}
check-term : term → (m : maybe type) → spanM (check-ret m)
check-termi : term → (m : maybe type) → spanM (check-ret m)
check-type : type → (m : maybe kind) → spanM (check-ret m)
check-typei : type → (m : maybe kind) → spanM (check-ret m)
check-kind : kind → spanM ⊤
check-tk : tk → spanM ⊤

check-term subject nothing = check-termi subject nothing ≫=span cont
  where cont : maybe type → spanM (maybe type)
        cont (just tp) = get-ctxt (λ Γ → spanMr (just (hnf Γ unfold-head tp)))
        cont nothing = spanMr nothing 
check-term subject (just tp) =
  get-ctxt (λ Γ → 
    check-termi subject (just (if is-intro-form subject then (hnf-instantiate-iota Γ subject tp ff) else (hnf Γ unfold-head tp))))

check-type subject nothing = check-typei subject nothing
check-type subject (just k) = get-ctxt (λ Γ → check-typei subject (just (hnf Γ unfold-head k)))

check-termi (Parens pi t pi') tp =
  spanM-add (punctuation-span "Parens" pi pi') ≫span
  check-term t tp
check-termi (Var pi x) mtp =
  get-ctxt (cont mtp)
  where cont : (mtp : maybe type) → ctxt → spanM (check-ret mtp)
        cont mtp Γ with ctxt-lookup-term-var Γ x
        cont mtp Γ | nothing = 
         spanM-add (Var-span Γ pi x (maybe-to-checking mtp)
                      (error-data "Missing a type for a term variable." :: 
                       expected-type-if mtp (missing-type :: []))) ≫span
         return-when mtp mtp
        cont nothing Γ | just tp = 
          spanM-add (Var-span Γ pi x synthesizing ((type-data tp) :: [ hnf-type Γ tp ])) ≫span
          check-termi-return Γ (Var pi x) tp
        cont (just tp) Γ | just tp' = 
          spanM-add (Var-span Γ pi x checking
               (if conv-type Γ tp tp' then (expected-type tp :: [ type-data tp' ])
                 else (error-data "The computed type does not match the expected type." :: 
                       expected-type tp :: 
                       type-data tp' :: (hnf-expected-type Γ tp)
                       :: (hnf-type Γ tp') :: [])))

check-termi (AppTp t tp') tp =
  check-term t nothing ≫=spanm (λ htp → get-ctxt (λ Γ → cont (hnf-instantiate-iota Γ t htp tt))) ≫=spanr cont' tp 
  where cont : type → spanM (maybe type)
        cont (Abs pi b pi' x (Tkk k) tp2) = 
           check-type tp' (just k) ≫span 
           get-ctxt (λ Γ → spanMr (just (subst-type Γ tp' x tp2)))
        cont tp'' = spanM-add (AppTp-span t tp' (maybe-to-checking tp)
                               (error-data ("The type computed for the head of the application does"
                                        ^ " not allow the head to be applied to the (type) argument ")
                            :: term-app-head t
                            :: head-type tp'' 
                            :: type-argument tp'
                            :: [])) ≫span
                  spanMr nothing
        cont' : (outer : maybe type) → type → spanM (check-ret outer)
        cont' nothing tp'' = 
          get-ctxt (λ Γ → 
            spanM-add (AppTp-span t tp' synthesizing ((type-data (hnf Γ unfold-head tp'')) :: [])) ≫span
            check-termi-return Γ (AppTp t tp') tp'')
        cont' (just tp) tp'' = 
          get-ctxt (λ Γ → 
            if conv-type Γ tp tp'' then spanM-add (AppTp-span t tp' checking (expected-type tp :: [ type-data tp'' ]))
            else spanM-add (AppTp-span t tp' checking 
                           (error-data "The type computed for a term application does not match the expected type." ::
                            expected-type tp ::
                            type-data tp'' ::
                            [])))
  
check-termi (App t m t') tp =
  check-term t nothing ≫=spanm (λ htp → get-ctxt (λ Γ → cont m (hnf-instantiate-iota Γ t htp tt))) ≫=spanr cont' tp 
  where cont : maybeErased → type → spanM (maybe type)
        cont NotErased (TpArrow tp1 tp2) = 
          check-term t' (just tp1) ≫span 
          get-ctxt (λ Γ → 
            check-termi-return Γ (App t m t') tp2)
        cont Erased (TpArrow tp1 tp2) = 
          check-term-app-erased-error (maybe-to-checking tp) Erased t t' (TpArrow tp1 tp2)
        cont m (Abs pi b pi' x (Tkt tp1) tp2) = 
          if check-term-app-matching-erasures m b then
             (check-term t' (just tp1) ≫span 
              get-ctxt (λ Γ → 
                check-termi-return Γ (App t m t') (subst-type Γ t' x tp2)))
          else
            check-term-app-erased-error (maybe-to-checking tp) m t t' (Abs pi b pi' x (Tkt tp1) tp2)
        cont m tp' = spanM-add (App-span t t' (maybe-to-checking tp)
                               (error-data ("The type computed for the head of the application does"
                                        ^ " not allow the head to be applied to " ^ h m ^ " argument ")
                            :: term-app-head t
                            :: head-type tp' 
                            :: term-argument t'
                            :: [])) ≫span
                  spanMr nothing
                  where h : maybeErased → string
                        h Erased = "an erased term"
                        h NotErased = "a term"
        -- the type should already be normalized and instantiated
        cont' : (outer : maybe type) → type → spanM (check-ret outer)
        cont' nothing tp' = 
          spanM-add (App-span t t' synthesizing [ type-data tp' ]) ≫span 
          spanMr (just tp') -- already normalizedby cont
        cont' (just tp) tp' = 
          get-ctxt (λ Γ → 
            if conv-type Γ tp tp' then spanM-add (App-span t t' checking (expected-type tp :: type-data tp' :: []))
            else spanM-add (App-span t t' checking
                           (error-data "The type computed for a term application does not match the expected type." ::
                            expected-type tp ::
                            type-data tp' :: 
                            hnf-expected-type-if Γ (just tp) [])))
check-termi (Lam pi l pi' x (SomeClass atk) t) nothing =
  spanM-add (punctuation-span "Lambda" pi (posinfo-plus pi 1)) ≫span
  check-tk atk ≫span
  get-ctxt (λ Γ → -- save the context here
    add-tk pi' x atk ≫span 
    check-term t nothing ≫=span (λ mtp → 
    set-ctxt Γ ≫span -- now restore the context
    cont mtp))

  where cont : maybe type → spanM (maybe type)
        cont nothing = spanM-add (Lam-span pi l x (SomeClass atk) t []) ≫span 
                       spanMr nothing
        cont (just tp) = 
          let rettp = abs-tk l x atk tp in
          let tvs = [ type-data rettp ] in
          spanM-add (Lam-span pi l x (SomeClass atk) t 
                       (if (lam-is-erased l) && (is-free-in-term skip-erased x t) then
                           (error-data "The bound variable occurs free in the erasure of the body (not allowed)."
                         :: erasure t :: tvs)
                        else tvs)) ≫span
          get-ctxt (λ Γ → 
            check-termi-return Γ (Lam pi l pi' x (SomeClass atk) t) rettp)

check-termi (Lam pi l _ x NoClass t) nothing =
            spanM-add (punctuation-span "Lambda" pi (posinfo-plus pi 1)) ≫span
  spanM-add (Lam-span pi l x NoClass t [ error-data ("We are not checking this abstraction against a type, so a classifier must be"
                                                  ^ " given for the bound variable " ^ x) ]) ≫span
  spanMr nothing

check-termi (Lam pi l pi' x oc t) (just tp) with to-abs tp 
check-termi (Lam pi l pi' x oc t) (just tp) | just (mk-abs pi'' b pi''' x' atk _ tp') =
  check-oc oc ≫span
  spanM-add (punctuation-span "Lambda" pi (posinfo-plus pi 1)) ≫span
  get-ctxt (λ Γ →  -- save the context
    spanM-add (this-span Γ oc (check-erasures l b)) ≫span
    add-tk pi' x (lambda-bound-class-if oc atk) ≫span 
      check-term t (just (rename-type Γ x' x (tk-is-type atk) tp')) ≫span
      set-ctxt Γ) -- restore the saved context

  where this-span : ctxt → optClass → 𝕃 tagged-val → span
        this-span _ NoClass tvs = Lam-span pi l x oc t tvs
        this-span Γ (SomeClass atk') tvs = 
          if conv-tk Γ atk' atk then
            Lam-span pi l x oc t tvs
          else
            Lam-span pi l x oc t (lambda-bound-var-conv-error x atk atk' tvs)
        check-oc : optClass → spanM ⊤
        check-oc NoClass = spanMok
        check-oc (SomeClass atk) = check-tk atk
        check-erasures : lam → binder → 𝕃 tagged-val
        check-erasures ErasedLambda All = type-data tp 
                                       :: (if (is-free-in-term skip-erased x t) then 
                                            (error-data "The Λ-bound variable occurs free in the erasure of the body." 
                                            :: [ erasure t ])
                                           else [])
        check-erasures KeptLambda Pi = [ type-data tp ]
        check-erasures ErasedLambda Pi = error-data ("The expected type is a Π-abstraction (indicating explicit input), but"
                                              ^ " the term is a Λ-abstraction (implicit input).")
                                     :: [ expected-type tp ]
        check-erasures KeptLambda All = error-data ("The expected type is a ∀-abstraction (indicating implicit input), but"
                                              ^ " the term is a λ-abstraction (explicit input).")
                                     :: [ expected-type tp ]

check-termi (Lam pi l _ x oc t) (just tp) | nothing =
  spanM-add (punctuation-span "Lambda"  pi (posinfo-plus pi 1)) ≫span
  spanM-add (Lam-span pi l x oc t (error-data "The expected type is not of the form that can classify a λ-abstraction" ::
                                   expected-type tp :: []))

check-termi (Beta pi) (just (TpEq t1 t2)) = 
  get-ctxt (λ Γ → 
    if conv-term Γ t1 t2 then
      spanM-add (Beta-span pi checking [ type-data (TpEq t1 t2) ])
    else
      spanM-add (Beta-span pi checking (error-data "The two terms in the equation are not β-equal" :: [ expected-type (TpEq t1 t2) ])))

check-termi (Beta pi) (just tp) = 
  spanM-add (Beta-span pi checking (error-data "The expected type is not an equation." :: [ expected-type tp ]))

check-termi (Beta pi) nothing = 
  spanM-add (Beta-span pi synthesizing [ error-data "An expected type is required in order to type a use of β." ]) ≫span spanMr nothing

check-termi (Delta pi t) (just tp) = 
  check-term t nothing ≫=span cont ("A delta-term is being used to derive a contradiction, but its subterm "
                                     ^ "does not prove an impossible beta-equality.")
  where cont : string → maybe type → spanM ⊤
        cont errmsg (just (TpEq t1 t2)) = 
          get-ctxt (λ Γ → 
            let t1' = hnf Γ unfold-all t1 in
            let t2' = hnf Γ unfold-all t2 in
              if check-beta-inequiv t1' t2' then
                 spanM-add (Delta-span pi t checking [ type-data tp ])
              else
                 spanM-add (Delta-span pi t checking (error-data errmsg
                                       :: ("the equality proved" , to-string (TpEq t1 t2))
                                       :: ("normalized version of the equality" , to-string (TpEq t1' t2'))
                                       :: [ expected-type tp ])))
        cont errmsg (just tp) = 
          spanM-add (Delta-span pi t checking (error-data errmsg :: [ expected-type tp ]))
        cont errmsg nothing = spanM-add (Delta-span pi t checking [ expected-type tp ])

check-termi (PiInj pi n t) mtp = 
  check-term t nothing ≫=span (λ tm → get-ctxt (λ Γ → cont Γ mtp tm))
  where cont : ctxt → (mtp : maybe type) → maybe type → spanM (check-ret mtp)
        cont Γ mtp (just (TpEq t1 t2)) with PiInj-try-project Γ (num-to-ℕ n) (hnf Γ unfold-head t1) (hnf Γ unfold-head t2)
        cont _ mtp (just (TpEq t1 t2)) | inj₂ msg = 
          spanM-add (PiInj-span pi n t (maybe-to-checking mtp)
                          ( error-data "We could not project out an equation between corresponding arguments."
                                       :: (expected-type-if mtp [ reason msg ]))) ≫span
          check-fail mtp
        cont Γ (just tp) (just (TpEq t1 t2)) | inj₁ eq = 
          (if conv-type Γ tp eq then
            spanM-add (PiInj-span pi n t checking [ type-data eq ])
           else 
            spanM-add (PiInj-span pi n t checking (type-data eq :: expected-type tp 
                                      :: [ error-data "The expected type does not match the computed type." ])))
          ≫span spanMok
        cont _ nothing (just (TpEq t1 t2)) | inj₁ eq = 
          spanM-add (PiInj-span pi n t synthesizing [ type-data eq ]) ≫span spanMr (just eq)
        cont _ mtp (just tp) =
           spanM-add (PiInj-span pi n t (maybe-to-checking mtp) (expected-type-if mtp 
                                          [ error-data ("The subterm of a pi-proof does not prove an equation.") ] )) ≫span
           check-fail mtp
        cont _ mtp nothing = spanM-add (PiInj-span pi n t (maybe-to-checking mtp) (expected-type-if mtp [])) ≫span check-fail mtp

check-termi (Epsilon pi lr m t) (just (TpEq t1 t2)) = 
  spanM-add (Epsilon-span pi lr m t checking [ type-data (TpEq t1 t2) ]) ≫span
  get-ctxt (λ Γ → 
    check-term t (just (check-term-update-eq Γ lr m t1 t2)))

check-termi (Epsilon pi lr m t) (just tp) = 
  spanM-add (Epsilon-span pi lr m t checking (error-data ("The expected type is not an equation, when checking an ε-term.") 
                                        :: [ expected-type tp ])) ≫span 
  spanMok
check-termi (Epsilon pi lr m t) nothing = 
  check-term t nothing ≫=span cont
  where cont : maybe type → spanM (maybe type)
        cont nothing = 
          spanM-add (Epsilon-span pi lr m t synthesizing [ error-data ("There is no expected type, and we could not synthesize a type from the body"
                                                           ^ " of the ε-term.") ]) ≫span
          spanMr nothing
        cont (just (TpEq t1 t2)) =
          get-ctxt (λ Γ → 
            let r = check-term-update-eq Γ lr m t1 t2 in
            spanM-add (Epsilon-span pi lr m t synthesizing [ type-data r ]) ≫span
            spanMr (just r))
        cont (just tp) = 
          spanM-add (Epsilon-span pi lr m t synthesizing ( error-data ("There is no expected type, and the type we synthesized for the body"
                                                           ^ " of the ε-term is not an equation.")
                                             :: ["the synthesized type" , to-string tp ])) ≫span
          spanMr nothing

check-termi (Sigma pi t) mt = 
  check-term t nothing ≫=span cont mt
  where cont : (outer : maybe type) → maybe type → spanM (check-ret outer)
        cont mt nothing = 
          spanM-add (Sigma-span pi t mt [ error-data ("We could not synthesize a type from the body"
                                                    ^ " of the ς-term.") ]) ≫span
          check-fail mt
        cont mt (just (TpEq t1 t2)) with TpEq t2 t1 
        cont nothing (just (TpEq t1 t2)) | r =
          spanM-add (Sigma-span pi t nothing [ type-data r ]) ≫span
          spanMr (just r)
        cont (just tp) (just (TpEq t1 t2)) | r =
          get-ctxt (λ Γ → 
            (if conv-type Γ tp r then
              spanM-add (Sigma-span pi t (just tp) [ type-data r ])
            else
              spanM-add (Sigma-span pi t (just tp) (error-data "The expected type does not match the computed type" :: [ type-data r ])))
            ≫span spanMok)
        cont mt (just tp) = 
          spanM-add (Sigma-span pi t mt ( error-data ("The type we synthesized for the body"
                                                      ^ " of the ς-term is not an equation.")
                                          :: ["the synthesized type" , to-string tp ])) ≫span
          check-fail mt

check-termi (Rho pi r t t') (just tp) = 
  check-term t nothing ≫=span cont
  where cont : maybe type → spanM ⊤
        cont nothing = spanM-add (Rho-span pi t t' checking r 0 [ expected-type tp ]) 
        cont (just (TpEq t1 t2)) = 
           get-ctxt (λ Γ →
             let s = rewrite-type Γ empty-renamectxt (is-rho-plus r) t1 t2 tp in
             check-term t' (just (fst s)) ≫span
             spanM-add (Rho-span pi t t' checking r (snd s) ( ("the equation" , to-string (TpEq t1 t2)) :: [ type-data tp ])))
        cont (just tp') = spanM-add (Rho-span pi t t' checking r 0
                                       (error-data "We could not synthesize an equation from the first subterm in a ρ-term."
                                     :: ("the synthesized type for the first subterm" , to-string tp')
                                     :: [ expected-type tp ])) 

check-termi (Rho pi r t t') nothing = 
  check-term t nothing ≫=span λ mtp → 
  check-term t' nothing ≫=span cont mtp
  where cont : maybe type → maybe type → spanM (maybe type)
        cont (just (TpEq t1 t2)) (just tp) = 
          get-ctxt (λ Γ → 
            let s = rewrite-type Γ empty-renamectxt (is-rho-plus r) t1 t2 tp in
            let tp' = fst s in
              spanM-add (Rho-span pi t t' synthesizing r (snd s) [ type-data tp' ]) ≫span
              check-termi-return Γ (Rho pi r t t') tp')
        cont (just tp') m2 = spanM-add (Rho-span pi t t' synthesizing r 0
                                         (error-data "We could not synthesize an equation from the first subterm in a ρ-term."
                                      :: ("the synthesized type for the first subterm" , to-string tp')
                                      :: [])) ≫span spanMr nothing
        cont nothing _ = spanM-add (Rho-span pi t t' synthesizing r 0 []) ≫span spanMr nothing

check-termi (Chi pi (Atype tp) t) mtp = 
  check-type tp (just star) ≫span
  check-term t (just tp) ≫span cont mtp
  where cont : (m : maybe type) → spanM (check-ret m)
        cont nothing = spanM-add (Chi-span pi (Atype tp) t []) ≫span spanMr (just tp)
        cont (just tp') =
          get-ctxt (λ Γ → 
            if conv-type Γ tp tp' then (spanM-add (Chi-span pi (Atype tp) t [ expected-type tp' ]))
            else (spanM-add (Chi-span pi (Atype tp) t ( error-data "The expected type does not match the asserted type."
                                                     :: expected-type tp' :: [])))) ≫span
          spanMok
check-termi (Chi pi NoAtype t) (just tp) = 
  check-term t nothing ≫=span cont 
  where cont : (m : maybe type) → spanM ⊤
        cont nothing = spanM-add (Chi-span pi NoAtype t []) ≫span spanMok
        cont (just tp') =
          get-ctxt (λ Γ → 
            if conv-type Γ tp tp' then (spanM-add (Chi-span pi NoAtype t []))
            else (spanM-add (Chi-span pi NoAtype t ( error-data "The expected type does not match the synthesized type."
                                                                :: expected-type tp :: [ type-data tp' ])))) ≫span
            spanMok

check-termi (Theta pi u t ls) nothing =
  spanM-add (Theta-span pi u t ls [ error-data "Theta-terms can only be used in checking positions (and this is a synthesizing one)." ])
  ≫span spanMr nothing

check-termi (Theta pi AbstractEq t ls) (just tp) =
  -- discard spans from checking t, because we will check it again below
  check-term t nothing ≫=spand cont
  where cont : maybe type → spanM ⊤
        cont nothing = check-term t nothing ≫=span (λ m → 
                          spanM-add (Theta-span pi AbstractEq t ls 
                                      (expected-type tp :: [ motive-label , "We could not compute a motive from the given term" ])))
        cont (just htp) =
           get-ctxt (λ Γ → 
             let x = (fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt) in
             let motive = mtplam x (Tkt htp) (TpArrow (TpEq t (mvar x)) tp) in
               spanM-add (Theta-span pi AbstractEq t ls (expected-type tp :: [ the-motive motive ])) ≫span 
               check-term (App* (AppTp t (NoSpans motive (posinfo-plus (term-end-pos t) 1)))
                              (lterms-to-𝕃 AbstractEq ls))
                 (just tp))

check-termi (Theta pi Abstract t ls) (just tp) =
  -- discard spans from checking the head, because we will check it again below
  check-term t nothing ≫=spand cont t
  where cont : term → maybe type → spanM ⊤
        cont _ nothing = check-term t nothing ≫=span (λ m → 
                           spanM-add (Theta-span pi Abstract t ls 
                                      (expected-type tp :: [ motive-label , "We could not compute a motive from the given term" ])))
        cont t (just htp) = 
          let x = compute-var t in
          let motive = mtplam x (Tkt htp) tp in
            spanM-add (Theta-span pi Abstract t ls (expected-type tp :: [ the-motive motive ])) ≫span 
            check-term (App* (AppTp t (NoSpans motive (term-end-pos t)))
                            (lterms-to-𝕃 Abstract ls)) 
               (just tp)
          where compute-var : term → string
                compute-var (Var pi' x) = x
                compute-var t = ignored-var

check-termi (Theta pi (AbstractVars vs) t ls) (just tp) =
  get-ctxt (λ Γ → cont (wrap-vars Γ vs tp))
  where wrap-var : ctxt → var → type → maybe type
        wrap-var Γ v tp = ctxt-lookup-var-tk Γ v ≫=maybe (λ atk → just (mtplam v atk tp))
        wrap-vars : ctxt →  vars → type → maybe type 
        wrap-vars Γ (VarsStart v) tp = wrap-var Γ v tp
        wrap-vars Γ (VarsNext v vs) tp = wrap-vars Γ vs tp ≫=maybe (λ tp → wrap-var Γ v tp)
        cont : maybe type → spanM ⊤
        cont nothing = check-term t nothing ≫=span (λ m → 
                          spanM-add (Theta-span pi (AbstractVars vs) t ls 
                                      (expected-type tp :: [ error-data ("We could not compute a motive from the given term"
                                                                       ^ " because one of the abstracted vars is not in scope.") ])))
        cont (just motive) =
            spanM-add (Theta-span pi (AbstractVars vs) t ls (expected-type tp :: [ the-motive motive ])) ≫span 
            check-term (App* (AppTp t (NoSpans motive (posinfo-plus (term-end-pos t) 1)))
                            (lterms-to-𝕃 Abstract ls)) 
               (just tp)

check-termi (Hole pi) tp =
  get-ctxt (λ Γ → spanM-add (hole-span Γ pi tp []) ≫span return-when tp tp)

check-termi t tp = spanM-add (unimplemented-term-span (term-start-pos t) (term-end-pos t) tp) ≫span unimplemented-if tp

check-typei (TpParens pi t pi') k =
  spanM-add (punctuation-span "Parens (type)" pi pi') ≫span
  check-type t k
check-typei (NoSpans t _) k = check-type t k ≫=spand spanMr
check-typei (TpVar pi x) mk =
  get-ctxt (cont mk)
  where cont : (mk : maybe kind) → ctxt → spanM (check-ret mk) 
        cont mk Γ with ctxt-lookup-type-var Γ x
        cont mk Γ | nothing = 
          spanM-add (TpVar-span Γ pi x (maybe-to-checking mk)
                       (error-data "Missing a kind for a type variable." :: 
                        expected-kind-if mk (missing-kind :: []))) ≫span
          return-when mk mk
        cont nothing Γ | (just k) = 
          spanM-add (TpVar-span Γ pi x synthesizing ((kind-data k) :: [])) ≫span
          check-type-return Γ k
        cont (just k) Γ | just k' = 
         if conv-kind Γ k k' 
         then spanM-add (TpVar-span Γ pi x checking
                          (expected-kind k :: [ kind-data k' ]))
         else spanM-add (TpVar-span Γ pi x checking
                           (error-data "The computed kind does not match the expected kind." :: 
                            expected-kind k ::
                            [ kind-data k' ]))

check-typei (TpLambda pi pi' x atk' body) (just k) with to-absk k
check-typei (TpLambda pi pi' x atk body) (just k) | just (mk-absk pik pik' x' atk' _ k') =
  check-tk atk ≫span
  spanM-add (punctuation-span "Lambda (type)" pi (posinfo-plus pi 1)) ≫span
  get-ctxt (λ Γ → -- save ctxt
    spanM-add (if conv-tk Γ atk atk' then
                TpLambda-span pi x atk body checking [ kind-data k ]
               else
                 TpLambda-span pi x atk body checking (lambda-bound-var-conv-error x atk' atk [ kind-data k ])) ≫span
    add-tk pi' x atk ≫span 
    check-type body (just (rename-kind Γ x' x (tk-is-type atk') k')) ≫span
    set-ctxt Γ) -- restore ctxt
          
check-typei (TpLambda pi pi' x atk body) (just k) | nothing =
  check-tk atk ≫span
  spanM-add (punctuation-span "Lambda (type)" pi (posinfo-plus pi 1)) ≫span
  spanM-add (TpLambda-span pi x atk body checking
               (error-data "The type is being checked against a kind which is not an arrow- or Pi-kind." ::
                expected-kind k :: []))

check-typei (TpLambda pi pi' x atk body) nothing =
  spanM-add (punctuation-span "Lambda (type)" pi (posinfo-plus pi 1)) ≫span
  check-tk atk ≫span
  get-ctxt (λ Γ → 
    add-tk pi' x atk ≫span 
    check-type body nothing ≫=span
    cont ≫=span (λ mk →
    set-ctxt Γ ≫span
    spanMr mk))

  where cont : maybe kind → spanM (maybe kind)
        cont nothing = 
          spanM-add (TpLambda-span pi x atk body synthesizing []) ≫span
          spanMr nothing
        cont (just k) = 
          let r = absk-tk x atk k in
            spanM-add (TpLambda-span pi x atk body synthesizing [ kind-data r ]) ≫span
            
            spanMr (just r)

check-typei (Abs pi b {- All or Pi -} pi' x atk body) k = 
  spanM-add (TpQuant-span (binder-is-pi b) pi x atk body (maybe-to-checking k)
               (if-check-against-star-data "A type-level quantification" k)) ≫span
  spanM-add (punctuation-span "Forall" pi (posinfo-plus pi 1)) ≫span
  check-tk atk ≫span
  get-ctxt (λ Γ → 
    add-tk pi' x atk ≫span
    check-type body (just star) ≫span
    set-ctxt Γ ≫span
    return-star-when k)
  where helper : maybe kind → 𝕃 tagged-val
        helper nothing = [ kind-data star ]
        helper (just (Star _)) = [ kind-data star ]
        helper (just k) = error-data "A type-level quantification is being checked against a kind other than ★" ::
                          expected-kind k :: []

check-typei (TpArrow t1 t2) k = 
  spanM-add (TpArrow-span t1 t2 (maybe-to-checking k) (if-check-against-star-data "An arrow type" k)) ≫span
  check-type t1 (just star) ≫span
  check-type t2 (just star) ≫span
    return-star-when k

check-typei (TpAppt tp t) k =
  check-type tp nothing ≫=spanm cont ≫=spanr cont' k
  where cont : kind → spanM (maybe kind)
        cont (KndTpArrow tp' k') = 
          check-term t (just tp') ≫span 
          spanMr (just k')
        cont (KndPi _ _ x (Tkt tp') k') = 
          check-term t (just tp') ≫span 
          get-ctxt (λ Γ → 
            spanMr (just (subst-kind Γ t x k')))
        cont k' = spanM-add (TpAppt-span tp t (maybe-to-checking k)
                               (error-data ("The kind computed for the head of the type application does"
                                        ^ " not allow the head to be applied to an argument which is a term")
                            :: type-app-head tp
                            :: head-kind k' 
                            :: term-argument t
                            :: [])) ≫span
                  spanMr nothing
        cont' : (outer : maybe kind) → kind → spanM (check-ret outer)
        cont' nothing k = 
          spanM-add (TpAppt-span tp t synthesizing ((kind-data k) :: [])) ≫span
          get-ctxt (λ Γ → 
            check-type-return Γ k)
        cont' (just k') k = 
          get-ctxt (λ Γ → 
            if conv-kind Γ k k' then spanM-add (TpAppt-span tp t checking (expected-kind k' :: [ kind-data k ]))
            else spanM-add (TpAppt-span tp t checking 
                           (error-data "The kind computed for a type application does not match the expected kind." ::
                            expected-kind k' ::
                            kind-data k ::
                            [])))

check-typei (TpApp tp tp') k =
  check-type tp nothing ≫=spanm cont ≫=spanr cont' k
  where cont : kind → spanM (maybe kind)
        cont (KndArrow k'' k') = 
          check-type tp' (just k'') ≫span 
          spanMr (just k')
        cont (KndPi _ _ x (Tkk k'') k') = 
          check-type tp' (just k'') ≫span 
          get-ctxt (λ Γ → 
            spanMr (just (subst-kind Γ tp' x k')))
        cont k' = spanM-add (TpApp-span tp tp' (maybe-to-checking k)
                               (error-data ("The kind computed for the head of the type application does"
                                        ^ " not allow the head to be applied to an argument which is a type")
                            :: type-app-head tp
                            :: head-kind k' 
                            :: type-argument tp'
                            :: [])) ≫span
                  spanMr nothing
        cont' : (outer : maybe kind) → kind → spanM (check-ret outer)
        cont' nothing k = 
          spanM-add (TpApp-span tp tp' synthesizing ((kind-data k) :: [])) ≫span
          get-ctxt (λ Γ → 
            check-type-return Γ k)
        cont' (just k') k = 
          get-ctxt (λ Γ → 
            if conv-kind Γ k k' then spanM-add (TpApp-span tp tp' checking (expected-kind k' :: [ kind-data k' ]))
            else spanM-add (TpApp-span tp tp' checking 
                           (error-data "The kind computed for a type application does not match the expected kind." ::
                            expected-kind k' ::
                            kind-data k ::
                            [])))

check-typei (TpEq t1 t2) k = 
  get-ctxt (λ Γ → 
    var-spans-term Γ t1 ≫span
    var-spans-term Γ t2) ≫span
    spanM-add (TpEq-span t1 t2 (maybe-to-checking k) (if-check-against-star-data "An equation" k)) ≫span
    return-star-when k
  
check-typei (Lft pi pi' X t l) k = 
  get-ctxt (λ Γ → 
    add-tk pi' X (Tkk star) ≫span
    check-term t (just (liftingType-to-type X l)) ≫span
    spanM-add (punctuation-span "Lift" pi (posinfo-plus pi 1)) ≫span
    set-ctxt Γ ≫span
    cont k (liftingType-to-kind l))
  where cont : (outer : maybe kind) → kind → spanM (check-ret outer)
        cont nothing k = spanM-add (Lft-span pi X t synthesizing [ kind-data k ]) ≫span spanMr (just k)
        cont (just k') k = 
          get-ctxt (λ Γ → 
            if conv-kind Γ k k' then 
              spanM-add (Lft-span pi X t checking ( expected-kind k' :: [ kind-data k ])) ≫span spanMok
            else
              spanM-add (Lft-span pi X t checking ( error-data "The expected kind does not match the computed kind."
                                                 :: expected-kind k' :: [ kind-data k ])))
check-typei t k = spanM-add (unimplemented-type-span (type-start-pos t) (type-end-pos t) k) ≫span unimplemented-if k

check-kind (KndParens pi k pi') =
  spanM-add (punctuation-span "Parens (kind)" pi pi') ≫span
  check-kind k
check-kind (Star pi) = spanM-add (Star-span pi checking)
check-kind (KndVar pi x) = get-ctxt (λ Γ → spanM-add (KndVar-span Γ pi x checking))
check-kind (KndArrow k k') = 
  spanM-add (KndArrow-span k k' checking) ≫span
  check-kind k ≫span
  check-kind k'
check-kind (KndTpArrow t k) = 
  spanM-add (KndTpArrow-span t k checking) ≫span
  check-type t (just star) ≫span
  check-kind k
check-kind (KndPi pi pi' x atk k) = 
  spanM-add (punctuation-span "Pi (kind)" pi (posinfo-plus pi 1)) ≫span
  spanM-add (KndPi-span pi x atk k checking) ≫span
  check-tk atk ≫span
  get-ctxt (λ Γ → 
    add-tk pi' x atk ≫span 
    check-kind k ≫span
    set-ctxt Γ)

check-tk (Tkk k) = check-kind k
check-tk (Tkt t) = check-type t (just star)



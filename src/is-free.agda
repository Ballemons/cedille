module is-free where

open import lib

open import cedille-types
open import ctxt
open import syntax-util

is-free-e = 𝔹
check-erased = tt
skip-erased = ff

is-free-in-t : Set → Set
is-free-in-t T = is-free-e → var ⊎ (ctxt × stringset) → T → 𝔹

{- if the second argument is in₁ x, we are looking for a free occurrence of x.
   If it is in₂ t, then t is a stringset recording which variables are bound. -}
is-free-in-term : is-free-in-t term
is-free-in-type : is-free-in-t type
is-free-in-kind : is-free-in-t kind
is-free-in-optClass : is-free-in-t optClass
is-free-in-optType : is-free-in-t optType
is-free-in-optTerm : is-free-in-t optTerm
is-free-in-tk : is-free-in-t tk 
is-free-in-liftingType : is-free-in-t liftingType
is-free-in-maybeAtype : is-free-in-t maybeAtype
is-free-in-args : is-free-in-t args

is-free-in-term ce x (App t Erased t') = is-free-in-term ce x t || (ce && is-free-in-term ce x t')
is-free-in-term ce x (App t NotErased t') = is-free-in-term ce x t || is-free-in-term ce x t'
is-free-in-term ce x (Unfold pi t) = is-free-in-term ce x t
is-free-in-term ce x (AppTp t tp) = is-free-in-term ce x t || (ce && is-free-in-type ce x tp)
is-free-in-term ce x (Hole x₁) = ff
is-free-in-term ce (inj₁ x) (Lam _ b _ x' oc t) =
  (ce && is-free-in-optClass ce (inj₁ x) oc) || (~ (x =string x') && is-free-in-term ce (inj₁ x) t)
is-free-in-term ce (inj₂ (Γ , t)) (Lam _ b _ x' oc t') =
  (ce && is-free-in-optClass ce (inj₂ (Γ , t)) oc) || is-free-in-term ce (inj₂ (Γ , stringset-insert t x')) t'
is-free-in-term ce x (Parens x₁ t x₂) = is-free-in-term ce x t
is-free-in-term ce (inj₁ x) (Var _ x') = x =string x'
is-free-in-term ce (inj₂ (Γ , t)) (Var _ x') = ~ (stringset-contains t x') && ~ (ctxt-declares-term-var Γ x')
is-free-in-term ce x (Beta _ ot) = is-free-in-optTerm ce x ot
is-free-in-term ce x (Delta _ t) = ce && is-free-in-term ce x t
is-free-in-term ce x (Omega _ t) = is-free-in-term ce x t
is-free-in-term ce x (InlineDef _ _ x' t _) = is-free-in-term ce x t
is-free-in-term ce x (IotaPair _ t1 t2 ot _) = is-free-in-term ce x t1 || (ce && is-free-in-term ce x t2) || (ce && is-free-in-optTerm ce x ot)
is-free-in-term ce x (IotaProj t n _) = is-free-in-term ce x t
is-free-in-term ce x (PiInj _ _ t) = is-free-in-term ce x t
is-free-in-term ce x (Epsilon _ _ _ t) = is-free-in-term ce x t
is-free-in-term ce x (Sigma _ t) = is-free-in-term ce x t
is-free-in-term ce x (Rho _ _ t t') = (ce && is-free-in-term ce x t) || is-free-in-term ce x t'
is-free-in-term ce x (Chi _ T t') = (ce && is-free-in-maybeAtype ce x T) || is-free-in-term ce x t'
is-free-in-term ce x (Theta _ _ t ls) = is-free-in-term ce x t || is-free-in-lterms ce x ls
  where is-free-in-lterms : is-free-e → var ⊎ (ctxt × stringset) → lterms → 𝔹
        is-free-in-lterms ce x (LtermsNil _) = ff
        is-free-in-lterms ce x (LtermsCons Erased t ls) = (ce && is-free-in-term ce x t) || is-free-in-lterms ce x ls
        is-free-in-lterms ce x (LtermsCons NotErased t ls) = is-free-in-term ce x t || is-free-in-lterms ce x ls

is-free-in-type ce (inj₁ x) (Abs _ _ _ x' atk t) = is-free-in-tk ce (inj₁ x) atk || (~ (x =string x') && is-free-in-type ce (inj₁ x) t)
is-free-in-type ce (inj₂ (Γ , t)) (Abs _ _ _ x' atk t') =
  is-free-in-tk ce (inj₂ (Γ , t)) atk || is-free-in-type ce (inj₂ (Γ , stringset-insert t x')) t'
is-free-in-type ce (inj₁ x) (Mu _ _ x' k t) = is-free-in-kind ce (inj₁ x) k || (~(x =string x') && (is-free-in-type ce (inj₁ x) t))
is-free-in-type ce (inj₂ (Γ , t)) (Mu _ _ x' k t') =
  is-free-in-kind ce (inj₂ (Γ , t)) k || is-free-in-type ce (inj₂ (Γ , stringset-insert t x')) t'
is-free-in-type ce (inj₁ x) (TpLambda _ _ x' atk t) = 
  is-free-in-tk ce (inj₁ x) atk || (~ (x =string x') && is-free-in-type ce (inj₁ x) t) 
is-free-in-type ce (inj₂ t) (TpLambda _ _ x' atk t') = 
  is-free-in-tk ce (inj₂ t) atk || (is-free-in-type ce (inj₂ t) t') 
is-free-in-type ce (inj₁ x) (IotaEx _ _ _ x' m t) = is-free-in-optType ce (inj₁ x) m || (~ (x =string x') && is-free-in-type ce (inj₁ x) t)
is-free-in-type ce (inj₂ (Γ , t)) (IotaEx _ _ _ x' m t') =
  is-free-in-optType ce (inj₂ (Γ , t)) m || (is-free-in-type ce (inj₂ (Γ , stringset-insert t x')) t')
is-free-in-type ce (inj₁ x) (Lft _ _ X t l) = is-free-in-liftingType ce (inj₁ x) l || (~ x =string X && is-free-in-term ce (inj₁ x) t)
is-free-in-type ce (inj₂ (Γ , t)) (Lft _ _ X t' l) =
  is-free-in-liftingType ce (inj₂ (Γ , t)) l || (is-free-in-term ce (inj₂ (Γ , stringset-insert t X)) t')
is-free-in-type ce x (TpApp t t') = is-free-in-type ce x t || is-free-in-type ce x t'
is-free-in-type ce x (TpAppt t t') = is-free-in-type ce x t || is-free-in-term ce x t'
is-free-in-type ce x (TpArrow t _ t') = is-free-in-type ce x t || is-free-in-type ce x t'
is-free-in-type ce x (TpEq t t') = is-free-in-term ce x t || is-free-in-term ce x t'
is-free-in-type ce x (TpParens x₁ t x₂) = is-free-in-type ce x t
is-free-in-type ce (inj₁ x) (TpVar _ x') = x =string x'
is-free-in-type ce (inj₂ (Γ , t)) (TpVar _ x') = ~ (stringset-contains t x') && ~ (ctxt-declares-type-var Γ x')
is-free-in-type ce x (NoSpans t _) = is-free-in-type ce x t

--ACG
is-free-in-type ce (inj₁ x) (TpHole _) = ff
is-free-in-type ce (inj₂ (Γ , t)) (TpHole _) = ff

is-free-in-kind ce x (KndArrow k k') = is-free-in-kind ce x k || is-free-in-kind ce x k'
is-free-in-kind ce x (KndParens x₁ k x₂) = is-free-in-kind ce x k
is-free-in-kind ce (inj₁ x) (KndPi _ _ x' atk k) = is-free-in-tk ce (inj₁ x) atk || (~ (x =string x') && is-free-in-kind ce (inj₁ x) k)
is-free-in-kind ce (inj₂ (Γ , t)) (KndPi _ _ x' atk k) =
  is-free-in-tk ce (inj₂ (Γ , t)) atk || (is-free-in-kind ce (inj₂ (Γ , stringset-insert t x')) k)
is-free-in-kind ce x (KndTpArrow t k) = is-free-in-type ce x t || is-free-in-kind ce x k
is-free-in-kind ce (inj₁ x) (KndVar _ x' ys) = x =string x' || is-free-in-args ce (inj₁ x) ys
is-free-in-kind ce (inj₂ (Γ , t)) (KndVar _ x' ys) = is-free-in-args ce (inj₂ (Γ , t)) ys
is-free-in-kind ce x (Star x₁) = ff

is-free-in-args ce x (ArgsCons (TermArg y) ys) = is-free-in-term ce x y || is-free-in-args ce x ys
is-free-in-args ce x (ArgsCons (TypeArg y) ys) = is-free-in-type ce x y || is-free-in-args ce x ys
is-free-in-args ce x (ArgsNil x₁) = ff

is-free-in-optClass ce x NoClass = ff
is-free-in-optClass ce x (SomeClass atk) = is-free-in-tk ce x atk

is-free-in-optType ce x NoType = ff
is-free-in-optType ce x (SomeType t) = is-free-in-type ce x t

is-free-in-optTerm ce x NoTerm = ff
is-free-in-optTerm ce x (SomeTerm t _) = is-free-in-term ce x t

is-free-in-tk ce x (Tkt t) = is-free-in-type ce x t
is-free-in-tk ce x (Tkk k) = is-free-in-kind ce x k

is-free-in-liftingType ce x (LiftArrow l l') = is-free-in-liftingType ce x l || is-free-in-liftingType ce x l'
is-free-in-liftingType ce x (LiftParens x₁ l x₂) = is-free-in-liftingType ce x l
is-free-in-liftingType ce (inj₁ x) (LiftPi _ x' t l) =
  is-free-in-type ce (inj₁ x) t || (~ (x =string x') && is-free-in-liftingType ce (inj₁ x) l)
is-free-in-liftingType ce (inj₂ (Γ , t)) (LiftPi _ x' t' l) =
  is-free-in-type ce (inj₂ (Γ , t)) t' || (is-free-in-liftingType ce (inj₂ (Γ , stringset-insert t x')) l)
is-free-in-liftingType ce x (LiftStar x₁) = ff
is-free-in-liftingType ce x (LiftTpArrow t l) = is-free-in-type ce x t || is-free-in-liftingType ce x l

is-free-in-maybeAtype ce x NoAtype = ff
is-free-in-maybeAtype ce x (Atype T) = is-free-in-type ce x T

is-free-in : {ed : exprd} → is-free-e → var → ⟦ ed ⟧ → 𝔹
is-free-in{TERM} e x t = is-free-in-term e (inj₁ x) t 
is-free-in{TYPE} e x t = is-free-in-type e (inj₁ x) t 
is-free-in{KIND} e x t = is-free-in-kind e (inj₁ x) t 
is-free-in{LIFTINGTYPE} e x t = is-free-in-liftingType e (inj₁ x) t 

is-open : {ed : exprd} → ctxt → is-free-e → ⟦ ed ⟧ → 𝔹
is-open{TERM} Γ e t = is-free-in-term e (inj₂ (Γ , empty-stringset)) t 
is-open{TYPE} Γ e t = is-free-in-type e (inj₂ (Γ , empty-stringset)) t 
is-open{KIND} Γ e t = is-free-in-kind e (inj₂ (Γ , empty-stringset)) t 
is-open{LIFTINGTYPE} Γ e t = is-free-in-liftingType e (inj₂ (Γ , empty-stringset)) t 


abs-tk : lam → var → tk → type → type
abs-tk l x (Tkk k) tp = Abs posinfo-gen All posinfo-gen x (Tkk k) tp
abs-tk ErasedLambda x (Tkt tp') tp = Abs posinfo-gen All posinfo-gen x (Tkt tp') tp
abs-tk KeptLambda x (Tkt tp') tp with is-free-in check-erased x tp 
abs-tk KeptLambda x (Tkt tp') tp | tt = Abs posinfo-gen Pi posinfo-gen x (Tkt tp') tp
abs-tk KeptLambda x (Tkt tp') tp | ff = TpArrow tp' UnerasedArrow  tp

absk-tk : var → tk → kind → kind
absk-tk x atk k with is-free-in check-erased x k
absk-tk x atk k | tt = KndPi posinfo-gen posinfo-gen x atk k
absk-tk x (Tkt tp) k | ff = KndTpArrow tp k
absk-tk x (Tkk k') k | ff = KndArrow k' k

data abs  : Set where
  mk-abs : posinfo → binder → posinfo → var → tk → (var-free-in-body : 𝔹) → type → abs 

to-abs : type → maybe abs
to-abs (Abs pi b pi' x atk tp) = just (mk-abs pi b pi' x atk (is-free-in check-erased x tp) tp)
to-abs (TpArrow tp1 ErasedArrow tp2) = just (mk-abs posinfo-gen All posinfo-gen dummy-var (Tkt tp1) ff tp2)
to-abs (TpArrow tp1 UnerasedArrow tp2) = just (mk-abs posinfo-gen Pi posinfo-gen dummy-var (Tkt tp1) ff tp2)
to-abs _ = nothing

data absk  : Set where
  mk-absk : posinfo → posinfo → var → tk → (var-free-in-body : 𝔹) → kind → absk 

to-absk : kind → maybe absk
to-absk (KndPi pi pi' x atk k) = just (mk-absk pi pi' x atk (is-free-in check-erased x k) k)
to-absk (KndArrow k1 k2) = just (mk-absk posinfo-gen posinfo-gen dummy-var (Tkk k1) ff k2)
to-absk (KndTpArrow tp k) = just (mk-absk posinfo-gen posinfo-gen dummy-var (Tkt tp) ff k)
to-absk _ = nothing


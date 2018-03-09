import cedille-options

module to-string (options : cedille-options.options) where

open import lib
open import cedille-types
open import syntax-util
open import ctxt
open import rename
open import general-util


data expr-side : Set where
  left : expr-side
  right : expr-side
  neither : expr-side

not-left : expr-side → 𝔹
not-left left = ff
not-left _ = tt
not-right : expr-side → 𝔹
not-right right = ff
not-right _ = tt

is-untyped : {ed : exprd} → ⟦ ed ⟧ → expr-side → 𝔹
is-untyped{TERM} (Beta _ _) _ = tt
is-untyped{TERM} (Phi _ _ _ _ _) right = tt
is-untyped{TYPE} (TpEq _ _) _ = tt
is-untyped _ _ = ff

no-parens : {ed : exprd} → {ed' : exprd} → ⟦ ed ⟧ → ⟦ ed' ⟧ → expr-side → 𝔹
no-parens {_} {TERM} _ (IotaPair pi t t' pi') lr = tt
no-parens {_} {TERM} _ (Parens pi t pi') lr = tt
no-parens {_} {TYPE} _ (TpParens pi T pi') lr = tt
no-parens {_} {KIND} _ (KndParens pi k pi') lr = tt
no-parens {_} {LIFTINGTYPE} _ (LiftParens pi lT pi') lr = tt
no-parens {_} {TYPE} _ (TpEq t t') lr = tt
no-parens {_} {TERM} _ (Beta pi ot) lr = tt
no-parens {_} {TERM} _ (Phi pi eq t t' pi') right = tt
no-parens{TERM} (App t me t') p lr = is-untyped p lr || is-abs p || (is-arrow p || is-app p) && not-right lr
no-parens{TERM} (AppTp t T) p lr = is-untyped p lr || is-abs p || (is-arrow p || is-app p) && not-right lr
no-parens{TERM} (Beta pi ot) p lr = tt
no-parens{TERM} (Chi pi mT t) p lr = is-eq-op p
no-parens{TERM} (Epsilon pi lr' m t) p lr = is-eq-op p
no-parens{TERM} (Hole pi) p lr = tt
no-parens{TERM} (IotaPair pi t t' pi') p lr = tt
no-parens{TERM} (IotaProj t n pi) p lr = tt
no-parens{TERM} (Lam pi l' pi' x oc t) p lr = is-untyped p lr || is-abs p
no-parens{TERM} (Let pi dtT t) p lr = tt
no-parens{TERM} (Parens pi t pi') p lr = tt
no-parens{TERM} (Phi pi eq t t' pi') p lr = is-eq-op p
no-parens{TERM} (Rho pi r eq t) p lr = is-eq-op p
no-parens{TERM} (Sigma pi t) p lr = is-eq-op p
no-parens{TERM} (Theta pi theta t lts) p lr = ff
no-parens{TERM} (Var pi x) p lr = tt
no-parens{TYPE} (Abs pi b pi' x Tk T) p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{TYPE} (Iota pi pi' x oT T) p lr = is-abs p
no-parens{TYPE} (Lft pi pi' x t lT) p lr = ff
no-parens{TYPE} (NoSpans T pi) p lr = tt
no-parens{TYPE} (TpApp T T') p lr = is-abs p || is-arrow p || is-app p && not-right lr
no-parens{TYPE} (TpAppt T t) p lr = is-abs p || is-arrow p || is-app p && not-right lr
no-parens{TYPE} (TpArrow T a T') p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{TYPE} (TpEq t t') p lr = tt
no-parens{TYPE} (TpHole pi) p lr = tt
no-parens{TYPE} (TpLambda pi pi' x Tk T) p lr = is-abs p
no-parens{TYPE} (TpParens pi T pi') p lr = tt
no-parens{TYPE} (TpVar pi x) p lr = tt
no-parens{KIND} (KndArrow k k') p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{KIND} (KndParens pi k pi') p lr = tt
no-parens{KIND} (KndPi pi pi' x Tk k) p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{KIND} (KndTpArrow T k) p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{KIND} (KndVar pi x as) p lr = tt
no-parens{KIND} (Star pi) p lr = tt
no-parens{LIFTINGTYPE} (LiftArrow lT lT') p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{LIFTINGTYPE} (LiftParens pi lT pi') p lr = tt
no-parens{LIFTINGTYPE} (LiftPi pi x T lT) p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{LIFTINGTYPE} (LiftStar pi) p lr = tt
no-parens{LIFTINGTYPE} (LiftTpArrow T lT) p lr = (is-abs p || is-arrow p) && not-left lr
no-parens{QUALIF} _ _ _ = tt
no-parens{ARG} _ _ _ = tt


-------------------------------
strM : Set
strM = {ed : exprd} → rope → ℕ → 𝕃 tag → ctxt → maybe ⟦ ed ⟧ → expr-side →
  rope × ℕ × 𝕃 tag

to-stringh : {ed : exprd} → ⟦ ed ⟧ → strM

strM-Γ : (ctxt → strM) → strM
strM-Γ f s n ts Γ = f Γ s n ts Γ
strM-n : (ℕ → strM) → strM
strM-n f s n = f n s n
strM-p : ({ed : exprd} → maybe ⟦ ed ⟧ → strM) → strM
strM-p f s n ts Γ pe = f pe s n ts Γ pe

infixr 4 _≫str_

_≫str_ : strM → strM → strM
(m ≫str m') s n ts Γ pe lr with m s n ts Γ pe lr
(m ≫str m') s n ts Γ pe lr | s' , n' , ts' = m' s' n' ts' Γ pe lr

strΓ : var → posinfo → strM → strM
strΓ v pi m s n ts Γ@(mk-ctxt (fn , mn , ps , q) syms i symb-occs) pe =
  m s n ts
    (mk-ctxt (fn , mn , ps , (trie-insert q v (v' , ArgsNil pi))) syms (trie-insert i v' (var-decl , ("missing" , "missing"))) symb-occs)
    pe
  where v' = pi % v

strAdd : string → strM
strAdd s s' n ts Γ pe lr = s' ⊹⊹ [[ s ]] , n + (string-length s) , ts

var-loc-tag : ctxt → qvar → ℕ → ℕ → 𝕃 tag
var-loc-tag Γ v start end with ctxt-var-location Γ (qualif-var Γ v)
...| "missing" , "missing" = []
...| fn , pos = [ make-tag "loc" (("fn" , [[ fn ]]) :: [ "pos" , [[ pos ]] ]) start end ]

var-shadowed-tag : ctxt → qvar → var → ℕ → ℕ → 𝕃 tag
var-shadowed-tag Γ v uqv start end = if (qualif-var Γ v) =string (qualif-var Γ uqv)
  then [] else [ make-tag "shadowed" [] start end ]

strVar : var → strM
strVar v s n ts Γ pe lr =
  let uqv = unqual-local (unqual-all (ctxt-get-qualif Γ) v) in
  let uqv' = if cedille-options.options.show-qualified-vars options then v else uqv in
  let n' = n + (string-length uqv') in
  s ⊹⊹ [[ uqv' ]] , n' , var-loc-tag Γ v n n' ++ var-shadowed-tag Γ v uqv n n' ++ ts

strEmpty : strM
strEmpty s n ts Γ pe lr = s , n , ts

{-# TERMINATING #-}
term-to-stringh : term → strM
type-to-stringh : type → strM
kind-to-stringh : kind → strM
liftingType-to-stringh : liftingType → strM
tk-to-stringh : tk → strM

optTerm-to-string : optTerm → strM
optType-to-string : optType → strM
optClass-to-string : optClass → strM
maybeAtype-to-string : maybeAtype → strM
maybeCheckType-to-string : maybeCheckType → strM
lterms-to-string : lterms → strM
arg-to-string : arg → strM
args-to-string : args → strM
binder-to-string : binder → string
maybeErased-to-string : maybeErased → string
lam-to-string : lam → string
leftRight-to-string : leftRight → string
vars-to-string : vars → strM
theta-to-string : theta → strM
rho-to-string : rho → string
arrowtype-to-string : arrowtype → string
maybeMinus-to-string : maybeMinus → string

to-string-ed : {ed : exprd} → ⟦ ed ⟧ → strM
to-string-ed{TERM} = term-to-stringh
to-string-ed{TYPE} = type-to-stringh
to-string-ed{KIND} = kind-to-stringh
to-string-ed{LIFTINGTYPE} = liftingType-to-stringh
to-string-ed{ARG} = arg-to-string
to-string-ed{QUALIF} q = strEmpty

to-stringh' : {ed : exprd} → expr-side → ⟦ ed ⟧ → strM
to-stringh' lr t s n ts Γ nothing lr' = to-string-ed t s n ts Γ (just t) lr
to-stringh' lr t s n ts Γ (just pe) lr' = (if no-parens t pe lr
  then to-string-ed t
  else (strAdd "(" ≫str to-string-ed t ≫str strAdd ")")) s n ts Γ (just t) lr

to-stringl : {ed : exprd} → ⟦ ed ⟧ → strM
to-stringr : {ed : exprd} → ⟦ ed ⟧ → strM
to-stringl = to-stringh' left
to-stringr = to-stringh' right
to-stringh = to-stringh' neither

tk-to-stringh (Tkt T) = to-stringh T
tk-to-stringh (Tkk k) = to-stringh k

term-to-stringh (App t me t') = to-stringl t ≫str strAdd (" " ^ maybeErased-to-string me) ≫str to-stringr t'
term-to-stringh (AppTp t T) = to-stringl t ≫str strAdd " · " ≫str to-stringr T
term-to-stringh (Beta pi ot) = strAdd "β" ≫str optTerm-to-string ot
term-to-stringh (Chi pi mT t) = strAdd "χ " ≫str maybeAtype-to-string mT ≫str to-stringh t
term-to-stringh (Epsilon pi lr m t) = strAdd "ε" ≫str strAdd (leftRight-to-string lr) ≫str strAdd (maybeMinus-to-string m) ≫str to-stringh t
term-to-stringh (Hole pi) = strAdd "●"
term-to-stringh (IotaPair pi t t' pi') = strAdd "[ " ≫str to-stringh t ≫str strAdd " , " ≫str to-stringh t' ≫str strAdd " ]"
term-to-stringh (IotaProj t n pi) = to-stringh t ≫str strAdd ("." ^ n)
term-to-stringh (Lam pi l pi' x oc t) = strAdd (lam-to-string l ^ " " ^ x) ≫str optClass-to-string oc ≫str strAdd " . " ≫str strΓ x pi' (to-stringh t)
term-to-stringh (Let pi dtT t) with dtT
...| DefTerm pi' x m t' = strAdd ("[ " ^ x) ≫str maybeCheckType-to-string m ≫str strAdd " = " ≫str to-stringh t' ≫str strAdd " ] - " ≫str strΓ x pi' (to-stringh t)
...| DefType pi' x k t' = strAdd ("[ " ^ x) ≫str to-stringh k ≫str strAdd " = " ≫str to-stringh t' ≫str strAdd " ] - " ≫str strΓ x pi' (to-stringh t)
term-to-stringh (Parens pi t pi') = strAdd "(" ≫str to-string-ed t ≫str strAdd ")"
term-to-stringh (Phi pi eq t t' pi') = strAdd "φ " ≫str to-stringh eq ≫str strAdd " - (" ≫str to-stringh t ≫str strAdd ") {" ≫str to-stringr t' ≫str strAdd "}"
term-to-stringh (Rho pi r eq t) = strAdd (rho-to-string r) ≫str to-stringh eq ≫str strAdd " - " ≫str to-stringh t
term-to-stringh (Sigma pi t) = strAdd "ς " ≫str to-stringh t
term-to-stringh (Theta pi theta t lts) = theta-to-string theta ≫str to-stringh t ≫str lterms-to-string lts
term-to-stringh (Var pi x) = strVar x

type-to-stringh (Abs pi b pi' x Tk T) = strAdd (binder-to-string b ^ " " ^ x ^ " : ") ≫str tk-to-stringh Tk ≫str strAdd " . " ≫str strΓ x pi' (to-stringh T)
type-to-stringh (Iota pi pi' x oT T) = strAdd ("ι " ^ x) ≫str optType-to-string oT ≫str strAdd " . " ≫str strΓ x pi' (to-stringh T)
type-to-stringh (Lft pi pi' x t lT) = strAdd ("↑ " ^ x ^ " . ") ≫str strΓ x pi' (to-stringh t ≫str strAdd " : " ≫str to-stringh lT)
type-to-stringh (NoSpans T pi) = to-string-ed T
type-to-stringh (TpApp T T') = to-stringl T ≫str strAdd " · " ≫str to-stringr T'
type-to-stringh (TpAppt T t) = to-stringl T ≫str strAdd " " ≫str to-stringr t
type-to-stringh (TpArrow T a T') = to-stringl T ≫str strAdd (arrowtype-to-string a) ≫str to-stringr T'
type-to-stringh (TpEq t t') = strAdd "{ " ≫str to-stringh t ≫str strAdd " ≃ " ≫str to-stringh t' ≫str strAdd " }"
type-to-stringh (TpHole pi) = strAdd "●"
type-to-stringh (TpLambda pi pi' x Tk T) = strAdd ("λ " ^ x ^ " : ") ≫str tk-to-stringh Tk ≫str strAdd " . " ≫str strΓ x pi' (to-stringh T)
type-to-stringh (TpParens pi T pi') = strAdd "(" ≫str to-string-ed T ≫str strAdd ")"
type-to-stringh (TpVar pi x) = strVar x

kind-to-stringh (KndArrow k k') = to-stringl k ≫str strAdd " ➔ " ≫str to-stringr k'
kind-to-stringh (KndParens pi k pi') = strAdd "(" ≫str to-string-ed k ≫str strAdd ")"
kind-to-stringh (KndPi pi pi' x Tk k) = strAdd ("Π " ^ x ^ " : ") ≫str tk-to-stringh Tk ≫str strAdd " . " ≫str strΓ x pi' (to-stringh k)
kind-to-stringh (KndTpArrow T k) = to-stringl T ≫str strAdd " ➔ " ≫str to-stringr k
kind-to-stringh (KndVar pi x as) = strVar x ≫str args-to-string as
kind-to-stringh (Star pi) = strAdd "★"

liftingType-to-stringh (LiftArrow lT lT') = to-stringl lT ≫str strAdd " ➔↑ " ≫str to-stringr lT'
liftingType-to-stringh (LiftParens pi lT pi') = strAdd "(" ≫str to-string-ed lT ≫str strAdd ")"
liftingType-to-stringh (LiftPi pi x T lT) = strAdd ("Π↑ " ^ x ^ " : ") ≫str to-stringh T ≫str strAdd " . " ≫str strΓ x pi (to-stringh lT)
liftingType-to-stringh (LiftStar pi) = strAdd "☆"
liftingType-to-stringh (LiftTpArrow T lT) = to-stringl T ≫str strAdd " ➔↑ " ≫str to-stringr lT
optTerm-to-string NoTerm = strEmpty
optTerm-to-string (SomeTerm t _) = strAdd " { " ≫str to-stringh t ≫str strAdd " }"
optType-to-string NoType = strEmpty
optType-to-string (SomeType T) = strAdd " : " ≫str to-stringh T
optClass-to-string NoClass = strEmpty
optClass-to-string (SomeClass Tk) = strAdd " : " ≫str tk-to-stringh Tk
maybeAtype-to-string NoAtype = strEmpty
maybeAtype-to-string (Atype T) = to-stringh T
maybeCheckType-to-string NoCheckType = strEmpty
maybeCheckType-to-string (Type T) = strAdd " ◂ " ≫str to-stringh T
lterms-to-string (LtermsCons m t ts) = strAdd (" " ^ maybeErased-to-string m) ≫str to-stringh t ≫str lterms-to-string ts
lterms-to-string (LtermsNil _) = strEmpty
arg-to-string (TermArg t) = to-stringh t
arg-to-string (TypeArg T) = strAdd "· " ≫str to-stringh T
args-to-string (ArgsCons t ts) = strAdd " " ≫str arg-to-string t ≫str args-to-string ts
args-to-string (ArgsNil _) = strEmpty
binder-to-string All = "∀"
binder-to-string Pi = "Π"
maybeErased-to-string Erased = "-"
maybeErased-to-string NotErased = ""
lam-to-string ErasedLambda = "Λ"
lam-to-string KeptLambda = "λ"
leftRight-to-string Left = "l"
leftRight-to-string Right = "r"
leftRight-to-string Both = ""
vars-to-string (VarsStart v) = strVar v
vars-to-string (VarsNext v vs) = strVar v ≫str strAdd " " ≫str vars-to-string vs
theta-to-string Abstract = strAdd "θ "
theta-to-string AbstractEq = strAdd "θ+ "
theta-to-string (AbstractVars vs) = strAdd "θ<" ≫str vars-to-string vs ≫str strAdd "> "
rho-to-string RhoPlain = "ρ "
rho-to-string RhoPlus = "ρ+ "
arrowtype-to-string UnerasedArrow = " ➔ "
arrowtype-to-string ErasedArrow = " ➾ "
maybeMinus-to-string EpsHnf = ""
maybeMinus-to-string EpsHanf = "-"


strRun : ctxt → strM → rope
strRun Γ m = fst (m {TERM} [[]] 0 [] Γ nothing neither)

strRunTag : (name : string) → ctxt → strM → tagged-val
strRunTag name Γ m with m {TERM} [[]] 0 [] Γ nothing neither
...| s , n , ts = name , s , ts

to-string-tag : {ed : exprd} → string → ctxt → ⟦ ed ⟧ → tagged-val
to-string-tag name Γ t = strRunTag name Γ (to-stringh' neither t)

to-string : {ed : exprd} → ctxt → ⟦ ed ⟧ → rope
to-string Γ t = strRun Γ (to-stringh' neither t)

tk-to-string : ctxt → tk → rope
tk-to-string Γ (Tkt T) = to-string Γ T
tk-to-string Γ (Tkk k) = to-string Γ k

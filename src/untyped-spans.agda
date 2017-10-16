{- Module that generates semi-blank spans for the beta-reduction buffer -}

open import lib
open import ctxt

module untyped-spans where

open import cedille-types
open import spans
open import syntax-util
open import to-string


sloc = "location"
sll = "language-level"
sterm = "term"
stype = "type"
skind = "kind"
ssuperkind = "superkind"
scmd = "cmd"


{- Helper functions -}

get-loc-h : var → ctxt → tagged-val

get-loc : var → spanM tagged-val
get-loc v = get-ctxt (λ Γ → spanMr (get-loc-h v Γ))

get-loc-h v Γ with ctxt-get-info v Γ
get-loc-h v Γ | just (_ , (fp , pos)) = (sloc , fp ^ " - " ^ pos)
get-loc-h v Γ | nothing = (sloc , "missing - missing")

defTermOrType-start-pos : defTermOrType → posinfo
defTermOrType-start-pos (DefTerm pi _ _ _) = pi
defTermOrType-start-pos (DefType pi _ _ _) = pi

ll-term-tv : tagged-val
ll-term-tv = sll , sterm

type-tv : tagged-val
type-tv = stype , "[erased]"

symbol-tv : string → tagged-val
symbol-tv s = "symbol" , s


erased-spans : term → spanM ⊤
error-spans : string → spanM ⊤
error-spans s = λ Γ → λ ss → triv , Γ , (global-error s nothing)

inc-pi : posinfo → posinfo
inc-pi pi = posinfo-plus pi 1

put-span : posinfo → posinfo → 𝕃 tagged-val → spanM ⊤
put-span pi pi' tv = spanM-add (mk-span "" (inc-pi pi) (inc-pi pi') (ll-term-tv :: tv))

pi-plus-span : posinfo → string → 𝕃 tagged-val → spanM ⊤
pi-plus-span pi s tv = put-span pi (posinfo-plus-str pi s) tv

inc-span : posinfo → 𝕃 tagged-val → spanM ⊤
inc-span pi = put-span pi (inc-pi pi)

optTerm-span : optTerm → spanM ⊤
optTerm-span NoTerm = spanMok
optTerm-span (SomeTerm t pi) = erased-spans t

erased-var-span : posinfo → var → spanM ⊤
erased-var-span pi v = get-loc v ≫=span λ loc →
  pi-plus-span pi v (type-tv :: symbol-tv v :: loc :: [])

defTermOrType-span : defTermOrType → spanM ⊤
defTermOrType-span (DefTerm pi x m t) = erased-var-span pi x ≫span erased-spans t
defTermOrType-span (DefType pi x k tp) = error-spans "Type is defined!"

get-defTermOrType-pi-v : defTermOrType → (posinfo × var)
get-defTermOrType-pi-v (DefTerm pi x _ _) = pi , x
get-defTermOrType-pi-v _ = "" , ""


{-# TERMINATING #-}
erased-spans (App t me t') = put-span (term-start-pos t) (term-end-pos t') [] ≫span
  erased-spans t ≫span erased-spans t'
erased-spans (Beta pi ot) = optTerm-span ot
erased-spans (Hole pi) = inc-span pi []
erased-spans (Lam pi l pi' v oc t) =
  put-span pi (term-end-pos t) (binder-data-const :: []) ≫span
  get-ctxt (λ Γ →
    let Γ' = ctxt-var-decl pi' v Γ in
      set-ctxt Γ' ≫span
      erased-var-span pi' v ≫span
      erased-spans t ≫span
      set-ctxt Γ)
erased-spans (Let pi dtt t) =
  get-ctxt (λ Γ →
    put-span pi (term-end-pos t) (binder-data-const :: bound-data dtt Γ :: []) ≫span
    let pi-v = get-defTermOrType-pi-v dtt in
      let Γ' = ctxt-var-decl (fst pi-v) (snd pi-v) Γ in
        set-ctxt Γ' ≫span
        defTermOrType-span dtt ≫span
        erased-spans t ≫span
        set-ctxt Γ)
erased-spans (Parens _ t _) = erased-spans t
erased-spans (Var pi v) = erased-var-span pi v
erased-spans t = error-spans ("Unknown term: " ^ (ParseTreeToString (parsed-term t))
  ^ ", " ^ (to-string (new-ctxt "") t) ^ " (untyped-spans.agda)")

{-

untyped-term : term → spanM ⊤
untyped-type : type → spanM ⊤
untyped-kind : kind → spanM ⊤
untyped-tk : tk → spanM ⊤
untyped-cmd : cmd → spanM ⊤

inc-pi : posinfo → posinfo
inc-pi pi = posinfo-plus pi 1

put-span : posinfo → posinfo → string → spanM ⊤
put-span pi pi' ll = spanM-add (mk-span "" (inc-pi pi) (inc-pi pi') ((sll , ll) :: []))

pi-plus-span : posinfo → string → string → spanM ⊤
pi-plus-span pi s = put-span pi (posinfo-plus-str pi s)

inc-span : posinfo → string → spanM ⊤
inc-span pi = put-span pi (inc-pi pi)

optTerm-span : optTerm → spanM ⊤
optTerm-span NoTerm = spanMok
optTerm-span (SomeTerm t pi) = untyped-term t

optClass-span : optClass → spanM ⊤
optClass-span NoClass = spanMok
optClass-span (SomeClass t-k) = untyped-tk t-k

optType-span : optType → spanM ⊤
optType-span NoType = spanMok
optType-span (SomeType t) = untyped-type t

maybeAType-span : maybeAtype → spanM ⊤
maybeAType-span NoAtype = spanMok
maybeAType-span (Atype t) = untyped-type t

maybeCheckType-span : maybeCheckType → spanM ⊤
maybeCheckType-span (Type tp) = untyped-type tp
maybeCheckType-span NoCheckType = spanMok

defTermOrType-span : defTermOrType → spanM ⊤
defTermOrType-span (DefTerm pi x m t) = pi-plus-span pi x sterm ≫span maybeCheckType-span m ≫span untyped-term t
defTermOrType-span (DefType pi x k tp) = pi-plus-span pi x sterm ≫span untyped-kind k ≫span untyped-type tp

arg-span : arg → spanM ⊤
arg-span (TermArg t) = untyped-term t
arg-span (TypeArg tp) = untyped-type tp

args-spans : args → spanM posinfo
args-spans (ArgsCons h t) = arg-span h ≫span args-spans t
args-spans (ArgsNil pi) = spanMr pi

{- Span generating functions -}

untyped-term (App t me t') = put-span (term-start-pos t) (term-end-pos t') sterm ≫span
  untyped-term t ≫span untyped-term t'
untyped-term (AppTp t tp) = put-span (term-start-pos t) (type-end-pos tp) sterm ≫span
  untyped-term t ≫span untyped-type tp
untyped-term (Beta pi ot) = optTerm-span ot
untyped-term (Chi pi mt t) = maybeAType-span mt ≫span untyped-term t
untyped-term (Delta pi t) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Epsilon pi lr mm t) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Hole pi) = inc-span pi sterm
untyped-term (IotaPair pi t t' ot pi') = untyped-term t ≫span untyped-term t' ≫span
  optTerm-span ot
untyped-term (IotaProj t n pi) = put-span (term-start-pos t) pi sterm ≫span untyped-term t
untyped-term (Lam pi l pi' v oc t) = put-span pi (term-end-pos t) sterm ≫span
  optClass-span oc ≫span pi-plus-span pi' v sterm ≫span untyped-term t
untyped-term (Let pi dtt t) = put-span pi (term-end-pos t) sterm ≫span
  defTermOrType-span dtt
untyped-term (Omega pi t) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Parens pi t pi') = untyped-term t
untyped-term (PiInj pi n t) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Rho pi r t t') = put-span pi (term-end-pos t') sterm ≫span
  untyped-term t ≫span untyped-term t'
untyped-term (Sigma pi t) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Theta pi th t lts) = put-span pi (term-end-pos t) sterm ≫span untyped-term t
untyped-term (Unfold pi t) = untyped-term t
untyped-term (Var pi v) = get-loc v ≫=span λ loc → spanM-add (mk-span "" (inc-pi pi)
  (inc-pi (posinfo-plus-str pi v)) ((stype , "") :: (sll , sterm) :: loc))


untyped-type (Abs pi b pi' v t-k tp) = put-span pi (type-end-pos tp) stype ≫span
  pi-plus-span pi' v stype ≫span untyped-tk t-k ≫span untyped-type tp
untyped-type (IotaEx pi i-e pi' v ot tp) = put-span pi (type-end-pos tp) stype ≫span
  optType-span ot ≫span untyped-type tp
untyped-type (Lft pi pi' v t lt) = pi-plus-span pi' v stype ≫span untyped-term t
untyped-type (NoSpans tp pi) = untyped-type tp
untyped-type (TpApp tp tp') = put-span (type-start-pos tp) (type-end-pos tp') stype ≫span
  untyped-type tp ≫span untyped-type tp'
untyped-type (TpAppt tp t) = put-span (type-start-pos tp) (term-end-pos t) stype ≫span
  untyped-type tp ≫span untyped-term t
untyped-type (TpArrow tp at tp') = untyped-type tp ≫span untyped-type tp' ≫span
  put-span (type-start-pos tp) (type-end-pos tp') stype
untyped-type (TpEq t t') = put-span (term-start-pos t) (term-end-pos t') stype ≫span
  untyped-term t ≫span untyped-term t'
untyped-type (TpHole pi) = inc-span pi stype
untyped-type (TpLambda pi pi' v t-k tp) = put-span pi (type-end-pos tp) stype ≫span
  untyped-tk t-k ≫span pi-plus-span pi' v stype ≫span untyped-type tp
untyped-type (TpParens pi tp pi') = untyped-type tp
untyped-type (TpVar pi v) = get-loc v ≫=span λ loc → spanM-add (mk-span "" (inc-pi pi)
  (inc-pi (posinfo-plus-str pi v)) ((skind , "") :: (sll , stype) :: loc))


untyped-kind (KndArrow k k') = untyped-kind k ≫span untyped-kind k'
untyped-kind (KndParens pi k pi') = untyped-kind k
untyped-kind (KndPi pi pi' v t-k k) = put-span pi (kind-end-pos k) skind ≫span
  untyped-tk t-k ≫span untyped-kind k
untyped-kind (KndTpArrow tp k) = untyped-type tp ≫span untyped-kind k ≫span
  put-span (type-start-pos tp) (kind-end-pos k) skind
untyped-kind (KndVar pi kv as) = get-loc kv ≫=span λ loc → args-spans as ≫=span
  λ pi' → spanM-add (mk-span "" (inc-pi pi) (inc-pi (posinfo-plus pi (posinfo-to-ℕ pi')))
  ((sll , skind) :: (ssuperkind , "") :: loc))
untyped-kind (Star pi) = inc-span pi skind


untyped-tk (Tkt tp) = untyped-type tp
untyped-tk (Tkk k) = untyped-kind k


untyped-cmd (DefKind pi kv pms k pi') = pi-plus-span pi kv skind ≫span put-span pi pi' scmd
{- TODO: Implement params spans ↑↑↑ -}
untyped-cmd (DefTermOrType dtt pi) = defTermOrType-span dtt ≫span put-span (defTermOrType-start-pos dtt) pi scmd
untyped-cmd (Import pi fp pi') = put-span pi pi' scmd
-}

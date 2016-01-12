module spans where

open import lib
open import cedille-types 
open import ctxt
open import syntax-util
open import to-string

--------------------------------------------------
-- tagged values, which go in spans
--------------------------------------------------
tagged-val : Set
tagged-val = string × string

-- We number these when so we can sort them back in emacs
tagged-val-to-string : ℕ → tagged-val → string
tagged-val-to-string n (tag , val) = "\"" ^ tag ^ "\":\"" ^ ℕ-to-string n ^ " " ^ val ^ "\""

tagged-vals-to-string : ℕ → 𝕃 tagged-val → string
tagged-vals-to-string n [] = ""
tagged-vals-to-string n (s :: []) = tagged-val-to-string n s
tagged-vals-to-string n (s :: (s' :: ss)) = tagged-val-to-string n s ^ "," ^ tagged-vals-to-string (suc n) (s' :: ss)

--------------------------------------------------
-- span datatype
--------------------------------------------------
data span : Set where
  mk-span : string → posinfo → posinfo → 𝕃 tagged-val {- extra information for the span -} → span

span-to-string : span → string
span-to-string (mk-span name start end extra) = 
  "[\"" ^ name ^ "\"," ^ start ^ "," ^ end ^ ",{" ^ tagged-vals-to-string 0 extra ^ "}]"

data spans : Set where
  regular-spans : 𝕃 span → spans
  global-error : string {- error message -} → maybe span → spans

global-error-p : spans → 𝔹
global-error-p (global-error _ _) = tt
global-error-p _ = ff

empty-spans : spans
empty-spans = regular-spans []

spans-to-string : spans → string
spans-to-string (regular-spans ss) = "{\"spans\":[" ^ (string-concat-sep-map "," span-to-string ss) ^ "]}\n"
spans-to-string (global-error e o) = "{\"error\":\"" ^ e ^ helper o ^ "\"" ^ "}\n"
  where helper : maybe span → string
        helper (just x) = ", \"global-error\":" ^ span-to-string x
        helper nothing = ""

add-span : span → spans → spans
add-span s (regular-spans ss) = regular-spans (s :: ss)
add-span s (global-error e e') = global-error e e'

--------------------------------------------------
-- spanM, a state monad for spans
--------------------------------------------------
spanM : Set → Set
spanM A = spans → A × spans

-- return for the spanM monad
spanMr : ∀{A : Set} → A → spanM A
spanMr a ss = a , ss

spanMok : spanM ⊤
spanMok = spanMr triv

infixl 2 _≫span_ _≫=span_ _≫=spanj_ _≫=spanm_

_≫=span_ : ∀{A B : Set} → spanM A → (A → spanM B) → spanM B
(m ≫=span m') c with m c
(m ≫=span m') _ | v , c = m' v c

_≫span_ : ∀{A : Set} → spanM ⊤ → spanM A → spanM A
(m ≫span m') c = m' (snd (m c))

_≫=spanj_ : ∀{A : Set} → spanM (maybe A) → (A → spanM ⊤) → spanM ⊤
_≫=spanj_{A} m m' = m ≫=span cont
  where cont : maybe A → spanM ⊤
        cont nothing = spanMok
        cont (just x) = m' x

_≫=spanm_ : ∀{A : Set} → spanM (maybe A) → (A → spanM (maybe A)) → spanM (maybe A)
_≫=spanm_{A} m m' = m ≫=span cont
  where cont : maybe A → spanM (maybe A)
        cont nothing = spanMr nothing
        cont (just a) = m' a

spanM-add : span → spanM ⊤
spanM-add s ss = triv , add-span s ss

spanM-addl : 𝕃 span → spanM ⊤
spanM-addl [] = spanMok
spanM-addl (s :: ss) = spanM-add s ≫span spanM-addl ss

debug-span : posinfo → posinfo → 𝕃 tagged-val → span
debug-span pi pi' tvs = mk-span "Debug" pi pi' tvs

spanM-debug : posinfo → posinfo → 𝕃 tagged-val → spanM ⊤
--spanM-debug pi pi' tvs = spanM-add (debug-span pi pi' tvs)
spanM-debug pi pi' tvs = spanMok

--------------------------------------------------
-- tagged-val constants
--------------------------------------------------

explain : string → tagged-val
explain s = "explanation" , s

expected-type : type → tagged-val
expected-type tp = "expected-type" , type-to-string tp

expected-kind : kind → tagged-val
expected-kind tp = "expected kind" , kind-to-string tp

expected-kind-if : maybe kind → 𝕃 tagged-val → 𝕃 tagged-val
expected-kind-if nothing tvs = tvs
expected-kind-if (just k) tvs = expected-kind k :: tvs

expected-type-if : maybe type → 𝕃 tagged-val → 𝕃 tagged-val
expected-type-if nothing tvs = tvs
expected-type-if (just k) tvs = expected-type k :: tvs

missing-type : tagged-val
missing-type = "type" , "[undeclared]"

missing-kind : tagged-val
missing-kind = "kind" , "[undeclared]"

head-kind : kind → tagged-val
head-kind k = "the kind of the head" , kind-to-string k

head-type : type → tagged-val
head-type t = "the type of the head" , type-to-string t

type-app-head : type → tagged-val
type-app-head tp = "the head" , type-to-string tp

term-app-head : term → tagged-val
term-app-head t = "the head" , term-to-string t

term-argument : term → tagged-val
term-argument t = "the argument" , term-to-string t

type-argument : type → tagged-val
type-argument t = "the argument" , type-to-string t

type-data : type → tagged-val
type-data tp = "type" , type-to-string tp 

kind-data : kind → tagged-val
kind-data k = "kind" , kind-to-string k

super-kind-data : tagged-val
super-kind-data = "superkind" , "□"

error-data : string → tagged-val
error-data s = "error" , s

tk-data : tk → tagged-val
tk-data (Tkk k) = kind-data k
tk-data (Tkt t) = type-data t

ctxt-data : ctxt → tagged-val
ctxt-data Γ = "current context" , ctxt-to-string Γ

--------------------------------------------------
-- span-creating functions
--------------------------------------------------

Rec-span : posinfo → posinfo → kind → span
Rec-span pi pi' k = mk-span "Recursive datatype definition" pi pi' 
                      (kind-data k
                    :: [])

Star-name : string
Star-name = "Star"

parens-span : posinfo → posinfo → span
parens-span pi pi' = mk-span "parentheses" pi pi' []

data decl-class : Set where
  param : decl-class
  index : decl-class 

decl-class-name : decl-class → string
decl-class-name param = "parameter"
decl-class-name index = "index"

Decl-span : decl-class → posinfo → var → tk → posinfo → span
Decl-span dc pi v atk pi' = mk-span ((if tk-is-type atk then "Term " else "Type ") ^ (decl-class-name dc))
                                      pi pi' []

TpVar-span : posinfo → string → 𝕃 tagged-val → span
TpVar-span pi v tvs = mk-span "Type variable" pi (posinfo-plus-str pi v) tvs

Var-span : posinfo → string → 𝕃 tagged-val → span
Var-span pi v tvs = mk-span "Term variable" pi (posinfo-plus-str pi v) tvs

KndVar-span : posinfo → string → span
KndVar-span pi v = mk-span "Kind variable" pi (posinfo-plus-str pi v) [ super-kind-data ]

var-span : posinfo → string → tk → span
var-span pi x (Tkk k) = TpVar-span pi x [ kind-data k ]
var-span pi x (Tkt t) = Var-span pi x [ type-data t ]

TpAppt-span : type → term → 𝕃 tagged-val → span
TpAppt-span tp t tvs = mk-span "Application of a type to a term" (type-start-pos tp) (term-end-pos t) tvs

TpApp-span : type → type → 𝕃 tagged-val → span
TpApp-span tp tp' tvs = mk-span "Application of a type to a type" (type-start-pos tp) (type-end-pos tp') tvs

App-span : term → term → 𝕃 tagged-val → span
App-span t t' tvs = mk-span "Application of a term to a term" (term-start-pos t) (term-end-pos t') tvs

AppTp-span : term → type → 𝕃 tagged-val → span
AppTp-span t tp tvs = mk-span "Application of a term to a type" (term-start-pos t) (type-end-pos tp) tvs

TpQuant-e = 𝔹

is-pi : TpQuant-e
is-pi = tt

TpQuant-span : TpQuant-e → posinfo → var → tk → type → 𝕃 tagged-val → span
TpQuant-span is-pi pi x atk body tvs = mk-span (if is-pi then "Dependent function type" else "Implicit dependent function type")
                                         pi (type-end-pos body) tvs

TpLambda-span : posinfo → var → optClass → type → 𝕃 tagged-val → span
TpLambda-span pi x atk body tvs = mk-span "Type-level lambda abstraction" pi (type-end-pos body) tvs

-- a span boxing up the parameters and the indices of a Rec definition
RecPrelim-span : string → posinfo → posinfo → span
RecPrelim-span name pi pi' = mk-span ("Parameters, indices, and constructor declarations for datatype " ^ name) pi pi' []

TpArrow-span : type → type → 𝕃 tagged-val → span
TpArrow-span t1 t2 tvs = mk-span "Arrow type" (type-start-pos t1) (type-end-pos t2) tvs

TpEq-span : term → term → 𝕃 tagged-val → span
TpEq-span t1 t2 tvs = mk-span "Equation" (term-start-pos t1) (term-end-pos t2) tvs

Star-span : posinfo → span
Star-span pi = mk-span Star-name pi (posinfo-plus pi 1) []

KndPi-span : posinfo → var → tk → kind → span
KndPi-span pi x atk k = mk-span "Pi kind" pi (kind-end-pos k) [ super-kind-data ]

KndArrow-span : kind → kind → span
KndArrow-span k k' = mk-span "Arrow kind" (kind-start-pos k) (kind-end-pos k') [ super-kind-data ]

KndTpArrow-span : type → kind → span
KndTpArrow-span t k = mk-span "Arrow kind" (type-start-pos t) (kind-end-pos k) [ super-kind-data ]

Udefse-span : posinfo → 𝕃 tagged-val → span
Udefse-span pi tvs = mk-span "Empty constructor definitions part of a recursive type definition" pi (posinfo-plus pi 1) tvs

Ctordeclse-span : posinfo → 𝕃 tagged-val → span
Ctordeclse-span pi tvs = mk-span "Empty constructor declarations part of a recursive type definition" pi (posinfo-plus pi 1) tvs

Udef-span : posinfo → var → term → (normalized : 𝔹) → 𝕃 tagged-val → span
Udef-span pi x t normalized tvs =
  let tvs = tvs ++ ( explain ("Definition of constructor " ^ x) :: (if normalized then [ "normal form" , term-to-string t ] else [])) in
    mk-span "Constructor definition" pi (term-end-pos t) tvs

Ctordecl-span : posinfo → var → type → 𝕃 tagged-val → span
Ctordecl-span pi x tp tvs =
  mk-span "Constructor declaration" pi (type-end-pos tp) (tvs ++ [ explain ("Declaration of a type for constructor " ^ x)])

Udefs-span : udefs → span
Udefs-span us = mk-span "Constructor definitions (using lambda encodings)" (udefs-start-pos us) (udefs-end-pos us) []

Lam-span-erased : lam → string
Lam-span-erased ErasedLambda = "Erased lambda abstraction (term-level)"
Lam-span-erased KeptLambda = "Lambda abstraction (term-level)"

Lam-span : posinfo → lam → var → optClass → term → 𝕃 tagged-val → span
Lam-span pi l x NoClass tp tvs = mk-span (Lam-span-erased l) pi (term-end-pos tp) tvs
Lam-span pi l x (SomeClass atk) tp tvs = mk-span (Lam-span-erased l) pi (term-end-pos tp) 
                                           (tvs ++ [ "type of bound variable" , tk-to-string atk ])
DefTerm-span : posinfo → var → (checked : 𝔹) → maybe type → term → posinfo → span
DefTerm-span pi x checked tp t pi' = 
  h [ "normal form" , term-to-string t ] pi x checked tp pi'
  where h : 𝕃 tagged-val → posinfo → var → (checked : 𝔹) → maybe type → posinfo → span
        h tvs pi x tt _ pi' = 
          mk-span "Term-level definition (checking)" pi pi' tvs
        h tvs pi x ff (just tp) pi' = 
          mk-span "Term-level definition (synthesizing)" pi pi' ( ("synthesized type" , type-to-string tp) :: tvs)
        h tvs pi x ff nothing pi' = 
          mk-span "Term-level definition (synthesizing)" pi pi' ( ("synthesized type" , "[nothing]") :: tvs)
    
DefType-span : posinfo → var → (checked : 𝔹) → maybe kind → type → posinfo → span
DefType-span pi x tt _ _ pi' = mk-span "Type-level definition (checking)" pi pi' []
DefType-span pi x ff (just k) _ pi' =
  mk-span "Type-level definition (synthesizing)" pi pi' ( ("synthesized kind" , kind-to-string k) :: [])
DefType-span pi x ff nothing _ pi' =
  mk-span "Type-level definition (synthesizing)" pi pi' ( ("synthesized kind" , "[nothing]") :: [])

unimplemented-term-span : posinfo → posinfo → maybe type → span
unimplemented-term-span pi pi' nothing = mk-span "Unimplemented" pi pi' [ error-data "Unimplemented synthesizing a type for a term" ]
unimplemented-term-span pi pi' (just tp) = mk-span "Unimplemented" pi pi' 
                                              ( error-data "Unimplemented checking a term against a type" :: [ expected-type tp ])

unimplemented-type-span : posinfo → posinfo → maybe kind → span
unimplemented-type-span pi pi' nothing = mk-span "Unimplemented" pi pi' [ error-data "Unimplemented synthesizing a kind for a type" ]
unimplemented-type-span pi pi' (just k) = mk-span "Unimplemented" pi pi' 
                                              ( error-data "Unimplemented checking a type against a kind" :: [ expected-kind k ])

Beta-span : posinfo → 𝕃 tagged-val → span
Beta-span pi tvs = mk-span "Beta axiom" pi (posinfo-plus pi 1) 
                     (explain "A term constant whose type states that β-equal terms are provably equal" :: tvs)

hole-span : posinfo → maybe type → span
hole-span pi tp = mk-span "Hole" pi (posinfo-plus pi 1) (error-data "This hole remains to be filled in" :: expected-type-if tp [])

Epsilon-span : posinfo → leftRight → term → 𝕃 tagged-val → span
Epsilon-span pi lr t tvs = mk-span "Epsilon" pi (term-end-pos t) 
                            (tvs ++ [ explain ("Normalize the " ^ side lr ^ "-hand side of the expected equation.") ])
  where side : leftRight → string
        side Left = "left"
        side Right = "right"

Rho-span : posinfo → optnum → term → term → 𝕃 tagged-val → span
Rho-span pi n t t' tvs = mk-span "Rho" pi (term-end-pos t') 
                          (tvs ++ [ explain ("Rewrite terms in the expected type, using an equation. " ^ h n) ])
  where h : optnum → string
        h (SomeNum n) = "The " ^ n ^"'th occurrence is to be rewritten."
        h NoNum = "All occurrences are to be rewritten."

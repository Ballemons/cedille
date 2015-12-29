module spans where

open import lib
open import cedille-types 
open import syntax-util
open import to-string

--------------------------------------------------
-- tagged values, which go in spans
--------------------------------------------------
tagged-val : Set
tagged-val = string × string

tagged-val-to-string : tagged-val → string
tagged-val-to-string (tag , val) = "\"" ^ tag ^ "\":\"" ^ val ^ "\""

--------------------------------------------------
-- span datatype
--------------------------------------------------
data span : Set where
  mk-span : string → posinfo → posinfo → 𝕃 tagged-val {- extra information for the span -} → span

span-to-string : span → string
span-to-string (mk-span name start end extra) = 
  "[\"" ^ name ^ "\"," ^ start ^ "," ^ end ^ ",{" 
        ^ string-concat-sep-map "," tagged-val-to-string extra ^ "}]"

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

infixr 2 _≫span_ _≫=span_ 

_≫=span_ : ∀{A B : Set} → spanM A → (A → spanM B) → spanM B
(m ≫=span m') c with m c
(m ≫=span m') _ | v , c = m' v c

_≫span_ : ∀{A : Set} → spanM ⊤ → spanM A → spanM A
(m ≫span m') c = m' (snd (m c))

spanM-add : span → spanM ⊤
spanM-add s ss = triv , add-span s ss

spanMok : spanM ⊤
spanMok = spanMr triv

--------------------------------------------------
-- span constants
--------------------------------------------------
explain-name : string
explain-name = "explanation"

Rec-name : string
Rec-name = "Rec"

Rec-explain : string → tagged-val
Rec-explain datatype-name = (explain-name , "Definition of recursive datatype " ^ datatype-name)

Star-name : string
Star-name = "Star"

Decl-span : 𝔹 → posinfo → var → tk → posinfo → span
Decl-span is-param pi v atk pi' = mk-span ((if tk-is-type atk then "Term " else "Type ") ^ (if is-param then "parameter" else "index"))
                                      pi pi' []

TpVar-span : string → posinfo → 𝕃 tagged-val → span
TpVar-span v pi tvs = mk-span "Type variable" pi (ℕ-to-string (string-length v + (posinfo-to-ℕ pi))) tvs

expected-type : type → tagged-val
expected-type tp = "expected-type" , type-to-string tp

expected-kind : kind → tagged-val
expected-kind tp = "expected-kind" , kind-to-string tp

missing-type : tagged-val
missing-type = "type" , "[undeclared]"

missing-kind : tagged-val
missing-kind = "kind" , "[undeclared]"

type-data : type → tagged-val
type-data tp = "type" , type-to-string tp 

kind-data : kind → tagged-val
kind-data k = "kind" , kind-to-string k

error-data : string → tagged-val
error-data s = "error" , s

tk-data : tk → tagged-val
tk-data (Tkk k) = kind-data k
tk-data (Tkt t) = type-data t


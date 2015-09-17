module check-util where

open import lib

open import cedille-types
open import defeq
open import free
open import lift
open import rename
open import syntax-util
open import subst
open import tpstate

{-# NO_TERMINATION_CHECK #-}
u-type : tpstate → (var → 𝔹) → kind → error-t type
u-type s b (KndArrow k k') = u-type s b k' ≫=err λ r → no-error (AbsTp2 Lambda (tpstate-fresh-var s b "X" empty-renamectxt) (Tkk k) r)
u-type s b (KndParens k) = u-type s b k
u-type s b (KndPi x a k) =  u-type s b k ≫=err λ r → no-error (AbsTp2 Lambda x a r)
u-type s b (KndTpArrow t k) = u-type s b k ≫=err λ r → no-error (AbsTp2 Lambda (tpstate-fresh-var s b "x" empty-renamectxt) (Tkt t) r)
u-type s b (KndVar x) with lookup-kind-var s x
u-type s b (KndVar x) | nothing = yes-error ("No definition was found for kind variable " ^ x ^ " (should not happen.)")
u-type s b (KndVar x) | just k = u-type s b k
u-type s b Star = no-error U


unimplemented : string → ∀{A : Set} → error-t A
unimplemented s = yes-error (s ^ " is currently unimplemented.\n")

evwrong-kind : renamectxt → evidence → kind → check-t
evwrong-kind r e k = 
  yes-error ("The wrong form of evidence was given for checking a kind.\n" 
              ^ "1. the evidence: " ^ evidence-to-string r e ^ "\n"
              ^ "2. the kind: " ^ kind-to-string r k)

evwrong-type : renamectxt → evidence → type → kind → check-t
evwrong-type r e t k = 
  yes-error ("The wrong form of evidence was given for checking a kinding.\n"
           ^ "1. the evidence: " ^ evidence-to-string r e ^ "\n"
           ^ "2. the kinding: " ^ type-to-string r t ^ " : " ^ kind-to-string r k)

evwrong-ctorset-k : renamectxt → ctorset → check-t
evwrong-ctorset-k r Θ = 
  yes-error ("Encountered the wrong form of evidence for checking that the following ctor set is kindable:\n"
           ^ ctorset-to-string r Θ)

evwrong-ctorset : renamectxt → ctorset → check-t
evwrong-ctorset r Θ = 
  yes-error ("Encountered the wrong form of evidence for checking the following ctor set:\n"
           ^ ctorset-to-string r Θ)

evwrong-term : renamectxt → term → type → check-t
evwrong-term r x y = 
  yes-error ("Encountered the wrong form of evidence for checking the following typing:\n"
           ^ term-to-string r x ^ " : " ^ type-to-string r y)

holewrong-type : renamectxt → type → synth-t kind
holewrong-type r l = 
  yes-error ("A hole is being used where we need to synthesize a kind for the following type:\n"
           ^ type-to-string r l)

holewrong-term : renamectxt → term → synth-t type
holewrong-term r t = 
  yes-error ("A hole is being used where we need to synthesize a type for the following term:\n"
           ^ term-to-string r t)

synth-type-errstr : renamectxt → type → string
synth-type-errstr r t = "the type whose kind we are trying to synthesize: " ^ type-to-string r t

synth-term-errstr : renamectxt → term → string
synth-term-errstr r t = "the term whose type we are trying to synthesize: " ^ term-to-string r t

add-to-def-error : string → string → error-t tpstate
add-to-def-error v m = yes-error ("While checking the definition of " ^ v ^ ":\n" ^ m)

redefine-err : var → string
redefine-err x = "The symbol " ^ x ^ " is being redefined (not allowed).\n"
def-assert-free : tpstate → ctxt → var → error-t ⊤
def-assert-free s (Δ , b , r) x =
 if rename-pred s b x then yes-error (redefine-err x) else no-error triv

ctorset-find-term : tpstate → ctxt → term → ctorset → maybe type
ctorset-find-term s (Δ , b , r) t (Add trm tp Θ₁) with eq-term s (bctxt-contains b) r t trm
ctorset-find-term s (Δ , b , r) t (Add trm tp Θ₁) | tt = just tp
ctorset-find-term s (Δ , b , r) t (Add trm tp Θ₁) | ff = ctorset-find-term s (Δ , b , r) t Θ₁
ctorset-find-term s (Δ , b , r) t Empty = nothing

convert-type-rbeta-lift-err : renamectxt → string → type → string
convert-type-rbeta-lift-err r nstr tp = "Doing an rbeta-lift conversion, we could not remove " ^ nstr ^ " arguments from a type.\n"
                                      ^ "1. the type we were supposed to remove those arguments from: " ^ type-to-string r tp

synth-type-t : Set
synth-type-t = tpstate → ctxt → evidence → type → synth-t kind

try-synth-type-t : Set
try-synth-type-t = tpstate → ctxt → evidence → type → kind → check-t

synth-term-t : Set
synth-term-t = tpstate → ctxt → evidence → term → synth-t type

try-synth-term-t : Set
try-synth-term-t = tpstate → ctxt → evidence → term → type → check-t

data s-t : Set where
  mk-s : synth-type-t → try-synth-type-t → synth-term-t → try-synth-term-t → s-t


module rewriting where

open import lib

open import cedille-types
open import conversion
open import ctxt
open import general-util
open import is-free
open import rename
open import subst
open import syntax-util

rewrite-t : Set → Set
rewrite-t T = ctxt → (is-plus : 𝔹) → (nums : maybe stringset) →
              (left : term) → (right : term) → (total-matches : ℕ) →
              T {- Returned value -} ×
              ℕ {- Number of rewrites actually performed -} ×
              ℕ {- Total number of matches, including skipped ones -}

infixl 4 _≫rewrite_

_≫rewrite_ : ∀ {A B : Set} → rewrite-t (A → B) → rewrite-t A → rewrite-t B
(f ≫rewrite a) Γ op on t₁ t₂ n with f Γ op on t₁ t₂ n
...| f' , n' , sn with a Γ op on t₁ t₂ sn
...| b , n'' , sn' = f' b , n' + n'' , sn'

rewriteR : ∀ {A : Set} → A → rewrite-t A
rewriteR a Γ op on t₁ t₂ n = a , 0 , n

{-# TERMINATING #-}
rewrite-term : term → rewrite-t term
rewrite-terma : term → rewrite-t term
rewrite-termh : term → rewrite-t term
rewrite-type : type → rewrite-t type
rewrite-kind : kind → rewrite-t kind
rewrite-tk : tk → rewrite-t tk
rewrite-liftingType : liftingType → rewrite-t liftingType

rewrite-rename-var : ∀ {A} → var → (var → rewrite-t A) → rewrite-t A
rewrite-rename-var x r Γ op on t₁ t₂ n =
  let x' = rename-var-if Γ empty-renamectxt x (App t₁ NotErased t₂) in
  r x' Γ op on t₁ t₂ n

rewrite-abs : ∀ {A} → (ctxt → var → var → 𝔹 → A → A) → var → var → 𝔹 → (A → rewrite-t A) → A → rewrite-t A
rewrite-abs f x x' b g a Γ = let Γ = ctxt-var-decl posinfo-gen x' Γ in g (f Γ x x' b a) Γ
rewrite-term-abs = rewrite-abs rename-term
rewrite-type-abs = rewrite-abs rename-type
rewrite-kind-abs = rewrite-abs rename-kind

rewrite-term t = rewrite-terma (erase-term t)

rewrite-terma t Γ op on t₁ t₂ sn =
  case conv-term Γ t₁ t of λ where
  tt → case on of λ where
    (just ns) → case trie-contains ns (ℕ-to-string (suc sn)) of λ where
      tt → t₂ , 1 , suc sn -- ρ nums contains n
      ff → t , 0 , suc sn -- ρ nums does not contain n
    nothing → t₂ , 1 , suc sn
  ff → case op of λ where
    tt → case rewrite-termh (hnf Γ unfold-head t tt) Γ op on t₁ t₂ sn of λ where
      (t' , 0 , sn') → t , 0 , sn' -- if no rewrites were performed, return the pre-hnf t
      (t' , n' , sn') → t' , n' , sn'
    ff → rewrite-termh t Γ op on t₁ t₂ sn

rewrite-termh (App t e t') =
  rewriteR App ≫rewrite rewrite-terma t ≫rewrite rewriteR e ≫rewrite rewrite-terma t'
rewrite-termh (Lam pi KeptLambda pi' y NoClass t) =
  rewrite-rename-var y λ y' → rewriteR (Lam pi KeptLambda pi' y' NoClass) ≫rewrite
  rewrite-term-abs y y' tt rewrite-terma t
rewrite-termh (Parens _ t _) = rewrite-terma t
rewrite-termh (Var pi x) = rewriteR (Var pi x)
rewrite-termh = rewriteR

rewrite-type (Abs pi b pi' x atk T) =
  rewrite-rename-var x λ x' → 
  rewriteR (Abs pi b pi' x') ≫rewrite rewrite-tk atk ≫rewrite
  rewrite-type-abs x x' (tk-is-type atk) rewrite-type T
rewrite-type (Iota pi pi' x T T') =
  rewrite-rename-var x λ x' →
  rewriteR (Iota pi pi' x') ≫rewrite rewrite-type T ≫rewrite
  rewrite-type-abs x x' tt rewrite-type T'
rewrite-type (Lft pi pi' x t l) =
  rewrite-rename-var x λ x' →
  rewriteR (Lft pi pi' x') ≫rewrite
  rewrite-term-abs x x' ff rewrite-term t ≫rewrite
  rewrite-liftingType l
rewrite-type (TpApp T T') =
  rewriteR TpApp ≫rewrite rewrite-type T ≫rewrite rewrite-type T'
rewrite-type (TpAppt T t) =
  rewriteR TpAppt ≫rewrite rewrite-type T ≫rewrite rewrite-term t
rewrite-type (TpEq pi t₁ t₂ pi') =
  rewriteR (TpEq pi) ≫rewrite rewrite-term t₁ ≫rewrite
  rewrite-term t₂ ≫rewrite rewriteR pi'
rewrite-type (TpLambda pi pi' x atk T) =
  rewrite-rename-var x λ x' →
  rewriteR (TpLambda pi pi' x') ≫rewrite rewrite-tk atk ≫rewrite
  rewrite-type-abs x x' (tk-is-type atk) rewrite-type T
rewrite-type (TpArrow T a T') =
  rewriteR TpArrow ≫rewrite rewrite-type T ≫rewrite rewriteR a ≫rewrite rewrite-type T'
rewrite-type (TpParens _ T _) = rewrite-type T
rewrite-type (NoSpans T _) = rewrite-type T
rewrite-type (TpVar pi x) = rewriteR (TpVar pi x)
rewrite-type = rewriteR

rewrite-kind = rewriteR -- Unimplemented

rewrite-liftingType = rewriteR -- Unimplemented

rewrite-tk (Tkt T) = rewriteR Tkt ≫rewrite rewrite-type T
rewrite-tk (Tkk k) = rewriteR Tkk ≫rewrite rewrite-kind k

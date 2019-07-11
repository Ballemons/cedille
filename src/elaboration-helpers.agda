import cedille-options
module elaboration-helpers (options : cedille-options.options) where

open import general-util
open import cedille-types
open import syntax-util
open import type-util
open import ctxt
open import conversion
open import constants
open import instances
open import subst
open import rename
open import rewriting
open import free-vars
open import toplevel-state options {IO}
--open import spans options {Id}
open import datatype-functions
--open import templates

{-
uncurry' : ∀ {A B C D : Set} → (A → B → C → D) → (A × B × C) → D
uncurry' f (a , b , c) = f a b c

uncurry'' : ∀ {A B C D E : Set} → (A → B → C → D → E) → (A × B × C × D) → E
uncurry'' f (a , b , c , d) = f a b c d

uncurry''' : ∀ {A B C D E F : Set} → (A → B → C → D → E → F) → (A × B × C × D × E) → F
uncurry''' f (a , b , c , d , e) = f a b c d e

ctxt-lookup-term-var' : ctxt → var → maybe type
ctxt-lookup-term-var' Γ @ (mk-ctxt (fn , mn , ps , q) ss is Δ) x =
  env-lookup Γ x >>= λ where
    (term-decl T , _) → just T
    (term-def ps _ _ T , _ , x') →
      let ps = maybe-else [] id ps in
      just $ abs-expand-type ps T
    _ → nothing

-- TODO: Could there be parameter/argument clashes if the same parameter variable is defined multiple times?
-- TODO: Could variables be parameter-expanded multiple times?
ctxt-lookup-type-var' : ctxt → var → maybe kind
ctxt-lookup-type-var' Γ @ (mk-ctxt (fn , mn , ps , q) ss is Δ) x =
  env-lookup Γ x >>= λ where
    (type-decl k , _) → just k
    (type-def ps _ _ k , _ , x') →
      let ps = maybe-else [] id ps in
      just $ abs-expand-kind ps k
    _ → nothing
-}

{-
restore-renamectxt : renamectxt → 𝕃 (var × maybe var) → renamectxt
restore-renamectxt = foldr $ uncurry λ x x' ρ → maybe-else' x' (renamectxt-remove ρ x) (renamectxt-insert ρ x)

restore-ctxt-params : ctxt → 𝕃 (var × maybe qualif-info) → ctxt
restore-ctxt-params = foldr $ uncurry λ x x' Γ → ctxt-set-qualif Γ (maybe-else' x' (trie-remove (ctxt-get-qualif Γ) x) (trie-insert (ctxt-get-qualif Γ) x))
-}

rename-validify : string → string
rename-validify = 𝕃char-to-string ∘ (h ∘ string-to-𝕃char) where
  validify-char : char → 𝕃 char
  validify-char '/' = [ '-' ]
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
fresh-var' : string → (string → 𝔹) → string
fresh-var' x f = fresh-h f (rename-validify x)

rename-new_from_for_ : ∀ {X : Set} → var → ctxt → (var → X) → X
rename-new ignored-var from Γ for f = f $ fresh-var' "x" (ctxt-binds-var Γ)
rename-new x from Γ for f = f $ fresh-var' x (ctxt-binds-var Γ)

rename_from_for_ : ∀ {X : Set} → var → ctxt → (var → X) → X
rename ignored-var from Γ for f = f ignored-var
rename x from Γ for f = f $ fresh-var' x (ctxt-binds-var Γ)

get-renaming : renamectxt → var → var → var × renamectxt
get-renaming ρₓ xₒ x = let x' = fresh-var' x (renamectxt-in-field ρₓ) in x' , renamectxt-insert ρₓ xₒ x'

rename_-_from_for_ : ∀ {X : Set} → var → var → renamectxt → (var → renamectxt → X) → X
rename xₒ - ignored-var from ρₓ for f = f ignored-var ρₓ
rename xₒ - x from ρₓ for f = uncurry f $ get-renaming ρₓ xₒ x

rename_-_lookup_for_ : ∀ {X : Set} → var → var → renamectxt → (var → renamectxt → X) → X
rename xₒ - x lookup ρₓ for f with renamectxt-lookup ρₓ xₒ
...| nothing = rename xₒ - x from ρₓ for f
...| just x' = f x' ρₓ

module reindexing (Γ : ctxt) (D I mn : var) (isₒ : indices) (psₜ : params) where

  reindex-fresh-var : qualif → trie indices → var → var
  reindex-fresh-var ρₓ is ignored-var = ignored-var
  reindex-fresh-var ρₓ is x =
    fresh-h (λ x' → ctxt-binds-var Γ x' || trie-contains is x' || trie-contains ρₓ x') x

  rename-indices' : qualif → trie indices → indices
  rename-indices' ρₓ is = foldr {B = renamectxt → qualif → indices}
    (λ {(Index x atk) f r ρₓ →
       let x' = reindex-fresh-var ρₓ is x in
       Index x' (substh Γ r empty-trie -tk atk) :: f (renamectxt-insert r x x') (trie-insert ρₓ x (x' , []))})
    (λ r ρₓ → []) isₒ empty-renamectxt ρₓ
  
  reindex-t : Set → Set
  reindex-t X = qualif → trie indices → X → X
  
  {-# TERMINATING #-}
  reindex : ∀ {ed} → reindex-t ⟦ ed ⟧

  rc-is : qualif → indices → qualif
  rc-is = foldr λ {(Index x atk) ρₓ → trie-insert ρₓ x (x , [])}

  is-index-var : maybe tpkd → 𝔹
  is-index-var (just (Tkt (TpVar x))) = x =string I
  is-index-var _ = ff
  
--  reindex {TERM} ρₓ is (App t (Var x)) with trie-lookup is x
--  ...| nothing = App (reindex ρₓ is t) $ reindex ρₓ is $ Var x
--  ...| just is' = indices-to-apps is' $ reindex ρₓ is t
  reindex {TERM} ρₓ is (AppEr t (Var x)) with trie-lookup is x
  ...| nothing = AppEr (reindex ρₓ is t) $ reindex ρₓ is $ Var x
  ...| just is' = indices-to-apps is' $ reindex ρₓ is t
  reindex {TERM} ρₓ is (App t t') =
    App (reindex ρₓ is t) (reindex ρₓ is t')
  reindex {TERM} ρₓ is (AppE t tT) =
    AppE (reindex ρₓ is t) (reindex ρₓ is -tT tT)
  reindex {TERM} ρₓ is (Beta t t') =
    Beta (reindex ρₓ is t) (reindex ρₓ is t')
  reindex {TERM} ρₓ is (Delta T t) =
    Delta (reindex ρₓ is T) (reindex ρₓ is t)
  reindex {TERM} ρₓ is (Hole pi) =
    Hole pi
  reindex {TERM} ρₓ is (IotaPair t₁ t₂ x Tₓ) =
    let x' = reindex-fresh-var ρₓ is x in
    IotaPair (reindex ρₓ is t₁) (reindex ρₓ is t₂) x'
      (reindex (trie-insert ρₓ x (x' , [])) is Tₓ)
  reindex {TERM} ρₓ is (IotaProj t n) =
    IotaProj (reindex ρₓ is t) n
  reindex {TERM} ρₓ is (Lam me x tk? t) with is-index-var tk?
  ...| ff = let x' = reindex-fresh-var ρₓ is x in
    Lam me x' (reindex ρₓ is -tk_ <$> tk?) (reindex (trie-insert ρₓ x (x' , [])) is t)
  ...| tt with rename-indices' ρₓ is
  ...| isₙ = indices-to-lams isₙ $ reindex (rc-is ρₓ isₙ) (trie-insert is x isₙ) t
  reindex {TERM} ρₓ is (LetTm me x T? t t') =
    let x' = reindex-fresh-var ρₓ is x in
    LetTm me x' (reindex ρₓ is <$> T?) (reindex ρₓ is t) (reindex (trie-insert ρₓ x (x' , [])) is t')
  reindex {TERM} ρₓ is (LetTp x k T t) =
    let x' = reindex-fresh-var ρₓ is x in
    LetTp x' (reindex ρₓ is k) (reindex ρₓ is T) (reindex (trie-insert ρₓ x (x' , [])) is t)
  reindex {TERM} ρₓ is (Phi t₌ t₁ t₂) =
    Phi (reindex ρₓ is t₌) (reindex ρₓ is t₁) (reindex ρₓ is t₂)
  reindex {TERM} ρₓ is (Rho t₌ x Tₓ t) =
    let x' = reindex-fresh-var ρₓ is x in
    Rho (reindex ρₓ is t) x' (reindex (trie-insert ρₓ x (x' , [])) is Tₓ) (reindex ρₓ is t)
  reindex {TERM} ρₓ is (Sigma t) =
    Sigma (reindex ρₓ is t)
  reindex {TERM} ρₓ is (Var x) =
    maybe-else' (trie-lookup ρₓ x) (Var x) (uncurry (apps-term ∘ Var))
  reindex {TERM} ρₓ is (Mu μ t Tₘ? f~ cs) = Var "template-mu-not-allowed"
  
  reindex {TYPE} ρₓ is (TpAbs me x atk T) with is-index-var (just atk)
  ...| ff = let x' = reindex-fresh-var ρₓ is x in
    TpAbs me x' (reindex ρₓ is -tk atk) (reindex (trie-insert ρₓ x (x' , [])) is T)
  ...| tt = let isₙ = rename-indices' ρₓ is in
    indices-to-alls isₙ $ reindex (rc-is ρₓ isₙ) (trie-insert is x isₙ) T
  reindex {TYPE} ρₓ is (TpEq t₁ t₂) =
    TpEq (reindex ρₓ is t₁) (reindex ρₓ is t₂)
  reindex {TYPE} ρₓ is (TpIota x T T') =
    let x' = reindex-fresh-var ρₓ is x in
    TpIota x' (reindex ρₓ is T) (reindex (trie-insert ρₓ x (x' , [])) is T')
  reindex {TYPE} ρₓ is (TpAppTm T (Var x)) with trie-lookup is x
  ...| nothing = TpAppTm (reindex ρₓ is T) $ reindex ρₓ is $ Var x
  ...| just is' = indices-to-tpapps is' $ reindex ρₓ is T
--  reindex {TYPE} ρₓ is (TpAppTp T (TpVar x)) with trie-lookup is x
--  ...| nothing = TpAppTp (reindex ρₓ is T) $ reindex ρₓ is $ TpVar x
--  ...| just is' = indices-to-tpapps is' $ reindex ρₓ is T
  reindex {TYPE} ρₓ is (TpApp T tT) =
    TpApp (reindex ρₓ is T) (reindex ρₓ is -tT tT)
  reindex {TYPE} ρₓ is (TpHole pi) =
    TpHole pi
  reindex {TYPE} ρₓ is (TpLam x atk T) with is-index-var (just atk)
  ...| ff = let x' = reindex-fresh-var ρₓ is x in
    TpLam x' (reindex ρₓ is -tk atk) (reindex (trie-insert ρₓ x (x' , [])) is T)
  ...| tt = let isₙ = rename-indices' ρₓ is in
    indices-to-tplams isₙ $ reindex (rc-is ρₓ isₙ) (trie-insert is x isₙ) T
  reindex {TYPE} ρₓ is (TpVar x) =
    maybe-else' (trie-lookup ρₓ x) (TpVar x) (uncurry (apps-type ∘ TpVar))
  
  reindex {KIND} ρₓ is (KdAbs x atk k) with is-index-var (just atk)
  ...| ff = let x' = reindex-fresh-var ρₓ is x in
    KdAbs x' (reindex ρₓ is -tk atk) (reindex (trie-insert ρₓ x (x' , [])) is k)
  ...| tt = let isₙ = rename-indices' ρₓ is in
    indices-to-kind isₙ $ reindex (rc-is ρₓ isₙ) (trie-insert is x isₙ) k
  reindex {KIND} ρₓ is (KdHole pi) =
    KdHole pi
  reindex {KIND} ρₓ is KdStar =
    KdStar

  reindex-cmd : qualif → trie indices → cmd → cmd × qualif
  reindex-cmd ρₓ is (CmdImport (Import p? fp mnᵢ q? as)) =
    CmdImport (Import p? fp mnᵢ q? (reindex ρₓ is -arg_ <$> as)) , ρₓ
  reindex-cmd ρₓ is (CmdDefTerm x t) =
    let x' = {-rename-validify-} (D ^ "/" ^ x) in
    CmdDefTerm x' (lam-expand-term psₜ $ reindex ρₓ is t) ,
    trie-insert ρₓ (mn # x) (ctxt-get-current-modname Γ # x' , params-to-args psₜ)
  reindex-cmd ρₓ is (CmdDefType x k T) =
    let x' = {-rename-validify-} (D ^ "/" ^ x) in
    CmdDefType x' (abs-expand-kind psₜ $ reindex ρₓ is k)
                  (lam-expand-type psₜ $ reindex ρₓ is T) ,
    trie-insert ρₓ (mn # x) (ctxt-get-current-modname Γ # x' , params-to-args psₜ)
  reindex-cmd ρₓ is (CmdDefKind x ps k) =
    CmdDefKind x ps k , ρₓ
  reindex-cmd ρₓ is (CmdDefData es x ps k cs) =
    CmdDefData es x ps k cs , ρₓ
  
  reindex-cmds : qualif → trie indices → cmds → cmds
  reindex-cmds ρₓ is cs =
    foldr
      (λ c rec ρₓ → elim reindex-cmd ρₓ is c for λ c ρₓ → c :: rec ρₓ)
      (λ ρₓ → []) cs ρₓ

reindex-file : ctxt → (D I modname : var) → indices → params → cmds → cmds
reindex-file Γ D I mn is ps cs =
  let ps' = ctxt-get-current-params Γ ++ params-set-erased Erased ps
      open reindexing Γ D I mn is ps' in
  reindex-cmds empty-trie empty-trie cs

-- Maps over expression, elaborating all mu-terms
{-# TERMINATING #-}
choose-mu : ∀ {ed} → ⟦ ed ⟧ → ⟦ ed ⟧
choose-mu {TERM} (App tm tm') = App (choose-mu tm) (choose-mu tm')
choose-mu {TERM} (AppE tm tT) = AppE (choose-mu tm) (choose-mu -tT tT)
choose-mu {TERM} (Beta tm tm') = Beta (choose-mu tm) (choose-mu tm')
choose-mu {TERM} (Delta tp tm) = Delta (choose-mu tp) (choose-mu tm)
choose-mu {TERM} (Hole pi) = Hole pi
choose-mu {TERM} (IotaPair tm₁ tm₂ x Tₓ) = IotaPair (choose-mu tm₁) (choose-mu tm₂) x (choose-mu Tₓ)
choose-mu {TERM} (IotaProj tm n) = IotaProj (choose-mu tm) n
choose-mu {TERM} (Lam e x tk? tm) = Lam e x (choose-mu -tk_ <$> tk?) (choose-mu tm)
choose-mu {TERM} (LetTm e x tp? tm tm') = LetTm e x (choose-mu <$> tp?) (choose-mu tm) (choose-mu tm')
choose-mu {TERM} (LetTp x k T t) = LetTp x (choose-mu k) (choose-mu T) (choose-mu t)
choose-mu {TERM} (Phi tm₌ tm₁ tm₂) = Phi (choose-mu tm₌) (choose-mu tm₁) (choose-mu tm₂)
choose-mu {TERM} (Rho tm₌ x Tₓ tm) = Rho (choose-mu tm₌) x (choose-mu Tₓ) (choose-mu tm)
choose-mu {TERM} (Sigma tm) = Sigma (choose-mu tm)
choose-mu {TERM} (Mu μ t tp? ~> cs) = ~> t tp? cs
choose-mu {TERM} (Var x) = Var x
choose-mu {TYPE} (TpAbs e x tk tp) = TpAbs e x (choose-mu -tk tk) (choose-mu tp)
choose-mu {TYPE} (TpIota x tp₁ tp₂) = TpIota x (choose-mu tp₁) (choose-mu tp₂)
choose-mu {TYPE} (TpApp tp tT) = TpApp (choose-mu tp) (choose-mu -tT tT)
choose-mu {TYPE} (TpEq tmₗ tmᵣ) = TpEq (choose-mu tmₗ) (choose-mu tmᵣ)
choose-mu {TYPE} (TpHole pi) = TpHole pi
choose-mu {TYPE} (TpLam x tk tp) = TpLam x (choose-mu -tk tk) (choose-mu tp)
choose-mu {TYPE} (TpVar x) = TpVar x
choose-mu {KIND} (KdAbs x tk kd) = KdAbs x (choose-mu -tk tk) (choose-mu kd)
choose-mu {KIND} (KdHole pi) = KdHole pi
choose-mu {KIND} KdStar = KdStar


-- Adds all encoding definitions' values to the ctxt
ctxt-open-encoding-defs : ctxt → ctxt
ctxt-open-encoding-defs Γ with ctxt.Δ Γ | ctxt.i Γ
...| _ , _ , _ , μ~ , _ | i =
  let tmd = λ t → term-def nothing opacity-open (just t) (TpHole pi-gen)
      tpd = λ T → type-def nothing opacity-open (just T) (KdHole pi-gen) in
  record Γ { i = foldr
    (uncurry λ x tT i →
      trie-insert i x
        (either-else' tT
          (tmd ∘ hnf (record Γ {i = i}) unfold-head)
          (tpd ∘ hnf (record Γ {i = i}) unfold-head-elab) ,
         "missing" , "missing")) i μ~ }


mk-ctr-fmap-t : Set → Set
mk-ctr-fmap-t X = ctxt → (var × var × var × term) → X
{-# TERMINATING #-}
mk-ctr-fmap-η+ : mk-ctr-fmap-t (term → type → term)
mk-ctr-fmap-η- : mk-ctr-fmap-t (term → type → term)
mk-ctr-fmap-η? : mk-ctr-fmap-t (term → type → term) → mk-ctr-fmap-t (term → type → term)
mk-ctr-fmapₖ-η+ : mk-ctr-fmap-t (type → kind → type)
mk-ctr-fmapₖ-η- : mk-ctr-fmap-t (type → kind → type)
mk-ctr-fmapₖ-η? : mk-ctr-fmap-t (type → kind → type) → mk-ctr-fmap-t (type → kind → type)

mk-ctr-fmap-η? f Γ x body T with is-free-in (fst x) T
...| tt = f Γ x body T
...| ff = body

mk-ctr-fmapₖ-η? f Γ x body k with is-free-in (fst x) k
...| tt = f Γ x body k
...| ff = body

mk-ctr-fmap-η+ Γ x @ (Aₓ , Bₓ , _) body T with decompose-ctr-type Γ T
...| Tₕ , as , _ =
  params-to-lams as $
  let Γ' = add-params-to-ctxt as Γ
      tₓ' = case Tₕ of λ where
              (TpIota x'' T₁ T₂) body →
                let t₁ = mk-ctr-fmap-η+ Γ' x (IotaProj body ι1) T₁
                    t₂ = mk-ctr-fmap-η+ Γ' x (IotaProj body ι2) (subst Γ' t₁ x'' T₂) in
                IotaPair t₁ t₂ x'' T₂ -- TODO: T₂ or [Bₓ/Aₓ]T₂ ?
              _ body → body
  in
  tₓ' $ foldl
    (λ {(Param me x'' (Tkt T)) body →
          (if me then AppEr body else App body) $
            mk-ctr-fmap-η? mk-ctr-fmap-η- Γ' x (Var x'') T;
        (Param _ x'' (Tkk k)) body →
          AppTp body $ mk-ctr-fmapₖ-η? mk-ctr-fmapₖ-η- Γ' x (TpVar x'') k})
    body as

mk-ctr-fmap-η- Γ xₒ @ (Aₓ , Bₓ , cₓ , castₓ) body T with decompose-ctr-type Γ T
...| TpVar x'' , as , rs =
  params-to-lams (substh-params Γ (renamectxt-single Aₓ Bₓ) empty-trie as) $
  let Γ' = add-params-to-ctxt as Γ in
  if x'' =string Aₓ
    then App (recompose-apps (tmtps-to-args Erased rs) $
                AppEr (AppTp (AppTp castₓ (TpVar Aₓ)) (TpVar Bₓ)) (Var cₓ))
    else id $
  foldl (λ {(Param me x'' (Tkt T)) body →
              (if me then AppEr body else App body) $
                 mk-ctr-fmap-η? mk-ctr-fmap-η+ Γ' xₒ (Var x'') T;
            (Param me x'' (Tkk k)) body →
              AppTp body $ mk-ctr-fmapₖ-η? mk-ctr-fmapₖ-η+ Γ' xₒ (TpVar x'') k}) body as
...| TpIota x'' T₁ T₂ , as , [] =
  let Γ' = add-params-to-ctxt as Γ
      tₒ = foldl (λ where
            (Param me x'' (Tkt T)) body →
              (if me then AppEr body else App body) $
                mk-ctr-fmap-η? mk-ctr-fmap-η+ Γ' xₒ (Var x'') T
            (Param me x'' (Tkk k)) body →
              AppTp body $ mk-ctr-fmapₖ-η? mk-ctr-fmapₖ-η+ Γ' xₒ (TpVar x'') k
           ) body as
      t₁ = mk-ctr-fmap-η? mk-ctr-fmap-η- Γ' xₒ (IotaProj tₒ ι1) T₁
      t₂ = mk-ctr-fmap-η? mk-ctr-fmap-η- Γ' xₒ (IotaProj tₒ ι2) ([ Γ' - t₁ / x'' ] T₂) in
  params-to-lams (substh-params Γ (renamectxt-single Aₓ Bₓ) empty-trie as) $
  IotaPair t₁ t₂ x'' (rename-var (ctxt-var-decl x'' Γ') Aₓ Bₓ T₂)
--    (subst Γ' (mk-ctr-fmap-η? mk-ctr-fmap-η- Γ' xₒ (Var x'') T₁) x'' T₂)
...| Tₕ , as , rs = body

mk-ctr-fmapₖ-η+ Γ xₒ @ (Aₓ , Bₓ , cₓ , castₓ) body k =
  let is = kind-to-indices Γ k in
  indices-to-tplams is $
  let Γ' = add-indices-to-ctxt is Γ in
  foldl
    (λ {(Index x'' (Tkt T)) → flip TpAppTm $ mk-ctr-fmap-η?  mk-ctr-fmap-η-  Γ' xₒ (Var x'') T;
        (Index x'' (Tkk k)) → flip TpAppTp $ mk-ctr-fmapₖ-η? mk-ctr-fmapₖ-η- Γ' xₒ (TpVar x'') k})
    body is

mk-ctr-fmapₖ-η- Γ xₒ @ (Aₓ , Bₓ , cₓ , castₓ) body k with kind-to-indices Γ k
...| is =
  indices-to-tplams is $
  let Γ' = add-indices-to-ctxt is Γ in
  foldl (λ {(Index x'' (Tkt T)) → flip TpAppTm $ mk-ctr-fmap-η? mk-ctr-fmap-η+ Γ' xₒ (Var x'') T;
            (Index x'' (Tkk k)) → flip TpApp $ Ttp $ mk-ctr-fmapₖ-η? mk-ctr-fmapₖ-η+ Γ' xₒ (TpVar x'') k})
    body is


mk-def : term → term
mk-def t = Phi (Beta t id-term) t (erase t)

top-type : type
top-type = TpEq id-term id-term

-- Index telescoping parameter
pattern IdxTele Iₓ = Param tt Iₓ (Tkk KdStar) :: []
pattern EncArgIdx I = ArgTp I
pattern EncArgCast Cast = ArgTp Cast
pattern EncArgCastIn cast-in = Arg cast-in
pattern EncArgCastOut cast-out = Arg cast-out
pattern EncArgCastIs cast-is = Arg cast-is
pattern EncArgFunctor Functor = ArgTp Functor
pattern EncArgFunctorIn functor-in = Arg functor-in
pattern EncArgFunctorOut functor-out = Arg functor-out
pattern EncArgFix Fix = ArgTp Fix
pattern EncArgFixIn fix-in = Arg fix-in
pattern EncArgFixOut fix-out = Arg fix-out
pattern EncArgLambek1 lambek1 = Arg lambek1
pattern EncArgLambek2 lambek2 = Arg lambek2
pattern EncArgFixInd fix-ind = Arg fix-ind
pattern EncArgs I Cast cast-in cast-out cast-is Functor functor-in functor-out
                Fix fix-in fix-out lambek1 lambek2 fix-ind =
  EncArgIdx I ::
  EncArgCast Cast ::
  EncArgCastIn cast-in ::
  EncArgCastOut cast-out ::
  EncArgCastIs cast-is ::
  EncArgFunctor Functor ::
  EncArgFunctorIn functor-in ::
  EncArgFunctorOut functor-out ::
  EncArgFix Fix ::
  EncArgFixIn fix-in ::
  EncArgFixOut fix-out ::
  EncArgLambek1 lambek1 ::
  EncArgLambek2 lambek2 ::
  EncArgFixInd fix-ind :: []

pattern EncImp fp I Cast cast-in cast-out cast-is Functor functor-in functor-out
               Fix fix-in fix-out lambek1 lambek2 fix-ind =
  CmdImport (Import _ fp _ _ (EncArgs
      I Cast cast-in cast-out cast-is Functor functor-in functor-out
      Fix fix-in fix-out lambek1 lambek2 fix-ind))

encode-datatype : ctxt → encoding-defs → datatype → encoding-defs
encode-datatype Γ eds @ (mk-enc-defs ecs _
                               Cast cast-in cast-out cast-is
                               Functor functor-in functor-out
                               Fix fix-in fix-out
                               lambek1 lambek2 fix-ind)
                  (Data Dₓ' ps is cs) =
  record eds {gcs = [: TypeF-cmd ⌟ IndF-cmd ⌟ fmap-cmd ⌟
                       D-cmd ⌟ Is-cmd ⌟ is-cmd ⌟ to-cmd ⌟
                       map ctr-cmd cs~ :] }
  where

  Γₚₛ = ctxt-get-current-params Γ
  psₑ = params-set-erased Erased ps
  psₜ = Γₚₛ ++ psₑ

  app-ps = params-to-apps psₜ ∘ Var
  tpapp-ps = params-to-tpapps psₜ ∘ TpVar

  mn = ctxt-get-current-modname Γ

  Dₓ = mn # Dₓ'
  cs~ = map-snd (subst Γ (params-to-tpapps ps (TpVar Dₓ)) Dₓ) <$> cs
  cs' = map-snd (rename-var Γ Dₓ Dₓ') <$> cs

  topᵢ = indices-to-kind is $ KdAbs ignored-var (Tkt top-type) KdStar

  mk-ctr-eterm : params → ctr → term
  mk-ctr-eterm ps (Ctr x _) =
    let xs = erase-params ps in
    Beta id-term $ foldr
      mlam
      (foldl (flip App ∘ Var) (Var x) xs)
      (map fst cs)
  
  mk-ctr-etype : ctxt → ctr → var → type
  mk-ctr-etype Γ (Ctr x T) X with decompose-ctr-type (ctxt-var-decl X Γ) T
  ...| Tₕ , as , rs =
    params-to-alls as $
    let rs' = if length rs =ℕ length psₜ + length is then drop (length psₜ) rs else rs in
    TpAppTm (recompose-tpapps rs' $ TpVar X) $ mk-ctr-eterm as (Ctr x T)
  

  {-
  for the datatype
    data Dₓ (p₁ : P₁) (p₂ : P₂)... : Π i₁ : I₁. Π i₂ : I₂. ... ★ =
      | c₁ : Π/∀ a₁ : A₁. Π/∀ a₂ : A₂. ... (Dₓ r₁ r₂...)
      | c₂ : ... .
  produce the functor type
  ∀ X : Π i₁ : I₁. Π i₂ : I₂. ... Π _ : Top. ★.
    (Π/∀ a₁ : A₁. Π/∀ a₂ : A₂. ... (X r₁ r₂ β<λ x. x>{λ c₁. λ c₂. ... |c₁ a₁ a₂...|})) →
     ... →
    X i₁ i₂... ιₓ
  -}
  mk-ftype2 : ctxt → (ιₓ : var) → ctrs → type
  mk-ftype2 Γ ιₓ cs =
    rename "X" from Γ for λ X →
    TpAbs tt X (Tkk topᵢ) $
    foldr
      (λ c → TpAbs ff ignored-var $ Tkt $ mk-ctr-etype Γ c X)
      (TpAppTm (indices-to-tpapps is $ TpVar X) $ Var ιₓ)
      cs

  mk-ctr-fterm : ctr → ctrs → (as : params) → term
  mk-ctr-fterm (Ctr x' T) cs as =
    let Γ' = add-params-to-ctxt as Γ in
    rename "X" from Γ' for λ Xₓ →
    rename "x" from Γ' for λ xₓ →
    let tkₓ = just (Tkk (indices-to-kind is (KdAbs ignored-var (Tkt top-type) KdStar)))
        fₜ = λ x T → Lam ff x (just (Tkt (mk-ctr-etype Γ' (Ctr x T) Xₓ)))
        t = Lam tt Xₓ tkₓ (foldr (uncurry fₜ) (params-to-apps as (Var x')) cs) in
    IotaPair (Beta id-term (erase t)) t xₓ (mk-ftype2 Γ' xₓ cs)

  mk-ctr-ftype : ctxt → ctr → ctrs → var → type
  mk-ctr-ftype Γ (Ctr x T) cs X with decompose-ctr-type (ctxt-var-decl X Γ) T
  ...| Tₕ , as , rs =
    params-to-alls as $
    TpAppTm (recompose-tpapps rs $ TpVar X) $ mk-ctr-fterm (Ctr x T) cs as


  Is/D = tpapp-ps (data-Is/ Dₓ)
  is/D = app-ps (data-is/ Dₓ)
  to/D = app-ps (data-to/ Dₓ)
  TypeF/D = tpapp-ps (data-TypeF/ Dₓ)
  IndF/D = tpapp-ps (data-IndF/ Dₓ)
  fmap/D = app-ps (data-fmap/ Dₓ)
  D = tpapp-ps Dₓ
  kᵢ = indices-to-kind is KdStar
  tkᵢ = Tkk kᵢ
  jtkᵢ = just tkᵢ

  decl-Γ : ctxt → 𝕃 var → ctxt
  decl-Γ = foldr ctxt-var-decl


  {-
  λ p₁ : P₁. λ p₂ : P₂. ...
    λ Dₓ : Π i₁ : I₁. Π i₂ : I₂. ... ★.
      λ i₁ : I₁. λ i₂ : I₂. ...
        ι ιₓ : Top. mk-ftype2 (ctxt-var-decl ιₓ Γ') ιₓ cs.
    -}
  TypeF-cmd = CmdDefType (data-TypeF/ Dₓ')
                (params-to-kind psₜ $ KdAbs ignored-var tkᵢ kᵢ) $
    let Γ' = add-indices-to-ctxt is $ add-params-to-ctxt ps Γ in
    rename "x" from Γ' for λ ιₓ →
    params-to-tplams ps $
      TpLam Dₓ' (Tkk $ indices-to-kind is KdStar) $
        indices-to-tplams is $
          TpIota ιₓ top-type $ mk-ftype2 (ctxt-var-decl ιₓ Γ') ιₓ cs'
  
  fmap-cmd = CmdDefTerm (data-fmap/ Dₓ') $
    let Γ = add-params-to-ctxt psₜ Γ in
    rename "A" from Γ for λ Aₓ →
    rename "B" from Γ for λ Bₓ →
    rename "c" from Γ for λ cₓ →
    rename "x" from Γ for λ xₓ →
    rename "X" from Γ for λ Xₓ →
    params-to-lams psₜ $
    let cs-a = map-snd (rename-var Γ Dₓ Aₓ) <$> cs
        cs-b = map-snd (rename-var Γ Dₓ Bₓ) <$> cs
        Γ-η = ctxt-open-encoding-defs (decl-Γ Γ [: Aₓ ⌟ Bₓ ⌟ cₓ :]) in
    AppEr (AppTp functor-in TypeF/D) $
    Lam tt Aₓ jtkᵢ $
    Lam tt Bₓ jtkᵢ $
    Lam tt cₓ (just (Tkt (TpAppTp (TpAppTp Cast (TpVar Aₓ)) (TpVar Bₓ)))) $
    AppEr (AppEr (AppTp (AppTp cast-in (TpAppTp TypeF/D (TpVar Aₓ)))
                                       (TpAppTp TypeF/D (TpVar Bₓ)))
      (indices-to-lams is $
       Lam ff xₓ (just (Tkt (indices-to-tpapps is (TpAppTp TypeF/D (TpVar Aₓ))))) $
       IotaPair (IotaProj (Var xₓ) ι1)
         (Lam tt Xₓ (just (Tkk topᵢ)) $
          flip (foldr $ uncurry λ x T → Lam ff x (just (Tkt
                 (mk-ctr-etype (decl-Γ Γ [: Aₓ ⌟ Bₓ ⌟ cₓ ⌟ xₓ ⌟ Xₓ :]) (x , T) Xₓ)))) cs-b $
          foldl
            (flip App ∘ uncurry
              (λ bodyₓ T → mk-ctr-fmap-η+ Γ-η
                (Aₓ , Bₓ , cₓ , cast-out)
                (Var bodyₓ)
                (hnf-ctr Γ-η Aₓ T)))
            (AppTp (IotaProj (Var xₓ) ι2) (TpVar Xₓ)) cs-a)
         xₓ (mk-ftype2 (decl-Γ Γ [: Aₓ ⌟ Bₓ ⌟ cₓ :]) xₓ cs-b)))
      (Beta id-term id-term)

  IndF-cmd = CmdDefTerm (data-IndF/ Dₓ') $
    params-to-lams psₜ $
    Lam tt Dₓ' jtkᵢ $
    indices-to-lams is $
    rename "x" from Γ for λ xₓ →
    rename "y" from Γ for λ yₓ →
    rename "e" from Γ for λ eₓ →
    rename "X" from Γ for λ Xₓ →
    let T = indices-to-tpapps is (TpAppTp TypeF/D (TpVar Dₓ')) in
    Lam ff xₓ (just $ Tkt T) $
    Lam tt Xₓ (just $ Tkk $ indices-to-kind is $ KdAbs ignored-var (Tkt T) KdStar) $
    flip (foldr λ c → Lam ff (fst c) (just (Tkt (mk-ctr-ftype Γ c cs' Xₓ)))) cs' $
    flip AppEr (Beta (Var xₓ) id-term) $
    flip AppEr (Var xₓ) $
    let Γ' = decl-Γ Γ [: xₓ ⌟ yₓ ⌟ eₓ ⌟ Xₓ :] in
    flip (foldl $ uncurry λ x' T' →
      elim decompose-arrows Γ' T' for λ as Tₕ →
      flip App $
      params-to-lams as $
      Lam tt yₓ (just (Tkt T)) $
      Lam tt eₓ (just (Tkt (TpEq (Var yₓ) (mk-ctr-eterm as (Ctr x' T'))))) $
      params-to-apps as $
      Var x') cs' $
    AppTp (IotaProj (Var xₓ) ι2) $
    indices-to-tplams is $
    TpLam xₓ (Tkt top-type) $
    TpAbs tt yₓ (Tkt T) $
    TpAbs tt eₓ (Tkt $ TpEq (Var yₓ) (Var xₓ)) $
    TpAppTm (indices-to-tpapps is $ TpVar Xₓ) $
    Phi (Var eₓ) (Var yₓ) (Var xₓ)

  D-cmd = CmdDefType Dₓ' (params-to-kind ps kᵢ) $
    params-to-tplams psₜ $
    TpAppTm (TpApp Fix (Ttp TypeF/D)) fmap/D

  is-projn : type → type → term → type
  is-projn Tₘ Tₙ t =
    rename "i" from add-params-to-ctxt ps Γ for λ iₓ →
    TpIota iₓ
      (indices-to-alls is
        (TpAbs ff ignored-var (Tkt (indices-to-tpapps is Tₘ))
          (indices-to-tpapps is Tₙ)))
      (TpEq (Var iₓ) t)

  is-proj1 = λ T → is-projn T D id-term
  is-proj2 = λ T → is-projn T (TpAppTp TypeF/D D) fix-out

  is-proj' : var → term → term
  is-proj' Xₓ mu =
    let t = App (AppTp mu (is-proj1 (TpVar Xₓ)))
              (Lam ff "c" (just (Tkt (is-proj1 (TpVar Xₓ))))
                (Lam ff "o" (just (Tkt (is-proj2 (TpVar Xₓ))))
                  (Var "c"))) in
    Phi (IotaProj t ι2) (IotaProj t ι1) id-term

  Is-cmd = CmdDefType (data-Is/ Dₓ') (params-to-kind ps $ KdAbs ignored-var tkᵢ KdStar) $
    params-to-tplams (Γₚₛ ++ ps) $
    rename "X" from add-params-to-ctxt ps Γ for λ Xₓ →
    rename "Y" from add-params-to-ctxt ps Γ for λ Yₓ →
    TpLam Xₓ tkᵢ $
    TpAbs tt Yₓ (Tkk KdStar) $
    TpAbs ff ignored-var
      (Tkt (TpAbs ff ignored-var (Tkt (is-proj1 (TpVar Xₓ))) $
            TpAbs ff ignored-var (Tkt (is-proj2 (TpVar Xₓ))) $
            TpVar Yₓ))
      (TpVar Yₓ)

  is-cmd = CmdDefTerm (data-is/ Dₓ') $
    params-to-lams (Γₚₛ ++ ps) $
    rename "Y" from add-params-to-ctxt ps Γ for λ Yₓ →
    rename "f" from add-params-to-ctxt ps Γ for λ fₓ →
    let pair = λ t → IotaPair t (Beta (erase t) (erase t)) "x" (TpEq (Var "x") (erase t)) in
    Lam tt Yₓ (just (Tkk KdStar)) $
    Lam ff fₓ (just (Tkt (TpAbs ff ignored-var (Tkt (is-proj1 D)) $
                          TpAbs ff ignored-var (Tkt (is-proj2 D)) $
                          TpVar Yₓ))) $
    App (App (Var fₓ) (pair (indices-to-lams is (Lam ff "x" (just (Tkt (indices-to-tpapps is D))) (Var "x")))))
        (pair (AppEr (AppTp fix-out TypeF/D) fmap/D))

  to-cmd = CmdDefTerm (data-to/ Dₓ') $
    rename "Y" from add-params-to-ctxt ps Γ for λ Yₓ →
    rename "mu" from add-params-to-ctxt ps Γ for λ muₓ →
    params-to-lams (Γₚₛ ++ ps) $
    Lam tt Yₓ jtkᵢ $
    Lam tt muₓ (just (Tkt (TpApp Is/D (Ttp (TpVar Yₓ))))) $
    is-proj' Yₓ (Var muₓ)

  ctr-cmd : ctr → cmd
  ctr-cmd (Ctr x' T) with subst Γ D Dₓ' T
  ...| T' with decompose-ctr-type Γ T'
  ...| Tₕ , as , rs = CmdDefTerm x' $
    let Γ' = add-params-to-ctxt as Γ in
    params-to-lams (Γₚₛ ++ ps) $
    params-to-lams as $
    App (recompose-apps (tmtps-to-args tt $ drop (length ps) rs) $
          AppEr (AppTp fix-in TypeF/D) fmap/D) $
    mk-ctr-fterm (Ctr x' T) cs~ as


init-encoding : ctxt → file → datatype → string ⊎ encoding-defs
init-encoding Γ (Module mn (IdxTele Iₓ) mcs) d @ (Data Dₓ ps is cs) =
  case reverse (reindex-file Γ Dₓ Iₓ mn is ps mcs) of λ where
    (EncImp fp Iₓ'
        Cast cast-in cast-out cast-is
        Functor functor-in functor-out
        Fix fix-in fix-out
        lambek1 lambek2 fix-ind :: mcs) →
      err⊎-guard (~ conv-type Γ Iₓ' (TpVar Iₓ))
        "Index telescoping argument to last import differs from the parameter" >>
      return (encode-datatype Γ (mk-enc-defs (reverse mcs) []
                          Cast cast-in cast-out cast-is
                          Functor functor-in functor-out
                          Fix fix-in fix-out
                          lambek1 lambek2 fix-ind) d)
    (CmdImport (Import p? fn mn q? as) :: mcsᵣ) →
      inj₁ $ "Expected 14 import args, but got" ^ rope-to-string (strRun Γ (args-to-string as))
    mcsᵣ →
      inj₁ "Datatype encodings must end with import ~/.cedille/Template.ced"
  where open import to-string options
init-encoding Γ (Module mn mps mcs) (Data Dₓ ps is cs) =
  inj₁ $ "Datatype encodings must have a single module parameter of kind star, " ^
         "for index telescoping"


{-


{- Datatypes -}


mendler-elab-mu-pure : ctxt → ctxt-datatype-info → encoded-datatype-names → maybe var → term → cases → maybe term
mendler-elab-mu-pure Γ (mk-data-info X is/X? asₚ asᵢ ps kᵢ k cs fcs) (mk-encoded-datatype-names _ _ _ _ _ _ _ _ fixpoint-inₓ fixpoint-outₓ fixpoint-indₓ fixpoint-lambekₓ) x? t ms =
  
  let ps-tm = id --λ t → foldr (const $ flip App id-term) t $ erase-params ps
      fix-ind = Var fixpoint-indₓ -- hnf Γ unfold-all (ps-tm $ Var fixpoint-indₓ) tt
      fix-out = Var fixpoint-outₓ -- hnf Γ unfold-all (ps-tm $ Var fixpoint-outₓ) tt
      μ-tm = λ x msf → App (App fix-ind t) $ mlam x $ rename "x" from ctxt-var-decl x Γ for λ fₓ → mlam fₓ $ msf $ Var fₓ -- App fix-out $ Var fₓ
      μ'-tm = λ msf → msf $ App fix-out t
      set-nth = λ l n a → foldr{B = maybe ℕ → 𝕃 (maybe term)}
        (λ {a' t nothing → a' :: t nothing;
            a' t (just zero) → a :: t nothing;
            a' t (just (suc n)) → a' :: t (just n)})
        (λ _ → []) l (just n) in
  -- Note: removing the implicit arguments below hangs Agda's type-checker!
  foldl{B = 𝕃 (maybe term) → maybe (term → term)}
    (λ c msf l → case_of_{B = maybe (term → term)} c
       λ {(Case _ x cas t) → env-lookup Γ ("//" ^ x) >>=
         λ {(ctr-def ps? _ n i a , _ , _) →
           msf (set-nth l i (just $ caseArgs-to-lams cas t)); _ → nothing}})
    (-- Note: lambda-expanding this "foldr..." also hangs Agda...?
     foldr (λ t? msf → msf >>= λ msf → t? >>= λ t →
              just λ t' → (msf (App t' t))) (just λ t → t))
    ms (map (λ _ → nothing) ms) >>= (just ∘ maybe-else' x? μ'-tm μ-tm)
-}


mendler-elab-mu : ctxt → ctxt-datatype-info → var → maybe term ⊎ var → term → type → cases → term
mendler-elab-mu Γ (mk-data-info X is/X?' asₚ asᵢ ps kᵢ k cs (mk-enc-defs ecs gcs Cast cast-in cast-out cast-is Functor functor-in functor-out Fix fix-in fix-out lambek1 lambek2 fix-ind) (mk-encd-defs Is/Dₓ is/Dₓ to/Dₓ TypeF/Dₓ indF/Dₓ fmap/Dₓ) fcs) Xₒ x? t Tₘ ms =
  let is = kind-to-indices Γ k
      Γᵢₛ = add-indices-to-ctxt is $ add-params-to-ctxt ps Γ
      is-as : indices → args
      is-as = λ is → map (λ {(Index x atk) → either-else' atk (λ _ → ArgEr (Var x)) (λ _ → ArgTp (TpVar x))}) is
      is/X? = is/X?' maybe-or either-else' x? id λ _ → nothing
      fmap/D = recompose-apps asₚ (Var fmap/Dₓ)
      TypeF/D = recompose-tpapps (args-to-tmtps asₚ) (TpVar TypeF/Dₓ)
      Is/D = recompose-tpapps (args-to-tmtps asₚ) (TpVar Is/Dₓ)
      is/D = recompose-apps (args-set-erased tt asₚ) (Var is/Dₓ)
      to/D = recompose-apps (args-set-erased tt asₚ) (Var to/Dₓ)
      indF/D = recompose-apps (args-set-erased tt asₚ) (Var indF/Dₓ)
      Xₜₚ = recompose-tpapps (args-to-tmtps asₚ) (TpVar X)
      toₓ = rename "to" from Γᵢₛ for id
      outₓ = rename "out" from Γᵢₛ for id
      to-tp = λ R → TpAppTp (TpAppTp Cast R) Xₜₚ
      out-tp = λ R → TpIota outₓ (indices-to-alls is (TpAbs ff ignored-var (Tkt (indices-to-tpapps is R)) (indices-to-tpapps is (TpAppTp TypeF/D R)))) (TpEq (Var outₓ) fix-out)
      ms' : trie term
      ms' = foldr (λ c σ → case c of λ {(Case x cas t asₜₚ) →
                let Γ' = add-caseArgs-to-ctxt cas Γᵢₛ in
                trie-insert σ x $
                rename "y" from Γ' for λ yₓ →
                rename "e" from Γ' for λ eₓ →
                rename "x" from Γ' for λ xₓ →
                case-args-to-lams cas $
                Lam tt yₓ (just (Tkt Xₜₚ)) $
                Lam tt eₓ (just (Tkt (TpEq (App fix-in (foldr (uncurry λ x T → Lam ff (snd (split-var x)) nothing) (foldl (λ ca t → case ca of λ {(CaseArg CaseArgTm x) → App t (Var (snd (split-var x))); _ → t}) (Var (snd (split-var x))) cas) cs)) (Var yₓ)))) $
                Rho (Sigma (Var eₓ)) xₓ (TpAppTm (recompose-tpapps asₜₚ Tₘ) (Var xₓ)) t})
              empty-trie ms
      in-fix = λ is/X? T asᵢ t → either-else' x?
        (λ e → maybe-else' (is/X? maybe-or e) t λ is/X → App (AppEr (recompose-apps asᵢ (AppTp (AppTp cast-out (TpVar Xₒ)) Xₜₚ)) (App is/X (Lam ff "to" (just (Tkt (to-tp (TpVar Xₒ)))) $ Lam ff "out" (just (Tkt (out-tp (TpVar Xₒ)))) $ Var "to"))) t)
        (λ x → App (recompose-apps asᵢ (AppEr (AppTp fix-in TypeF/D) fmap/D)) (maybe-else' is/X? t λ is/X →
        App (recompose-apps asᵢ (AppEr cast-out (AppEr (AppTp (AppTp fmap/D T) Xₜₚ) ({-open` data-Muₓ - -} (App is/X (Lam ff "to" (just (Tkt (to-tp (TpVar Xₒ)))) $ Lam ff "out" (just (Tkt (out-tp (TpVar Xₒ)))) $ Var "to")))))) t))
      app-lambek = λ is/X? t T asᵢ body → AppEr (AppEr body (in-fix is/X? T asᵢ t))
        (App (recompose-apps asᵢ (AppEr (AppTp lambek1 TypeF/D) fmap/D)) (in-fix is/X? T asᵢ t)) in
  rename "x" from Γᵢₛ for λ xₓ →
  rename "y" from Γᵢₛ for λ yₓ →
  rename "y'" from ctxt-var-decl yₓ Γᵢₛ for λ y'ₓ →
  rename "z" from Γᵢₛ for λ zₓ →
  rename "e" from Γᵢₛ for λ eₓ →
  rename "X" from Γᵢₛ for λ Xₓ →
  maybe-else (Var "1") id $
  foldl {B = maybe (term → term)} -- Agda hangs without this implicit argument...?
    (uncurry λ x Tₓ rec → rec >>= λ rec → trie-lookup ms' x >>= λ t →
      just λ tₕ → App (rec tₕ) t) (just λ t → t) cs >>= λ msf →
  maybe-else (just $ Var "2") just $
  just $ flip (either-else' x?)
    (λ xₒ → rename xₒ from Γᵢₛ for λ x →
    let Rₓₒ = mu-Type/ x
        isRₓₒ = mu-isType/ x in
    rename Rₓₒ from Γᵢₛ for λ Rₓ →
    rename isRₓₒ from Γᵢₛ for λ isRₓ →
    let fcₜ = AppEr (AppTp (AppTp cast-out (TpAppTp TypeF/D (TpVar Rₓ))) (TpAppTp TypeF/D Xₜₚ)) (AppEr (AppTp (AppTp fmap/D (TpVar Rₓ)) Xₜₚ) (Var toₓ))
        subst-msf = subst-renamectxt Γᵢₛ
          (renamectxt-insert* empty-renamectxt ((xₒ , x) :: (isRₓₒ , isRₓ) :: (Rₓₒ , Rₓ) :: (toₓ , toₓ) :: (outₓ , outₓ) :: (xₓ , xₓ) :: (yₓ , yₓ) :: (y'ₓ , y'ₓ) :: [])) ∘ msf in
    {-open` X - -} (App (AppTp (App (recompose-apps (tmtps-to-args tt asᵢ) (AppEr (AppTp fix-ind TypeF/D) fmap/D)) t) Tₘ)
      (Lam tt Rₓ (just (Tkk k)) $
       Lam tt toₓ (just (Tkt (to-tp (TpVar Rₓ)))) $
       Lam tt outₓ (just (Tkt (out-tp (TpVar Rₓ)))) $
       Lam ff x (just (Tkt (indices-to-alls is (TpAbs ff xₓ (Tkt (TpVar Rₓ)) (TpAppTm (indices-to-tpapps is Tₘ) (App (AppEr (AppTp (AppTp cast-out (TpVar Rₓ)) Xₜₚ) (Var toₓ)) (Var xₓ))))))) $
       indices-to-lams is $
       Lam ff yₓ (just (Tkt (indices-to-tpapps is (TpAppTp TypeF/D (TpVar Rₓ))))) $
       LetTm tt isRₓ (just $ TpAppTp Is/D (TpVar Rₓ)) 
           (Lam tt Xₓ (just (Tkk KdStar)) $
            Lam ff xₓ (just (Tkt (TpAbs ff ignored-var (Tkt (to-tp (TpVar Rₓ)))
                                   (TpAbs ff ignored-var (Tkt (out-tp (TpVar Rₓ)))
                                     (TpVar Xₓ))))) $
            App (App (Var xₓ) (Var toₓ)) (Var outₓ))
       (app-lambek (just $ Var isRₓ) (Var yₓ) (TpVar Rₓ) (is-as is) $ subst-msf
         (AppTp (Phi (Beta (Var yₓ) id-term) (App (indices-to-apps is (AppTp indF/D (TpVar Rₓ))) (Var yₓ)) (Var yₓ))
           (indices-to-tplams is $
            TpLam yₓ (Tkt $ indices-to-tpapps is (TpAppTp TypeF/D (TpVar Rₓ))) $
            TpAbs tt y'ₓ (Tkt $ indices-to-tpapps is Xₜₚ) $
            TpAbs tt eₓ (Tkt $ TpEq (App fix-in (Var yₓ)) (Var y'ₓ)) $
             TpAppTm (indices-to-tpapps is Tₘ) (Phi (Var eₓ)
               (App (indices-to-apps is (AppEr (AppTp fix-in TypeF/D) fmap/D))
                    (App (indices-to-apps is fcₜ) (Var yₓ)))
               (Var y'ₓ))))))))
    (λ _ → app-lambek is/X? t (recompose-tpapps (args-to-tmtps asₚ) (TpVar Xₒ))
             (tmtps-to-args tt asᵢ) (msf
      (let Tₛ = maybe-else' is/X? Xₜₚ λ _ → TpVar Xₒ
           fcₜ = maybe-else' is/X? id λ is/X → App $ indices-to-apps is $
             AppEr (AppTp (AppTp cast-out (TpAppTp TypeF/D Tₛ)) (TpAppTp TypeF/D Xₜₚ))
               (AppEr (AppTp (AppTp (AppEr (AppTp functor-out TypeF/D) fmap/D) Tₛ) Xₜₚ) (App is/X (Lam ff "to" (just (Tkt (to-tp Tₛ))) $ Lam ff "out" (just (Tkt (out-tp Tₛ))) $ Var "to")))
           out = maybe-else' is/X? (AppEr (AppTp fix-out TypeF/D) fmap/D) λ is/X →
             let i = App (AppTp is/X (TpIota xₓ (indices-to-alls is (TpAbs ff ignored-var (Tkt (indices-to-tpapps is Tₛ)) (indices-to-tpapps is (TpAppTp TypeF/D Tₛ)))) (TpEq (Var xₓ) fix-out))) (Lam ff "to" (just (Tkt (to-tp Tₛ))) $ Lam ff "out" (just (Tkt (out-tp Tₛ))) $ Var "out") in
             Phi (IotaProj i ι2) (IotaProj i ι1) fix-out in
      AppTp (App (recompose-apps (tmtps-to-args tt asᵢ) (AppTp indF/D Tₛ)) (App (recompose-apps (tmtps-to-args tt asᵢ) out) t))
        (indices-to-tplams is $ TpLam yₓ (Tkt $ indices-to-tpapps is (TpAppTp TypeF/D Tₛ)) $
           TpAbs tt y'ₓ (Tkt $ indices-to-tpapps is Xₜₚ) $
           TpAbs tt eₓ (Tkt (TpEq (App fix-in (Var yₓ)) (Var y'ₓ))) $
           TpAppTm (indices-to-tpapps is Tₘ) (Phi (Var eₓ)
             (App (indices-to-apps is (AppEr (AppTp fix-in TypeF/D) fmap/D)) (fcₜ (Var yₓ))) (Var y'ₓ))))))


{- ################################ IO ###################################### -}

open import to-string (record options {during-elaboration = tt; show-qualified-vars = ff; erase-types = ff; pretty-print = tt})

{-# TERMINATING #-}
cmds-to-string : (newline-before-after : 𝔹) → params → cmds → strM
cmd-to-string : params → cmd → strM
cmd-to-string ps (CmdDefTerm x t) = strBreak 2
  0 [ strVar x >>str strAdd " =" ]
  2 [ to-stringh (lam-expand-term ps t) >>str strAdd "." ]
cmd-to-string ps (CmdDefType x k T) = strBreak 3
  0 [ strVar x >>str strAdd " :" ]
  (3 + string-length x) [ to-stringh (abs-expand-kind ps k) >>str strAdd " =" ]
  2 [ to-stringh (lam-expand-type ps T)  >>str strAdd "." ]
cmd-to-string ps (CmdDefKind x psₖ k) = strBreak 2
  0 [ strVar x ]
  2 [ params-to-string'' (ps ++ psₖ) (to-stringh k) >>str strAdd "." ]
cmd-to-string ps (CmdDefData eds x psₓ k cs) =
  cmds-to-string ff ps (encoding-defs.ecs eds) >>str
  strList 2
    (strBreak 2
      0 [ strAdd "data " >>str strVar x ]
      (5 + string-length x) [ params-to-string'' (ps ++ psₓ)
                                (strAdd ": " >>str to-stringh k) ] ::
     map (uncurry λ x T → strBreak 2
       0 [ strAdd "| " >>str strVar x >>str strAdd " :" ]
       (5 + string-length x) [ to-stringh T ]) cs) >>str strAdd "."
cmd-to-string ps (CmdImport (Import p? fp mn q? as)) =
  strAdd "import " >>str
  strAdd mn >>str
  maybe-else' q? strEmpty (λ x → strAdd " as " >>str strAdd x) >>str
  args-to-string as >>str
  strAdd "."

cmds-to-string b-a ps =
  let b-a-tt : cmd → strM → strM
      b-a-tt = λ c cs → strLine >>str strLine >>str cmd-to-string ps c >>str cs
      b-a-ff : cmd → strM → strM
      b-a-ff = λ c cs → cmd-to-string ps c >>str cs >>str strLine >>str strLine in
  foldr (if b-a then b-a-tt else b-a-ff) strEmpty

file-to-string : file → strM
file-to-string (Module mn ps cs) =
  strAdd "module " >>str
  strAdd mn >>str
  strAdd "." >>str
  cmds-to-string tt ps cs

record elab-info : Set where
  constructor mk-elab-info
  field
    τ : toplevel-state
    ρ : renamectxt
    φ : renamectxt × trie file

new-elab-info : toplevel-state → elab-info
new-elab-info ts = mk-elab-info ts empty-renamectxt (empty-renamectxt , empty-trie)

{-# TERMINATING #-}
elab-file : elab-info → filepath → elab-info × var
elab-cmds : elab-info → (modname : var) → cmds → elab-info × cmds
elab-cmds ei mn [] = ei , []
elab-cmds (mk-elab-info τ ρ φ) mn (CmdDefTerm x t :: csᵣ) =
  rename (mn # x) - x from ρ for λ x' ρ' →
  elim elab-cmds (mk-elab-info τ ρ' φ) mn csᵣ for λ ei csᵣ →
  ei , CmdDefTerm x' (subst-renamectxt (toplevel-state.Γ τ) ρ (choose-mu t)) :: csᵣ
elab-cmds (mk-elab-info τ ρ φ) mn (CmdDefType x k T :: csᵣ) =
  rename (mn # x) - x from ρ for λ x' ρ' →
  elim elab-cmds (mk-elab-info τ ρ' φ) mn csᵣ for λ ei csᵣ →
  ei , CmdDefType x' (subst-renamectxt (toplevel-state.Γ τ) ρ (choose-mu k))
                     (subst-renamectxt (toplevel-state.Γ τ) ρ (choose-mu T)) :: csᵣ
elab-cmds ei mn (CmdDefKind x ps k :: csᵣ) =
  elab-cmds ei mn csᵣ
elab-cmds ei mn (CmdDefData es x ps k cs :: csᵣ) =
  elim elab-cmds ei mn (encoding-defs.ecs es) for λ ei ecs →
  elim elab-cmds ei mn (encoding-defs.gcs es) for λ ei gcs →
  elim elab-cmds ei mn csᵣ for λ ei rcs →
  ei , ecs ++ gcs ++ rcs
elab-cmds ei mn (CmdImport (Import p? fp mn' q? as) :: csᵣ) =
  elim elab-file ei fp for λ ei mn'' →
  elim elab-cmds ei mn csᵣ for λ ei csᵣ →
  ei , CmdImport (Import Private fp mn'' nothing []) :: csᵣ

elab-file ei @ (mk-elab-info τ ρ φ) fp with trie-contains (snd φ) fp
...| tt = ei , renamectxt-rep (fst φ) fp
...| ff with get-include-elt-if τ fp >>= include-elt.ast~
...| nothing = ei , "error"
...| just (Module mn ps es) =
  let p = elab-cmds ei mn es
      (mk-elab-info τ ρ φ) = fst p
      es' = snd p in
  rename fp - mn from fst φ for λ mn' φ' →
  mk-elab-info τ ρ (φ' , trie-insert (snd φ) fp (Module mn' ps es')) , mn'

elab-write-all : elab-info → (to : filepath) → IO ⊤
elab-write-all (mk-elab-info τ ρ φ) to =
  let Γ = toplevel-state.Γ τ
      print = strRun Γ ∘ file-to-string in
  foldr'
    (createDirectoryIfMissing ff to)
    (uncurry λ fₒ fₛ io →
       let fₘ = renamectxt-rep (fst φ) fₒ
           fₙ = combineFileNames to (fₘ ^ ".cdle") in
       io >> writeRopeToFile fₙ (print fₛ))
    (trie-mappings (snd φ))

elab-all : toplevel-state → (from to : filepath) → IO ⊤
elab-all ts fm to =
  elab-write-all (fst (elab-file (new-elab-info ts) fm)) to >>
  putStrLn "0"

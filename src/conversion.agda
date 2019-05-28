module conversion where

open import lib

open import constants
open import cedille-types
open import ctxt
open import free-vars
open import rename
open import subst
open import syntax-util
open import general-util
open import type-util

record unfolding : Set where
  constructor unfold
  field
    unfold-all : 𝔹
    unfold-defs : 𝔹
    unfold-erase : 𝔹

unfold-all : unfolding
unfold-all = unfold tt tt tt

unfold-head : unfolding
unfold-head = unfold ff tt tt

unfold-head-elab : unfolding
unfold-head-elab = unfold ff tt ff

unfold-dampen : unfolding → unfolding
unfold-dampen (unfold tt d e) = unfold tt d e
unfold-dampen (unfold ff d e) = unfold ff ff e

conv-t : Set → Set
conv-t T = ctxt → T → T → 𝔹

{-# TERMINATING #-}

-- main entry point
-- does not assume erased
conv-term : conv-t term
conv-type : conv-t type 
conv-kind : conv-t kind

-- assume erased
conv-terme : conv-t term 
conv-argse : conv-t (𝕃 term) 
conv-typee : conv-t type
conv-kinde : conv-t kind

-- call hnf, then the conv-X-norm functions
conv-term' : conv-t term 
conv-type' : conv-t type 

hnf : ∀ {ed : exprd} → ctxt → (u : unfolding) → ⟦ ed ⟧ → ⟦ ed ⟧ 

-- assume head normalized inputs
conv-term-norm : conv-t term 
conv-type-norm : conv-t type
conv-kind-norm : conv-t kind


-- does not assume erased
conv-tpkd : conv-t tpkd
conv-tty* : conv-t (𝕃 tty)

-- assume erased
conv-tpkde : conv-t tpkd
conv-ttye* : conv-t (𝕃 tty)

conv-ctr-ps : ctxt → var → var → maybe (ℕ × ℕ)
conv-ctr-args : conv-t (var × args)
conv-ctr : conv-t var

conv-term Γ t t' = conv-terme Γ (erase t) (erase t')

conv-terme Γ t t' with decompose-apps t | decompose-apps t'
conv-terme Γ t t' | Var x , args | Var x' , args' = 
     ctxt-eq-rep Γ x x' && conv-argse Γ (erase-args args) (erase-args args')
  || conv-ctr-args Γ (x , args) (x' , args')
  || conv-term' Γ t t'
conv-terme Γ t t' | _ | _ = conv-term' Γ t t'

conv-argse Γ [] [] = tt
conv-argse Γ (a :: args) (a' :: args') = conv-terme Γ a a' && conv-argse Γ args args'
conv-argse Γ _ _ = ff

conv-type Γ t t' = conv-typee Γ (erase t) (erase t')

conv-typee Γ t t' with decompose-tpapps t | decompose-tpapps t'
conv-typee Γ t t' | TpVar x , args | TpVar x' , args' = 
     ctxt-eq-rep Γ x x' && conv-tty* Γ args args'
  || conv-type' Γ t t'
conv-typee Γ t t' | _ | _ = conv-type' Γ t t'

conv-kind Γ k k' = conv-kinde Γ (erase k) (erase k')
conv-kinde Γ k k' = conv-kind-norm Γ (hnf Γ unfold-head k) (hnf Γ unfold-head k')

conv-term' Γ t t' = conv-term-norm Γ (hnf Γ unfold-head t) (hnf Γ unfold-head t')
conv-type' Γ t t' = conv-type-norm Γ (hnf Γ unfold-head t) (hnf Γ unfold-head t')


hnf {TERM} Γ u (App t tt t') = hnf Γ u t
hnf {TERM} Γ u (AppTp t T) = hnf Γ u t
hnf {TERM} Γ u (Beta _ (just t)) = hnf Γ u t
hnf {TERM} Γ u (Delta T t) = hnf Γ u t
hnf {TERM} Γ u (Hole pi) = Hole pi
hnf {TERM} Γ u (IotaPair t₁ t₂ x Tₓ) = hnf Γ u t₁
hnf {TERM} Γ u (IotaProj t n) = hnf Γ u t
hnf {TERM} Γ u (Lam tt x T t) = hnf Γ u t
hnf {TERM} Γ u (LetTp x k T t) = hnf Γ u t
hnf {TERM} Γ u (Open _ x t) = hnf Γ u t
hnf {TERM} Γ u (Phi tₑ t₁ t₂) = hnf Γ u t₂
hnf {TERM} Γ u (Rho tₑ x Tₓ t) = hnf Γ u t
hnf {TERM} Γ u (Sigma t) = hnf Γ u t
hnf {TERM} Γ u (Beta _ nothing) = let x = fresh-var Γ "x" in Lam ff x nothing (Var x)
hnf {TERM} Γ u (App t ff t') with hnf Γ u t
...| Lam ff x nothing t'' = hnf Γ u ([ Γ - t' / x ] t'')
...| t'' = App t'' ff (hnf Γ (unfold-dampen u) t')
hnf {TERM} Γ u (Lam ff x T t) with hnf (ctxt-var-decl x Γ) u t
...| App t' ff (Var x') = if x' =string x then t' else Lam ff x nothing (App t' ff (Var x'))
...| t' = Lam ff x nothing t'
hnf {TERM} Γ u (LetTm me x T t t') = hnf Γ u ([ Γ - t / x ] t')
hnf {TERM} Γ u (Var x) with
   maybe-if (unfolding.unfold-defs u) ≫maybe ctxt-lookup-term-var-def Γ x
...| nothing = Var x
...| just t = hnf Γ (unfold-dampen u) t
hnf {TERM} Γ u (Mu μₒ tₒ _ t~ cs') =
  let t = hnf Γ u tₒ
      μ = either-else' μₒ (λ _ → inj₁ nothing) inj₂
      Γ' = either-else' μₒ (λ _ → Γ) (flip ctxt-var-decl Γ)
      cs = erase-cases cs'
      t-else = λ t → Mu μ t nothing t~ $ flip map cs λ where
                 (Case x cas t) → Case x cas (hnf
                   (foldr (λ {(CaseArg _ x) → ctxt-var-decl x}) Γ' cas) (unfold-dampen u) t)
      case-matches : var → args → case → maybe (term × case-args × args)
      case-matches = λ {cₓ as (Case cₓ' cas t) →
                          conv-ctr-ps Γ cₓ' cₓ ≫=maybe uncurry λ ps' ps →
                          maybe-if (length as =ℕ length cas + ps) ≫=maybe λ _ →
                          just (t , cas , drop ps as)}
      matching-case = λ cₓ as → foldr (_maybe-or_ ∘ case-matches cₓ as) nothing cs
      sub-mu = let x = fresh-var Γ "x" in , Lam ff x nothing (t-else (Var x))
      sub = either-else' μₒ (λ _ → id {A = term})
        (λ x → substs Γ (trie-insert (trie-single x sub-mu) (data-to/ x) (, id-term))) in
  maybe-else' (decompose-var-headed t ≫=maybe uncurry matching-case) (t-else t) λ where
    (tₓ , cas , as) → hnf Γ u (recompose-apps as (case-args-to-lams cas (sub tₓ)))

hnf{TYPE} Γ u (TpAbs me x tk tp) = TpAbs me x (hnf Γ (unfold-dampen u) -tk tk) (hnf (ctxt-var-decl x Γ) (unfold-dampen u) tp)
hnf{TYPE} Γ u (TpIota x tp₁ tp₂) = TpIota x (hnf Γ (unfold-dampen u) tp₁) (hnf (ctxt-var-decl x Γ) (unfold-dampen u) tp₂)
hnf{TYPE} Γ u (TpApp tp tp') with hnf Γ u tp
...| TpLam x _ tp'' = hnf Γ u ([ Γ - tp' / x ] tp'')
...| tp'' = TpApp tp'' (hnf Γ (unfold-dampen u) tp')
hnf{TYPE} Γ u (TpAppt tp tm) with hnf Γ u tp
...| TpLam x _ tp'' = hnf Γ u ([ Γ - tm / x ] tp'')
...| tp'' = TpAppt tp''
              (if unfolding.unfold-erase u then hnf Γ (unfold-dampen u) tm else tm)
hnf{TYPE} Γ u (TpEq tm₁ tm₂) = TpEq (hnf Γ (unfold-dampen u) tm₁) (hnf Γ (unfold-dampen u) tm₂)
hnf{TYPE} Γ u (TpHole pi) = TpHole pi
hnf{TYPE} Γ u (TpLam x tk tp) = TpLam x (hnf Γ (unfold-dampen u) -tk tk) (hnf (ctxt-var-decl x Γ) (unfold-dampen u) tp)
hnf{TYPE} Γ u (TpVar x) with
   maybe-if (unfolding.unfold-defs u) ≫maybe ctxt-lookup-type-var-def Γ x
...| nothing = TpVar x
...| just t = hnf Γ (unfold-dampen u) t

hnf{KIND} Γ u (KdAbs x tk kd) =
  KdAbs x (hnf Γ (unfold-dampen u) -tk tk) (hnf (ctxt-var-decl x Γ) u kd)
hnf{KIND} Γ u KdStar = KdStar

hanf : ctxt → (erase : 𝔹) → term → term
hanf Γ e t with erase-if e t
...| t' = maybe-else t' id
  (decompose-var-headed t' ≫=maybe uncurry λ x as →
   ctxt-lookup-term-var-def Γ x ≫=maybe λ t'' →
   just (recompose-apps as t''))

-- unfold across the term-type barrier
hnf-term-type : ctxt → (erase : 𝔹) → type → type
hnf-term-type Γ e (TpEq t₁ t₂) = TpEq (hanf Γ e t₁) (hanf Γ e t₂)
hnf-term-type Γ e (TpAppt tp t) = hnf Γ (record unfold-head {unfold-erase = e}) (TpAppt tp (hanf Γ e t))
hnf-term-type Γ e tp = hnf Γ unfold-head tp

conv-cases : conv-t cases
conv-cases Γ cs₁ cs₂ = isJust $ foldl (λ c₂ x → x ≫=maybe λ cs₁ → conv-cases' Γ cs₁ c₂) (just cs₁) cs₂ where
  conv-cases' : ctxt → cases → case → maybe cases
  conv-cases' Γ [] (Case x₂ as₂ t₂) = nothing
  conv-cases' Γ (c₁ @ (Case x₁ as₁ t₁) :: cs₁) c₂ @ (Case x₂ as₂ t₂) with conv-ctr Γ x₁ x₂
  ...| ff = conv-cases' Γ cs₁ c₂ ≫=maybe λ cs₁ → just (c₁ :: cs₁)
  ...| tt = maybe-if (length as₂ =ℕ length as₁ && conv-term Γ (expand-case c₁) (expand-case (Case x₂ as₂ t₂))) ≫maybe just cs₁

ctxt-term-udef : posinfo → defScope → opacity → var → term → ctxt → ctxt

conv-term-norm Γ (Var x) (Var x') = ctxt-eq-rep Γ x x' || conv-ctr Γ x x'
-- hnf implements erasure for terms, so we can ignore some subterms for App and Lam cases below
conv-term-norm Γ (App t1 ff t2) (App t1' ff t2') = conv-term-norm Γ t1 t1' && conv-term Γ t2 t2'
conv-term-norm Γ (Lam ff x _ t) (Lam ff x' _ t') = conv-term (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) t t'
conv-term-norm Γ (Hole _) _ = tt
conv-term-norm Γ _ (Hole _) = tt
conv-term-norm Γ (Mu (inj₂ x₁) t₁ _ _ cs₁) (Mu (inj₂ x₂) t₂ _ _ cs₂) =
  let Γ' = ctxt-rename x₁ x₂ $ ctxt-var-decl x₂ Γ in
  conv-term Γ t₁ t₂ && conv-cases Γ' cs₁ cs₂
conv-term-norm Γ (Mu (inj₁ _) t₁ _ _ cs₁) (Mu (inj₁ _) t₂ _ _ cs₂) = conv-term Γ t₁ t₂ && conv-cases Γ cs₁ cs₂
{- it can happen that a term is equal to a lambda abstraction in head-normal form,
   if that lambda-abstraction would eta-contract following some further beta-reductions.
   We implement this here by implicitly eta-expanding the variable and continuing
   the comparison.

   A simple example is 

       λ v . t ((λ a . a) v) ≃ t
 -}
conv-term-norm Γ (Lam ff x _ t) t' =
  let x' = fresh-var Γ x in
  conv-term (ctxt-rename x x' Γ) t (App t' ff (Var x'))
conv-term-norm Γ t' (Lam ff x _ t) =
  let x' = fresh-var Γ x in
  conv-term (ctxt-rename x x' Γ) (App t' ff (Var x')) t 
conv-term-norm Γ _ _ = ff

conv-type-norm Γ (TpVar x) (TpVar x') = ctxt-eq-rep Γ x x'
conv-type-norm Γ (TpApp t1 t2) (TpApp t1' t2') = conv-type-norm Γ t1 t1' && conv-type Γ t2 t2'
conv-type-norm Γ (TpAppt t1 t2) (TpAppt t1' t2') = conv-type-norm Γ t1 t1' && conv-term Γ t2 t2'
conv-type-norm Γ (TpAbs me x tk tp) (TpAbs me' x' tk' tp') = 
  me iff me' && conv-tpkd Γ tk tk' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
conv-type-norm Γ (TpIota x m tp) (TpIota x' m' tp') = 
  conv-type Γ m m' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
conv-type-norm Γ (TpEq t₁ t₂) (TpEq t₁' t₂') = conv-term Γ t₁ t₁' && conv-term Γ t₂ t₂'
conv-type-norm Γ (TpLam x tk tp) (TpLam x' tk' tp') =
  conv-tpkd Γ tk tk' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
conv-type-norm Γ _ _ = ff 

{- even though hnf turns Pi-kinds where the variable is not free in the body into arrow kinds,
   we still need to check off-cases, because normalizing the body of a kind could cause the
   bound variable to be erased (hence allowing it to match an arrow kind). -}
conv-kind-norm Γ (KdAbs x tk k) (KdAbs x' tk' k'') = 
    conv-tpkd Γ tk tk' && conv-kind (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) k k''
conv-kind-norm Γ KdStar KdStar = tt
conv-kind-norm Γ _ _ = ff

conv-tpkd Γ tk tk' = conv-tpkde Γ (erase -tk tk) (erase -tk tk')

conv-tpkde Γ (Tkk k) (Tkk k') = conv-kind Γ k k'
conv-tpkde Γ (Tkt t) (Tkt t') = conv-type Γ t t'
conv-tpkde Γ _ _ = ff

conv-tty* Γ [] [] = tt
conv-tty* Γ (tterm t :: args) (tterm t' :: args')
  = conv-term Γ (erase t) (erase t') && conv-tty* Γ args args'
conv-tty* Γ (ttype t :: args) (ttype t' :: args')
  = conv-type Γ (erase t) (erase t') && conv-tty* Γ args args'
conv-tty* Γ _ _ = ff

conv-ttye* Γ [] [] = tt
conv-ttye* Γ (tterm t :: args) (tterm t' :: args') = conv-term Γ t t' && conv-ttye* Γ args args'
conv-ttye* Γ (ttype t :: args) (ttype t' :: args') = conv-type Γ t t' && conv-ttye* Γ args args'
conv-ttye* Γ _ _ = ff

conv-ctr Γ x₁ x₂ = conv-ctr-args Γ (x₁ , []) (x₂ , [])

conv-ctr-ps Γ x₁ x₂ with env-lookup Γ x₁ | env-lookup Γ x₂
...| just (ctr-def ps₁ T₁ n₁ i₁ a₁ , _) | just (ctr-def ps₂ T₂ n₂ i₂ a₂ , _) =
  maybe-if (n₁ =ℕ n₂ && i₁ =ℕ i₂ && a₁ =ℕ a₂) ≫maybe
  just (length (erase-params ps₁) , length (erase-params ps₂))
...| _ | _ = nothing

conv-ctr-args Γ (x₁ , as₁) (x₂ , as₂) =
  maybe-else' (conv-ctr-ps Γ x₁ x₂) ff $ uncurry λ ps₁ ps₂ →
  let as₁ = erase-args as₁; as₂ = erase-args as₂ in
  ps₁ ∸ length as₁ =ℕ ps₂ ∸ length as₂ &&
  conv-argse Γ (drop ps₁ as₁) (drop ps₂ as₂)


{-# TERMINATING #-}
inconv : ctxt → term → term → 𝔹
inconv Γ t₁ t₂ = inconv-lams empty-renamectxt empty-renamectxt
                   (hnf Γ unfold-all t₁) (hnf Γ unfold-all t₂)
  where
  fresh : var → renamectxt → renamectxt → var
  fresh x ρ₁ ρ₂ = fresh-h (λ x → ctxt-binds-var Γ x || renamectxt-in-field ρ₁ x || renamectxt-in-field ρ₂ x) x

  make-subst : renamectxt → renamectxt → 𝕃 var → 𝕃 var → term → term → (renamectxt × renamectxt × term × term)
  make-subst ρ₁ ρ₂ [] [] t₁ t₂ = ρ₁ , ρ₂ , t₁ , t₂
  make-subst ρ₁ ρ₂ (x₁ :: xs₁) [] t₁ t₂ =
    let x = fresh x₁ ρ₁ ρ₂ in
    make-subst (renamectxt-insert ρ₁ x₁ x) (renamectxt-insert ρ₂ x x) xs₁ [] t₁ (mapp t₂ $ Var x)
  make-subst ρ₁ ρ₂ [] (x₂ :: xs₂) t₁ t₂ =
    let x = fresh x₂ ρ₁ ρ₂ in
    make-subst (renamectxt-insert ρ₁ x x) (renamectxt-insert ρ₂ x₂ x) [] xs₂ (mapp t₁ $ Var x) t₂
  make-subst ρ₁ ρ₂ (x₁ :: xs₁) (x₂ :: xs₂) t₁ t₂ =
    let x = fresh x₁ ρ₁ ρ₂ in
    make-subst (renamectxt-insert ρ₁ x₁ x) (renamectxt-insert ρ₂ x₂ x) xs₁ xs₂ t₁ t₂
  
  inconv-lams : renamectxt → renamectxt → term → term → 𝔹
  inconv-apps : renamectxt → renamectxt → var → var → args → args → 𝔹
  inconv-ctrs : renamectxt → renamectxt → var → var → args → args → 𝔹
  inconv-mu : renamectxt → renamectxt → maybe (var × var) → cases → cases → 𝔹
  inconv-args : renamectxt → renamectxt → args → args → 𝔹

  inconv-args ρ₁ ρ₂ a₁ a₂ =
    let a₁ = erase-args a₁; a₂ = erase-args a₂ in
    ~  length a₁ =ℕ length a₂
    || list-any (uncurry $ inconv-lams ρ₁ ρ₂) (zip a₁ a₂)
  
  inconv-lams ρ₁ ρ₂ t₁ t₂ =
    elim-pair (decompose-lams t₁) λ l₁ b₁ →
    elim-pair (decompose-lams t₂) λ l₂ b₂ →
    elim-pair (make-subst ρ₁ ρ₂ l₁ l₂ b₁ b₂) λ ρ₁ ρ₂b₁₂ →
    elim-pair ρ₂b₁₂ λ ρ₂ b₁₂ →
    elim-pair b₁₂ λ b₁ b₂ →
    case (decompose-apps b₁ , decompose-apps b₂) of uncurry λ where
      (Var x₁ , a₁) (Var x₂ , a₂) →
        inconv-apps ρ₁ ρ₂ x₁ x₂ a₁ a₂ || inconv-ctrs ρ₁ ρ₂ x₁ x₂ a₁ a₂
      (Mu (inj₂ x₁) t₁ _ _ ms₁ , a₁) (Mu (inj₂ x₂) t₂ _ _ ms₂ , a₂) →
        inconv-mu ρ₁ ρ₂ (just $ x₁ , x₂) ms₁ ms₂ ||
        inconv-lams ρ₁ ρ₂ t₁ t₂ || inconv-args ρ₁ ρ₂ a₁ a₂
      (Mu (inj₁ _) t₁ _ _ ms₁ , a₁) (Mu (inj₁ _) t₂ _ _ ms₂ , a₂) →
        inconv-mu ρ₁ ρ₂ nothing ms₁ ms₂ ||
        inconv-lams ρ₁ ρ₂ t₁ t₂ || inconv-args ρ₁ ρ₂ a₁ a₂
      _ _ → ff

  inconv-apps ρ₁ ρ₂ x₁ x₂ a₁ a₂ =
    maybe-else' (renamectxt-lookup ρ₁ x₁) ff λ x₁ →
    maybe-else' (renamectxt-lookup ρ₂ x₂) ff λ x₂ →
    ~ x₁ =string x₂
    || inconv-args ρ₁ ρ₂ a₁ a₂

  inconv-ctrs ρ₁ ρ₂ x₁ x₂ as₁ as₂ with env-lookup Γ x₁ | env-lookup Γ x₂
  ...| just (ctr-def ps₁ _ n₁ i₁ a₁ , _) | just (ctr-def ps₂ _ n₂ i₂ a₂ , _) =
    let ps₁ = erase-params ps₁; ps₂ = erase-params ps₂
        as₁ = erase-args   as₁; as₂ = erase-args   as₂ in
    length as₁ ≤ length ps₁ + a₁ && -- Could use of "≤" here conflict with η-equality?
    length as₂ ≤ length ps₂ + a₂ &&
    (~ n₁ =ℕ n₂ ||
    ~ i₁ =ℕ i₂ ||
    ~ a₁ =ℕ a₂ ||
    ~ length as₁ + length ps₂ =ℕ length as₂ + length ps₁ ||
    -- ^ as₁ ∸ ps₁ ≠ as₂ ∸ ps₂, + ps₁ + ps₂ to both sides ^
    list-any (uncurry $ inconv-lams ρ₁ ρ₂)
      (zip (drop (length ps₁) as₁) (drop (length ps₂) as₂)))
  ...| _ | _ = ff

  inconv-mu ρ₁ ρ₂ xs? ms₁ ms₂ =
    ~ length ms₁ =ℕ length ms₂ ||
    maybe-else ff id
      (foldr {B = maybe 𝔹} (λ c b? → b? ≫=maybe λ b → inconv-case c ≫=maybe λ b' → just (b || b')) (just ff) ms₁)
    where
    matching-case : case → maybe (term × ℕ × ℕ)
    matching-case (Case x _ _) = foldl (λ where
      (Case xₘ cas tₘ) m? → m? maybe-or
        (conv-ctr-ps Γ xₘ x ≫=maybe uncurry λ psₘ ps →
         just (case-args-to-lams cas tₘ , length cas , ps)))
      nothing ms₂

    inconv-case : case → maybe 𝔹
    inconv-case c₁ @ (Case x cas₁ t₁) =
      matching-case c₁ ≫=maybe λ c₂ →
      just (inconv-lams ρ₁ ρ₂ (case-args-to-lams cas₁ t₁) (fst c₂))




ctxt-params-def : params → ctxt → ctxt
ctxt-params-def ps Γ@(mk-ctxt (fn , mn , _ , q) syms i symb-occs Δ) =
  mk-ctxt (fn , mn , ps , q) syms i symb-occs Δ

ctxt-kind-def : posinfo → var → params → kind → ctxt → ctxt
ctxt-kind-def pi v ps2 k Γ@(mk-ctxt (fn , mn , ps1 , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps1 , qualif-insert-params q (mn # v) v ps1)
  (trie-insert-append2 syms fn mn v , mn-fn)
  (trie-insert i (mn # v) (kind-def (ps1 ++ ps2) k' , fn , pi))
  symb-occs Δ
  where
  k' = hnf Γ unfold-head k

ctxt-datatype-decl : var → var → args → ctxt → ctxt
ctxt-datatype-decl vₒ vᵣ as Γ@(mk-ctxt mod ss is os (Δ , μ' , μ , η)) =
  mk-ctxt mod ss is os $ Δ , trie-insert μ' (mu-Type/ vᵣ) (vₒ , mu-isType/ vₒ , as) , μ , stringset-insert η (mu-Type/ vᵣ)

ctxt-datatype-def : posinfo → var → params → kind → kind → ctrs → ctxt → ctxt
ctxt-datatype-def pi v psᵢ kᵢ k cs Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i os (Δ , μ' , μ , η)) =
  let v' = mn # v
      q' = qualif-insert-params q v' v ps in
  mk-ctxt (fn , mn , ps , q') 
    (trie-insert-append2 syms fn mn v , mn-fn)
    (trie-insert i v' (type-def (just ps) tt nothing (abs-expand-kind psᵢ k) , fn , pi)) os
    (trie-insert Δ v' (ps ++ psᵢ , kᵢ , k , cs) , μ' , trie-insert μ (data-Is/ v') v' , stringset-insert η v')

ctxt-type-def : posinfo → defScope → opacity → var → maybe type → kind → ctxt → ctxt
ctxt-type-def _  _ _ ignored-var _ _  Γ = Γ
ctxt-type-def pi s op v t k Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , q')
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (type-def (def-params s ps) op t' k , fn , pi))
  symb-occs Δ
  where
  t' = maybe-map (λ t → hnf Γ unfold-head t) t
  v' = if s iff localScope then pi % v else mn # v
  q' = qualif-insert-params q v' v (if s iff localScope then [] else ps)

ctxt-ctr-def : posinfo → var → type → params → (ctrs-length ctr-index : ℕ) → ctxt → ctxt
ctxt-ctr-def pi c t ps' n i Γ@(mk-ctxt mod@(fn , mn , ps , q) (syms , mn-fn) is symb-occs Δ) = mk-ctxt
  (fn , mn , ps , q')
  ((trie-insert-append2 syms fn mn c) , mn-fn)  
  (trie-insert is c' (ctr-def (ps ++ ps') t n i (unerased-arrows t) , fn , pi))
  symb-occs Δ
  where
  c' = mn # c
  q' = qualif-insert-params q c' c ps

ctxt-term-def : posinfo → defScope → opacity → var → maybe term → type → ctxt → ctxt
ctxt-term-def _  _ _  ignored-var _ _ Γ = Γ
ctxt-term-def pi s op v t tp Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , q')
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (term-def (def-params s ps) op t' tp , fn , pi))
  symb-occs Δ
  where
  t' = maybe-map (λ t → hnf Γ unfold-head t) t
  v' = if s iff localScope then pi % v else mn # v
  q' = qualif-insert-params q v' v (if s iff localScope then [] else ps)

ctxt-term-udef _ _ _ ignored-var _ Γ = Γ
ctxt-term-udef pi s op v t Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , qualif-insert-params q v' v (if s iff localScope then [] else ps))
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (term-udef (def-params s ps) op t' , fn , pi))
  symb-occs Δ
  where
  t' = hnf Γ unfold-head t
  v' = if s iff localScope then pi % v else mn # v

module conversion where

open import lib

open import cedille-types
open import ctxt
open import is-free
open import lift
open import rename
open import subst
open import syntax-util
open import general-util
open import erase

{- Some notes:

   -- hnf{TERM} implements erasure as well as normalization.

   -- hnf{TYPE} does not descend into terms.

   -- definitions are assumed to be in hnf
-}

data unfolding : Set where
  no-unfolding : unfolding
  unfold : (unfold-all : 𝔹) {- if ff we unfold just the head -}
           → (unfold-lift : 𝔹) {- if tt we unfold lifting types -}
           → (dampen-after-head-beta : 𝔹) {- if tt we will not unfold definitions after a head beta reduction -}
           → (erase : 𝔹) -- if tt erase the term as we unfold
           → unfolding

unfolding-get-erased : unfolding → 𝔹
unfolding-get-erased no-unfolding = ff
unfolding-get-erased (unfold _ _ _ e) = e

unfolding-set-erased : unfolding → 𝔹 → unfolding
unfolding-set-erased no-unfolding e = no-unfolding
unfolding-set-erased (unfold b1 b2 b3 _) e = unfold b1 b2 b3 e

unfold-all : unfolding
unfold-all = unfold tt tt ff tt

unfold-head : unfolding
unfold-head = unfold ff tt ff tt

unfold-head-no-lift : unfolding
unfold-head-no-lift = unfold ff ff ff ff

unfold-head-one : unfolding
unfold-head-one = unfold ff tt tt tt

unfold-dampen : (after-head-beta : 𝔹) → unfolding → unfolding
unfold-dampen _ no-unfolding = no-unfolding
unfold-dampen _ (unfold tt b b' e) = unfold tt b b e -- we do not dampen unfolding when unfolding everywhere
unfold-dampen tt (unfold ff b tt e) = no-unfolding
unfold-dampen tt (unfold ff b ff e) = (unfold ff b ff e)
unfold-dampen ff _ = no-unfolding

unfolding-elab : unfolding → unfolding
unfolding-elab no-unfolding = no-unfolding
unfolding-elab (unfold b b' b'' _) = unfold b b' b'' ff

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

hnf : {ed : exprd} → ctxt → (u : unfolding) → ⟦ ed ⟧ → (is-head : 𝔹) → ⟦ ed ⟧ 

-- assume head normalized inputs
conv-term-norm : conv-t term 
conv-type-norm : conv-t type
conv-kind-norm : conv-t kind

hnf-optClass : ctxt → unfolding → optClass → optClass
-- hnf-tk : ctxt → unfolding → tk → tk

-- does not assume erased
conv-tk : conv-t tk
conv-liftingType : conv-t liftingType
conv-optClass : conv-t optClass
-- conv-optType : conv-t optType
conv-tty* : conv-t (𝕃 tty)

-- assume erased
conv-tke : conv-t tk
conv-liftingTypee : conv-t liftingType
conv-optClasse : conv-t optClass
-- -- conv-optTypee : conv-t optType
conv-ttye* : conv-t (𝕃 tty)

conv-ctr-ps : ctxt → var → var → maybe (𝕃 (var × type) × 𝕃 (var × type))
conv-ctr-args : conv-t (var × args)
conv-ctr : conv-t var

conv-term Γ t t' = conv-terme Γ (erase t) (erase t')

conv-terme Γ t t' with decompose-apps t | decompose-apps t'
conv-terme Γ t t' | Var _ x , args | Var _ x' , args' = 
     ctxt-eq-rep Γ x x' && conv-argse Γ (erase-args args) (erase-args args')
  || conv-ctr-args Γ (x , args) (x' , args')
  || conv-term' Γ t t'
conv-terme Γ t t' | _ | _ = conv-term' Γ t t'

conv-argse Γ [] [] = tt
conv-argse Γ (a :: args) (a' :: args') = conv-terme Γ a a' && conv-argse Γ args args'
conv-argse Γ _ _ = ff

conv-type Γ t t' = conv-typee Γ (erase t) (erase t')

conv-typee Γ t t' with decompose-tpapps t | decompose-tpapps t'
conv-typee Γ t t' | TpVar _ x , args | TpVar _ x' , args' = 
     ctxt-eq-rep Γ x x' && conv-tty* Γ args args'
  || conv-type' Γ t t'
conv-typee Γ t t' | _ | _ = conv-type' Γ t t'

conv-kind Γ k k' = conv-kinde Γ (erase k) (erase k')
conv-kinde Γ k k' = conv-kind-norm Γ (hnf Γ unfold-head k tt) (hnf Γ unfold-head k' tt)

conv-term' Γ t t' = conv-term-norm Γ (hnf Γ unfold-head t tt) (hnf Γ unfold-head t' tt)
conv-type' Γ t t' = conv-type-norm Γ (hnf Γ unfold-head t tt) (hnf Γ unfold-head t' tt)

-- is-head is only used in hnf{TYPE}
hnf{TERM} Γ no-unfolding e hd = erase-term e
hnf{TERM} Γ u (Parens _ t _) hd = hnf Γ u t hd
hnf{TERM} Γ u (App t1 Erased t2) hd = hnf Γ u t1 hd
hnf{TERM} Γ u (App t1 NotErased t2) hd with hnf Γ u t1 hd
hnf{TERM} Γ u (App _ NotErased t2) hd | Lam _ _ _ x _ t1 = hnf Γ (unfold-dampen tt u) (subst Γ t2 x t1) hd
hnf{TERM} Γ u (App _ NotErased t2) hd | t1 = App t1 NotErased (hnf Γ (unfold-dampen ff u) t2 ff)
hnf{TERM} Γ u (Lam _ Erased _ _ _ t) hd = hnf Γ u t hd
hnf{TERM} Γ u (Lam _ NotErased _ x oc t) hd with hnf (ctxt-var-decl x Γ) u t hd
hnf{TERM} Γ u (Lam _ NotErased _ x oc t) hd | (App t' NotErased (Var _ x')) with x =string x' && ~ (is-free-in skip-erased x t')
hnf{TERM} Γ u (Lam _ NotErased _ x oc t) hd | (App t' NotErased (Var _ x')) | tt = t' -- eta-contraction
hnf{TERM} Γ u (Lam _ NotErased _ x oc t) hd | (App t' NotErased (Var _ x')) | ff = 
  Lam posinfo-gen NotErased posinfo-gen x NoClass (App t' NotErased (Var posinfo-gen x'))
hnf{TERM} Γ u (Lam _ NotErased _ x oc t) hd | t' = Lam posinfo-gen NotErased posinfo-gen x NoClass t'
hnf{TERM} Γ u (Let _ ff (DefTerm _ x _ t) t') hd = hnf Γ u (subst Γ t x t') hd
hnf{TERM} Γ u (Let _ tt (DefTerm _ x _ t) t') hd = hnf Γ u t' hd 
hnf{TERM} Γ u (Let _ fe (DefType _ x _ _) t') hd = hnf (ctxt-var-decl x Γ) u t' hd 
hnf{TERM} Γ (unfold _ _ _ _) (Var _ x) hd with ctxt-lookup-term-var-def Γ x
hnf{TERM} Γ (unfold _ _ _ _) (Var _ x) hd | nothing = Var posinfo-gen x
hnf{TERM} Γ (unfold ff _ _ e) (Var _ x) hd | just t = erase-if e t -- definitions should be stored in hnf
hnf{TERM} Γ (unfold tt b b' e) (Var _ x) hd | just t = hnf Γ (unfold tt b b' e) t hd -- this might not be fully normalized, only head-normalized
hnf{TERM} Γ u (AppTp t tp) hd = hnf Γ u t hd
hnf{TERM} Γ u (Sigma _ t) hd = hnf Γ u t hd
hnf{TERM} Γ u (Epsilon _ _ _ t) hd = hnf Γ u t hd
hnf{TERM} Γ u (IotaPair _ t1 t2 _ _) hd = hnf Γ u t1 hd
hnf{TERM} Γ u (IotaProj t _ _) hd = hnf Γ u t hd
hnf{TERM} Γ u (Phi _ eq t₁ t₂ _) hd = hnf Γ u t₂ hd
hnf{TERM} Γ u (Rho _ _ _ t _ t') hd = hnf Γ u t' hd
hnf{TERM} Γ u (Chi _ T t') hd = hnf Γ u t' hd
hnf{TERM} Γ u (Delta _ T t') hd = hnf Γ u t' hd
hnf{TERM} Γ u (Theta _ u' t ls) hd = hnf Γ u (lterms-to-term u' t ls) hd
hnf{TERM} Γ u (Beta _ _ (SomeTerm t _)) hd = hnf Γ u t hd
hnf{TERM} Γ u (Beta _ _ NoTerm) hd = id-term
hnf{TERM} Γ u (Open _ _ _ _ t) hd = hnf Γ u t hd
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd with decompose-apps (hnf Γ u t hd)
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | tₕ , as with Mu' pi-gen NoTerm (recompose-apps as tₕ) NoType pi-gen (map (λ {(Case _ x as' t) → Case pi-gen x as' (hnf (foldr (λ {(CaseTermArg _ NotErased x) → ctxt-var-decl x; _ → id}) Γ as') (unfold-dampen ff u) t hd)}) (erase-cases cs)) pi-gen | tₕ
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as |  tₒ | Var _ x with foldl (λ {(Case _ xₘ cas tₘ) m? → m? maybe-or (conv-ctr-ps Γ xₘ x ≫=maybe uncurry λ psₘ ps → just (caseArgs-to-lams cas tₘ , length (erase-caseArgs cas) , length ps))}) nothing (erase-cases cs)
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | Var _ x | just (tₓ , nas , nps) with drop nps (erase-args as)
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | Var _ x | just (tₓ , nas , nps) | as' with nas =ℕ length as'
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | Var _ x | just (tₓ , nas , nps) | as' | tt = hnf Γ (unfold-dampen tt u) (recompose-apps (map (TermArg NotErased) as') tₓ) hd
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | Var _ x | just (tₓ , nas , nps) | as' | ff = tₒ
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | Var _ x | nothing = tₒ
hnf{TERM} Γ u (Mu' _ _ t _ _ cs _) hd | _ , as | tₒ | _ = tₒ
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd with decompose-apps (hnf Γ u t hd)
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as with (λ t → Mu pi-gen pi-gen x t NoType pi-gen (map (λ {(Case _ x as' t) → Case pi-gen x as' (hnf (foldr (λ {(CaseTermArg _ NotErased x) → ctxt-var-decl x; _ → id}) Γ as') (unfold-dampen ff u) t hd)}) (erase-cases cs)) pi-gen) | tₕ
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' with foldl (λ {(Case _ xₘ cas tₘ) m? → m? maybe-or (conv-ctr-ps Γ xₘ x' ≫=maybe uncurry λ psₘ ps → just (caseArgs-to-lams cas tₘ , length (erase-caseArgs cas) , length ps))}) nothing (erase-cases cs) | fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' | just (tₓ , nas , nps) | fₓ with drop nps (erase-args as)
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' | just (tₓ , nas , nps) | fₓ | as' with nas =ℕ length as'
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' | just (tₓ , nas , nps) | fₓ | as' | tt = hnf Γ (unfold-dampen tt u) (recompose-apps (map (TermArg NotErased) as') (subst Γ (mlam fₓ $ tₒ $ mvar fₓ) x tₓ)) hd
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' | just (tₓ , nas , nps) | fₓ | as' | ff = tₒ $ recompose-apps (map (TermArg NotErased) as') tₕ
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | Var _ x' | nothing | fₓ = tₒ $ recompose-apps as tₕ
hnf{TERM} Γ u (Mu _ _ x t _ _ cs _) hd | tₕ , as | tₒ | _ = tₒ $ recompose-apps as tₕ
hnf{TERM} Γ u x hd = x

hnf{TYPE} Γ no-unfolding e _ = e
hnf{TYPE} Γ u (TpParens _ t _) hd = hnf Γ u t hd
hnf{TYPE} Γ u (NoSpans t _)  hd = hnf Γ u t hd
hnf{TYPE} Γ (unfold ff b' _ _) (TpVar _ x) ff  = TpVar posinfo-gen x 
hnf{TYPE} Γ (unfold b b' _ _) (TpVar _ x) _ with ctxt-lookup-type-var-def Γ x
hnf{TYPE} Γ (unfold b b' _ _) (TpVar _ x) _ | just tp = tp
hnf{TYPE} Γ (unfold b b' _ _) (TpVar _ x) _ | nothing = TpVar posinfo-gen x
hnf{TYPE} Γ u (TpAppt tp t) hd with hnf Γ u tp hd
hnf{TYPE} Γ u (TpAppt _ t) hd  | TpLambda _ _ x _ tp = hnf Γ u (subst Γ t x tp) hd
hnf{TYPE} Γ u (TpAppt _ t) hd | tp = TpAppt tp (erase-if (unfolding-get-erased u) t)
hnf{TYPE} Γ u (TpApp tp tp') hd with hnf Γ u tp hd
hnf{TYPE} Γ u (TpApp _ tp') hd | TpLambda _ _ x _ tp = hnf Γ u (subst Γ tp' x tp) hd 
hnf{TYPE} Γ u (TpApp _ tp') hd | tp with hnf Γ u tp' hd 
hnf{TYPE} Γ u (TpApp _ _) hd | tp | tp' = try-pull-lift-types tp tp'

  {- given (T1 T2), with T1 and T2 types, see if we can pull a lifting operation from the heads of T1 and T2 to
     surround the entire application.  If not, just return (T1 T2). -}
  where try-pull-lift-types : type → type → type
        try-pull-lift-types tp1 tp2 with decompose-tpapps tp1 | decompose-tpapps (hnf Γ u tp2 tt)
        try-pull-lift-types tp1 tp2 | Lft _ _ X t l , args1 | Lft _ _ X' t' l' , args2 =
          if conv-tty* Γ args1 args2 then
            try-pull-term-in Γ t l (length args1) [] []
          else
            TpApp tp1 tp2

          where try-pull-term-in : ctxt → term → liftingType → ℕ → 𝕃 var → 𝕃 liftingType → type
                try-pull-term-in Γ t (LiftParens _ l _) n vars ltps = try-pull-term-in Γ t l n vars ltps 
                try-pull-term-in Γ t (LiftArrow _ l) 0 vars ltps = 
                  recompose-tpapps args1
                    (Lft posinfo-gen posinfo-gen X
                      (Lam* vars (hnf Γ no-unfolding (App t NotErased (App* t' (map (λ v → NotErased , mvar v) vars))) tt))
                      (LiftArrow* ltps l))
                try-pull-term-in Γ (Lam _ _ _ x _ t) (LiftArrow l1 l2) (suc n) vars ltps =
                  try-pull-term-in (ctxt-var-decl x Γ) t l2 n (x :: vars) (l1 :: ltps) 
                try-pull-term-in Γ t (LiftArrow l1 l2) (suc n) vars ltps =
                  let x = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt in
                    try-pull-term-in (ctxt-var-decl x Γ) (App t NotErased (mvar x)) l2 n (x :: vars) (l1 :: ltps) 
                try-pull-term-in Γ t l n vars ltps = TpApp tp1 tp2

        try-pull-lift-types tp1 tp2 | _ | _ = TpApp tp1 tp2


hnf{TYPE} Γ u (Abs _ b _ x atk tp) _ with Abs posinfo-gen b posinfo-gen x atk (hnf (ctxt-var-decl x Γ) u tp ff)
hnf{TYPE} Γ u (Abs _ b _ x atk tp) _ | tp' with to-abs tp'
hnf{TYPE} Γ u (Abs _ _ _ _ _ _) _ | tp'' | just (mk-abs b x atk tt {- x is free in tp -} tp) = Abs posinfo-gen b posinfo-gen x atk tp
hnf{TYPE} Γ u (Abs _ _ _ _ _ _) _ | tp'' | just (mk-abs b x (Tkk k) ff tp) = Abs posinfo-gen b posinfo-gen x (Tkk k) tp
hnf{TYPE} Γ u (Abs _ _ _ _ _ _) _ | tp'' | just (mk-abs b x (Tkt tp') ff tp) = TpArrow tp' b tp
hnf{TYPE} Γ u (Abs _ _ _ _ _ _) _ | tp'' | nothing = tp''
hnf{TYPE} Γ u (TpArrow tp1 arrowtype tp2) _ = TpArrow (hnf Γ u tp1 ff) arrowtype (hnf Γ u tp2 ff)
hnf{TYPE} Γ u (TpEq _ t1 t2 _) _
  = TpEq posinfo-gen (erase t1) (erase t2) posinfo-gen
hnf{TYPE} Γ u (TpLambda _ _ x atk tp) _ = 
  TpLambda posinfo-gen posinfo-gen x (hnf Γ u atk ff) (hnf (ctxt-var-decl x Γ) u tp ff)
hnf{TYPE} Γ u @ (unfold b tt b'' b''') (Lft _ _ y t l) _ = 
 let t = hnf (ctxt-var-decl y Γ) u t tt in
   do-lift Γ (Lft posinfo-gen posinfo-gen y t l) y l (λ t → hnf{TERM} Γ unfold-head t ff) t
-- We need hnf{TYPE} to preserve types' well-kindedness, so we must check if
-- the defined term is being checked against a type and use chi to make sure
-- that wherever it is substituted, the term will have the same directionality.
-- For example, "[e ◂ {a ≃ b} = ρ e' - β] - A (ρ e - a)", would otherwise
-- head-normalize to A (ρ (ρ e' - β) - a), which wouldn't check because it
-- synthesizes the type of "ρ e' - β" (which in turn fails to synthesize the type
-- of "β"). Similar issues could happen if the term is synthesized and it uses a ρ,
-- and then substitutes into a place where it would be checked against a type.
hnf{TYPE} Γ u (TpLet _ (DefTerm _ x ot t) T) hd =
  hnf Γ u (subst Γ (Chi posinfo-gen ot t) x T) hd
-- Note that if we ever remove the requirement that type-lambdas have a classifier,
-- we would need to introduce a type-level chi to do the same thing as above.
-- Currently, synthesizing or checking a type should not make a difference.
hnf{TYPE} Γ u (TpLet _ (DefType _ x k T) T') hd = hnf Γ u (subst Γ T x T') hd
hnf{TYPE} Γ u x _ = x

hnf{KIND} Γ no-unfolding e hd = e
hnf{KIND} Γ u (KndParens _ k _) hd = hnf Γ u k hd
hnf{KIND} Γ (unfold _ _ _ _) (KndVar _ x ys) _ with ctxt-lookup-kind-var-def Γ x 
... | nothing = KndVar posinfo-gen x ys
... | just (ps , k) = fst $ subst-params-args Γ ps ys k {- do-subst ys ps k
  where do-subst : args → params → kind → kind
        do-subst (ArgsCons (TermArg _ t) ys) (ParamsCons (Decl _ _ _ x _ _) ps) k = do-subst ys ps (subst Γ t x k)
        do-subst (ArgsCons (TypeArg t) ys) (ParamsCons (Decl _ _ _ x _ _) ps) k = do-subst ys ps (subst Γ t x k)
        do-subst _ _ k = k -- should not happen -}

hnf{KIND} Γ u (KndPi _ _ x atk k) hd =
    if is-free-in check-erased x k then
      (KndPi posinfo-gen posinfo-gen x atk k)
    else
      tk-arrow-kind atk k
hnf{KIND} Γ u x hd = x

hnf{LIFTINGTYPE} Γ u x hd = x
hnf{TK} Γ u (Tkk k) _ = Tkk (hnf Γ u k tt)
hnf{TK} Γ u (Tkt tp) _ = Tkt (hnf Γ u tp ff)
hnf{QUALIF} Γ u x hd = x
hnf{ARG} Γ u x hd = x

hnf-optClass Γ u NoClass = NoClass
hnf-optClass Γ u (SomeClass atk) = SomeClass (hnf Γ u atk ff)

{- this function reduces a term to "head-applicative" normal form,
   which avoids unfolding definitions if they would lead to a top-level
   lambda-abstraction or top-level application headed by a variable for which we
   do not have a (global) definition. -}
{-# TERMINATING #-}
hanf : ctxt → (e : 𝔹) → term → term
hanf Γ e t with hnf Γ (unfolding-set-erased unfold-head-one e) t tt
hanf Γ e t | t' with decompose-apps t'
hanf Γ e t | t' | (Var _ x) , [] = t'
hanf Γ e t | t' | (Var _ x) , args with ctxt-lookup-term-var-def Γ x 
hanf Γ e t | t' | (Var _ x) , args | nothing = t'
hanf Γ e t | t' | (Var _ x) , args | just _ = hanf Γ e t'
hanf Γ e t | t' | h , args {- h could be a Lambda if args is [] -} = t

-- unfold across the term-type barrier
hnf-term-type : ctxt → (e : 𝔹) → type → type
hnf-term-type Γ e (TpEq _ t1 t2 _) = TpEq posinfo-gen (hanf Γ e t1) (hanf Γ e t2) posinfo-gen
hnf-term-type Γ e (TpAppt tp t) = hnf Γ (unfolding-set-erased unfold-head e) (TpAppt tp (hanf Γ e t)) tt
hnf-term-type Γ e tp = hnf Γ unfold-head tp tt

{-
{-# TERMINATING #-}
-- unfold a constructor type, given the name of the datatype
hnf-ctr : ctxt → var → type → type
hnf-ctr Γ X T = if is-free-in check-erased X T then h Γ (substs{TYPE}{TERM} Γ empty-trie T) else T where
  h : ctxt → type → type
  hₖ : ctxt → kind → kind
  hₖ' : ctxt → kind → kind
  hₜₖ : ctxt → tk → tk
  
  hₜₖ Γ (Tkt T) = Tkt $ hnf-ctr Γ X T
  hₜₖ Γ (Tkk k) = Tkk $ hₖ Γ k
  
  hₖ Γ k = if is-free-in check-erased X k then hₖ' Γ k else k
  
  hₖ' Γ (KndArrow k₁ k₂) = KndArrow (hₖ Γ k₁) (hₖ Γ k₂)
  hₖ' Γ (KndParens _ k _) = hₖ' Γ k
  hₖ' Γ (KndPi _ _ x atk k) = KndPi pi-gen pi-gen x (hₜₖ Γ atk) (hₖ (ctxt-var-decl x Γ) k)
  hₖ' Γ (KndTpArrow T k) = KndTpArrow (hnf-ctr Γ X T) (hₖ Γ k)
  hₖ' Γ (KndVar _ x as) = maybe-else' (ctxt-lookup-kind-var-def Γ x) (KndVar pi-gen x as) $ uncurry λ ps k → hₖ Γ $ fst $ subst-params-args Γ ps as k
  hₖ' Γ (Star _) = star
  
  h Γ (Abs _ me _ x atk T) = Abs pi-gen me pi-gen x (hₜₖ Γ atk) (hnf-ctr (ctxt-var-decl x Γ) X T)
  h Γ (Iota _ _ x T₁ T₂) = Iota pi-gen pi-gen x (hnf-ctr Γ X T₁) (hnf-ctr (ctxt-var-decl x Γ) X T₂)
  h Γ (Lft _ _ x t lT) = hnf Γ (unfolding-elab unfold-all) (Lft pi-gen pi-gen x t lT) tt
  h Γ (TpLet _ (DefTerm _ x T? t) T) = hnf-ctr Γ X $ subst Γ t x T
  h Γ (TpLet _ (DefType _ x k T') T) = hnf-ctr Γ X $ subst Γ T' x T
  h Γ (TpApp Tₕ Tₐ) = hnf-ctr Γ X $ hnf Γ (unfolding-elab unfold-head) (TpApp Tₕ Tₐ) tt
  h Γ (TpAppt Tₕ tₐ) = hnf-ctr Γ X $ hnf Γ (unfolding-elab unfold-head) (TpAppt Tₕ tₐ) tt
  h Γ (TpArrow T₁ me T₂) = TpArrow (hnf-ctr Γ X T₁) me (hnf-ctr Γ X T₂)
  h Γ (TpLambda _ _ x atk T) = TpLambda pi-gen pi-gen x (hₜₖ Γ atk) (hnf-ctr (ctxt-var-decl x Γ) X T)
  h Γ (TpParens _ T _) = h Γ T
  h Γ T = T
-}

conv-cases : conv-t cases
conv-cases Γ cs₁ cs₂ = isJust $ foldl (λ c₂ x → x ≫=maybe λ cs₁ → conv-cases' Γ cs₁ c₂) (just cs₁) cs₂ where
  conv-cases' : ctxt → cases → case → maybe cases
  conv-cases' Γ [] (Case _ x₂ as₂ t₂) = nothing
  conv-cases' Γ (c₁ @ (Case _ x₁ as₁ t₁) :: cs₁) c₂ @ (Case _ x₂ as₂ t₂) with conv-ctr Γ x₁ x₂
  ...| ff = conv-cases' Γ cs₁ c₂ ≫=maybe λ cs₁ → just (c₁ :: cs₁)
  ...| tt = maybe-if (length as₂ =ℕ length as₁ && conv-term Γ (snd (expand-case c₁)) (snd (expand-case (Case pi-gen x₂ as₂ t₂)))) ≫maybe just cs₁

ctxt-term-udef : posinfo → defScope → opacity → var → term → ctxt → ctxt

conv-term-norm Γ (Var _ x) (Var _ x') = ctxt-eq-rep Γ x x' || conv-ctr Γ x x'
-- hnf implements erasure for terms, so we can ignore some subterms for App and Lam cases below
conv-term-norm Γ (App t1 m t2) (App t1' m' t2') = conv-term-norm Γ t1 t1' && conv-term Γ t2 t2'
conv-term-norm Γ (Lam _ l _ x oc t) (Lam _ l' _ x' oc' t') = conv-term (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) t t'
conv-term-norm Γ (Hole _) _ = tt
conv-term-norm Γ _ (Hole _) = tt
conv-term-norm Γ (Mu _ _ x₁ t₁ _ _ cs₁ _) (Mu _ _ x₂ t₂ _ _ cs₂ _) =
  let --fₓ = fresh-var x₂ (ctxt-binds-var Γ) empty-renamectxt
      --μ = mlam fₓ $ Mu pi-gen pi-gen x₂ (mvar fₓ) NoType pi-gen cs₂ pi-gen
      Γ' = ctxt-rename x₁ x₂ $ ctxt-var-decl x₂ Γ in --ctxt-term-udef pi-gen localScope OpacTrans x₂ μ Γ in
  conv-term Γ t₁ t₂ && conv-cases Γ' cs₁ cs₂ -- (subst-cases Γ' id-term (mu-name-cast x₁) cs₁) (subst-cases Γ' id-term (mu-name-cast x₂) cs₂)
conv-term-norm Γ (Mu' _ _ t₁ _ _ cs₁ _) (Mu' _ _ t₂ _ _ cs₂ _) = conv-term Γ t₁ t₂ && conv-cases Γ cs₁ cs₂
-- conv-term-norm Γ (Beta _ _ NoTerm) (Beta _ _ NoTerm) = tt
-- conv-term-norm Γ (Beta _ _ (SomeTerm t _)) (Beta _ _ (SomeTerm t' _)) = conv-term Γ t t'
-- conv-term-norm Γ (Beta _ _ _) (Beta _ _ _) = ff
{- it can happen that a term is equal to a lambda abstraction in head-normal form,
   if that lambda-abstraction would eta-contract following some further beta-reductions.
   We implement this here by implicitly eta-expanding the variable and continuing
   the comparison.

   A simple example is 

       λ v . t ((λ a . a) v) ≃ t
 -}
conv-term-norm Γ (Lam _ l _ x oc t) t' =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt in
  conv-term (ctxt-rename x x' Γ) t (App t' NotErased (Var posinfo-gen x'))
conv-term-norm Γ t' (Lam _ l _ x oc t) =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt in
  conv-term (ctxt-rename x x' Γ) (App t' NotErased (Var posinfo-gen x')) t 
conv-term-norm Γ _ _ = ff

conv-type-norm Γ (TpVar _ x) (TpVar _ x') = ctxt-eq-rep Γ x x'
conv-type-norm Γ (TpApp t1 t2) (TpApp t1' t2') = conv-type-norm Γ t1 t1' && conv-type Γ t2 t2'
conv-type-norm Γ (TpAppt t1 t2) (TpAppt t1' t2') = conv-type-norm Γ t1 t1' && conv-term Γ t2 t2'
conv-type-norm Γ (Abs _ b _ x atk tp) (Abs _ b' _ x' atk' tp') = 
  eq-maybeErased b b' && conv-tk Γ atk atk' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
conv-type-norm Γ (TpArrow tp1 a1 tp2) (TpArrow tp1' a2  tp2') = eq-maybeErased a1 a2 && conv-type Γ tp1 tp1' && conv-type Γ tp2 tp2'
conv-type-norm Γ (TpArrow tp1 a tp2) (Abs _ b _ _ (Tkt tp1') tp2') = eq-maybeErased a b && conv-type Γ tp1 tp1' && conv-type Γ tp2 tp2'
conv-type-norm Γ (Abs _ b _ _ (Tkt tp1) tp2) (TpArrow tp1' a tp2') = eq-maybeErased a b && conv-type Γ tp1 tp1' && conv-type Γ tp2 tp2'
conv-type-norm Γ (Iota _ _ x m tp) (Iota _ _ x' m' tp') = 
  conv-type Γ m m' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
conv-type-norm Γ (TpEq _ t1 t2 _) (TpEq _ t1' t2' _) = conv-term Γ t1 t1' && conv-term Γ t2 t2'
conv-type-norm Γ (Lft _ _ x t l) (Lft _ _ x' t' l') =
  conv-liftingType Γ l l' && conv-term (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) t t'
conv-type-norm Γ (TpLambda _ _ x atk tp) (TpLambda _ _ x' atk' tp') =
  conv-tk Γ atk atk' && conv-type (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) tp tp'
{-conv-type-norm Γ (TpLambda _ _ x atk tp) tp' =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt
      tp'' = if tk-is-type atk then TpAppt tp' (mvar x') else TpApp tp' (mtpvar x') in
  conv-type-norm (ctxt-rename x x' Γ) tp tp''
conv-type-norm Γ tp' (TpLambda _ _ x atk tp) =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt
      tp'' = if tk-is-type atk then TpAppt tp' (mvar x') else TpApp tp' (mtpvar x') in
  conv-type-norm (ctxt-rename x x' Γ) tp'' tp-}
conv-type-norm Γ _ _ = ff 

{- even though hnf turns Pi-kinds where the variable is not free in the body into arrow kinds,
   we still need to check off-cases, because normalizing the body of a kind could cause the
   bound variable to be erased (hence allowing it to match an arrow kind). -}
conv-kind-norm Γ (KndArrow k k₁) (KndArrow k' k'') = conv-kind Γ k k' && conv-kind Γ k₁ k''
conv-kind-norm Γ (KndArrow k k₁) (KndPi _ _ x (Tkk k') k'') = conv-kind Γ k k' && conv-kind Γ k₁ k''
conv-kind-norm Γ (KndArrow k k₁) _ = ff
conv-kind-norm Γ (KndPi _ _ x (Tkk k₁) k) (KndArrow k' k'') = conv-kind Γ k₁ k' && conv-kind Γ k k''
conv-kind-norm Γ (KndPi _ _ x atk k) (KndPi _ _ x' atk' k'') = 
    conv-tk Γ atk atk' && conv-kind (ctxt-rename x x' (ctxt-var-decl-if x' Γ)) k k''
conv-kind-norm Γ (KndPi _ _ x (Tkt t) k) (KndTpArrow t' k'') = conv-type Γ t t' && conv-kind Γ k k''
conv-kind-norm Γ (KndPi _ _ x (Tkt t) k) _ = ff
conv-kind-norm Γ (KndPi _ _ x (Tkk k') k) _ = ff
conv-kind-norm Γ (KndTpArrow t k) (KndTpArrow t' k') = conv-type Γ t t' && conv-kind Γ k k'
conv-kind-norm Γ (KndTpArrow t k) (KndPi _ _ x (Tkt t') k') = conv-type Γ t t' && conv-kind Γ k k'
conv-kind-norm Γ (KndTpArrow t k) _ = ff
conv-kind-norm Γ (Star x) (Star x') = tt
conv-kind-norm Γ (Star x) _ = ff
conv-kind-norm Γ _ _ = ff -- should not happen, since the kinds are in hnf

conv-tk Γ tk tk' = conv-tke Γ (erase-tk tk) (erase-tk tk')

conv-tke Γ (Tkk k) (Tkk k') = conv-kind Γ k k'
conv-tke Γ (Tkt t) (Tkt t') = conv-type Γ t t'
conv-tke Γ _ _ = ff

conv-liftingType Γ l l' = conv-liftingTypee Γ (erase l) (erase l')
conv-liftingTypee Γ l l' = conv-kind Γ (liftingType-to-kind l) (liftingType-to-kind l')

conv-optClass Γ NoClass NoClass = tt
conv-optClass Γ (SomeClass x) (SomeClass x') = conv-tk Γ (erase-tk x) (erase-tk x')
conv-optClass Γ _ _ = ff

conv-optClasse Γ NoClass NoClass = tt
conv-optClasse Γ (SomeClass x) (SomeClass x') = conv-tk Γ x x'
conv-optClasse Γ _ _ = ff

-- conv-optType Γ NoType NoType = tt
-- conv-optType Γ (SomeType x) (SomeType x') = conv-type Γ x x'
-- conv-optType Γ _ _ = ff

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
  just (erase-params ps₁ , erase-params ps₂)
...| _ | _ = nothing

conv-ctr-args Γ (x₁ , as₁) (x₂ , as₂) =
  maybe-else' (conv-ctr-ps Γ x₁ x₂) ff $ uncurry λ ps₁ ps₂ →
  conv-argse Γ (drop (length ps₁) $ erase-args as₁) (drop (length ps₂) $ erase-args as₂)

hnf-qualif-term : ctxt → term → term
hnf-qualif-term Γ t = hnf Γ unfold-head (qualif-term Γ t) tt

hnf-qualif-type : ctxt → type → type
hnf-qualif-type Γ t = hnf Γ unfold-head (qualif-type Γ t) tt

hnf-qualif-kind : ctxt → kind → kind
hnf-qualif-kind Γ t = hnf Γ unfold-head (qualif-kind Γ t) tt


{-# TERMINATING #-}
inconv : ctxt → term → term → 𝔹
inconv Γ t₁ t₂ = inconv-lams empty-renamectxt empty-renamectxt
                   (hnf Γ unfold-all t₁ tt) (hnf Γ unfold-all t₂ tt)
  where
  fresh : var → renamectxt → renamectxt → var
  fresh x ρ₁ = fresh-var x (λ x → ctxt-binds-var Γ x || renamectxt-in-field ρ₁ x)

  make-subst : renamectxt → renamectxt → 𝕃 var → 𝕃 var → term → term → (renamectxt × renamectxt × term × term)
  make-subst ρ₁ ρ₂ [] [] t₁ t₂ = ρ₁ , ρ₂ , t₁ , t₂ -- subst-renamectxt Γ ρ₁ t₁ , subst-renamectxt Γ ρ₂ t₂
  make-subst ρ₁ ρ₂ (x₁ :: xs₁) [] t₁ t₂ =
    let x = fresh x₁ ρ₁ ρ₂ in
    make-subst (renamectxt-insert ρ₁ x₁ x) (renamectxt-insert ρ₂ x x) xs₁ [] t₁ (mapp t₂ $ mvar x)
  make-subst ρ₁ ρ₂ [] (x₂ :: xs₂) t₁ t₂ =
    let x = fresh x₂ ρ₁ ρ₂ in
    make-subst (renamectxt-insert ρ₁ x x) (renamectxt-insert ρ₂ x₂ x) [] xs₂ (mapp t₁ $ mvar x) t₂
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
      (Var _ x₁ , a₁) (Var _ x₂ , a₂) →
        inconv-apps ρ₁ ρ₂ x₁ x₂ a₁ a₂ || inconv-ctrs ρ₁ ρ₂ x₁ x₂ a₁ a₂
      (Mu _ _ x₁ t₁ _ _ ms₁ _ , a₁) (Mu _ _ x₂ t₂ _ _ ms₂ _ , a₂) →
        inconv-mu ρ₁ ρ₂ (just $ x₁ , x₂) ms₁ ms₂ ||
        inconv-lams ρ₁ ρ₂ t₁ t₂ || inconv-args ρ₁ ρ₂ a₁ a₂
      (Mu' _ _ t₁ _ _ ms₁ _ , a₁) (Mu' _ _ t₂ _ _ ms₂ _ , a₂) →
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
    matching-case (Case _ x _ _) = foldl (λ where
      (Case _ xₘ cas tₘ) m? → m? maybe-or
        (conv-ctr-ps Γ xₘ x ≫=maybe uncurry λ psₘ ps →
         just (caseArgs-to-lams cas tₘ , length cas , length ps)))
      nothing ms₂

    inconv-case : case → maybe 𝔹
    inconv-case c₁ @ (Case _ x cas₁ t₁) =
      matching-case c₁ ≫=maybe λ c₂ →
      just (inconv-lams ρ₁ ρ₂ (caseArgs-to-lams cas₁ t₁) (fst c₂))
    


  -- No need to check if x₁ or x₂ are in scope (or bound in the other's body),
  -- because t₁ and t₂ both are already as η-contracted as possible. This is
  -- not necessarily true (I think) for conv-term-norm above
  {-h ρ (Lam _ _ _ x₁ _ t₁) (Lam _ _ _ x₂ _ t₂) =
    let x = fresh x₂ ρ in
    h (renamectxt-insert (renamectxt-insert ρ x₂ x) x₁ x) t₁ t₂
  h ρ (App h₁ NotErased a₁) (App h₂ NotErased a₂) =
    h ρ h₁ h₂ || h ρ a₁ a₂
  h ρ (Var _ x₁) (Var _ x₂) with renamectxt-lookup ρ x₁ | renamectxt-lookup ρ x₂
  h ρ (Var _ _ ) (Var _ _ ) | just x₁ | just x₂ with x₁ =string x₂
  h ρ (Var _ _ ) (Var _ _ ) | just x₁ | just x₂ | tt = {!!}
  h ρ (Var _ _ ) (Var _ _ ) | just x₁ | just x₂ | ff = {!!}
  h ρ (Var _ x₁) (Var _ x₂) | nothing | nothing with env-lookup Γ x₁ | env-lookup Γ x₂
  h ρ (Var _ x₁) (Var _ x₂) | nothing | nothing
      | just (ctr-def ps₁ T₁ n₁ i₁ a₁ , _) | just (ctr-def ps₂ T₂ n₂ i₂ a₂ , _) =
    {!? || ? || ?!}
  h ρ (Var _ x₁) (Var _ x₂) | nothing | nothing | _ | _ = ff
  h ρ (Var _ x₁) (Var _ x₂) | _ | _ = ff
  h ρ t₁ t₂ = ff-}
  






ctxt-params-def : params → ctxt → ctxt
ctxt-params-def ps Γ@(mk-ctxt (fn , mn , _ , q) syms i symb-occs Δ) =
  mk-ctxt (fn , mn , ps' , q) syms i symb-occs Δ
  where ps' = qualif-params Γ ps

ctxt-kind-def : posinfo → var → params → kind → ctxt → ctxt
ctxt-kind-def pi v ps2 k Γ@(mk-ctxt (fn , mn , ps1 , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps1 , qualif-insert-params q (mn # v) v ps1)
  (trie-insert-append2 syms fn mn v , mn-fn)
  (trie-insert i (mn # v) (kind-def (ps1 ++ qualif-params Γ ps2) k' , fn , pi))
  symb-occs Δ
  where
  k' = hnf Γ unfold-head (qualif-kind Γ k) tt

ctxt-datatype-decl : var → var → args → ctxt → ctxt
ctxt-datatype-decl vₒ vᵣ as Γ@(mk-ctxt mod ss is os (Δ , μ' , μ)) =
  mk-ctxt mod ss is os $ Δ , trie-insert μ' (mu-Type/ vᵣ) (vₒ , mu-isType/ vₒ , as) , μ

-- assumption: classifier (i.e. kind) already qualified
ctxt-datatype-def : posinfo → var → params → kind → kind → ctrs → ctxt → ctxt
ctxt-datatype-def pi v psᵢ kᵢ k cs Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i os (Δ , μ' , μ)) =
  let v' = mn # v
      q' = qualif-insert-params q v' v ps in
  mk-ctxt (fn , mn , ps , q') 
    (trie-insert-append2 syms fn mn v , mn-fn)
    (trie-insert i v' (type-def (just ps) OpacTrans nothing (abs-expand-kind psᵢ k) , fn , pi)) os
    (trie-insert Δ v' (ps ++ psᵢ , kᵢ , k , cs) , μ' ,
     trie-insert μ (data-Is/ v') v')
--    (trie-insert i v' (datatype-def (maybe-map (ps ++_) psᵢ) kᵢ k cs , fn , pi)) os
{-
ctxt-mu-def : posinfo → params → var → kind → ctxt → ctxt
ctxt-mu-def pi psᵢ x k (mk-ctxt (fn , mn , ps , q) (ss , mn-fn) is os Δ) =
  let x' = mu-name-Mu x
      x'' = mn # mu-name-Mu x
      q' = qualif-insert-params q x'' x' ps in
  mk-ctxt (fn , mn , ps , q') (trie-insert-append2 ss fn mn x' , mn-fn)
    (trie-insert is x'' (mu-def (just psᵢ) (mn # x) k , fn , pi)) os Δ
-}
-- assumption: classifier (i.e. kind) already qualified
ctxt-type-def : posinfo → defScope → opacity → var → maybe type → kind → ctxt → ctxt
ctxt-type-def pi s op v t k Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , q')
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (type-def (def-params s ps) op t' k , fn , pi))
  symb-occs Δ
  where
  t' = maybe-map (λ t → hnf Γ unfold-head (qualif-type Γ t) tt) t
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

-- assumption: classifier (i.e. type) already qualified
ctxt-term-def : posinfo → defScope → opacity → var → maybe term → type → ctxt → ctxt
ctxt-term-def pi s op v t tp Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , q')
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (term-def (def-params s ps) op t' tp , fn , pi))
  symb-occs Δ
  where
  t' = maybe-map (λ t → hnf Γ unfold-head (qualif-term Γ t) tt) t
  v' = if s iff localScope then pi % v else mn # v
  q' = qualif-insert-params q v' v (if s iff localScope then [] else ps)

ctxt-term-udef pi s op v t Γ@(mk-ctxt (fn , mn , ps , q) (syms , mn-fn) i symb-occs Δ) = mk-ctxt
  (fn , mn , ps , qualif-insert-params q v' v (if s iff localScope then [] else ps))
  ((if (s iff localScope) then syms else trie-insert-append2 syms fn mn v) , mn-fn)
  (trie-insert i v' (term-udef (def-params s ps) op t' , fn , pi))
  symb-occs Δ
  where
  t' = hnf Γ unfold-head (qualif-term Γ t) tt
  v' = if s iff localScope then pi % v else mn # v

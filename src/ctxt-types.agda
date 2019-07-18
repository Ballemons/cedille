module ctxt-types where

open import cedille-types
open import general-util
open import syntax-util

location : Set
location = string × posinfo -- file path and starting position in the file 

-- file path and starting / ending position in file
span-location = string × posinfo × posinfo

-- missing locations
missing-location : location
missing-location = ("missing" , "missing")

missing-span-location : span-location
missing-span-location = ("missing" , "missing" , "missing")

{- we will generally keep classifiers of variables in hnf in the ctxt, although
   we will not necessarily unfold recursive type definitions. -}

defScope : Set
defScope = 𝔹
pattern localScope = tt
pattern globalScope = ff
pattern concrete-datatype = globalScope
pattern abstract-datatype = localScope

defParams : Set
defParams = maybe params

data ctxt-info : Set where
  -- for defining a datatype
--  datatype-def : defParams → (ind reg : kind) → ctrs → ctxt-info

  -- for defining a datatype constructor
  ctr-def : params → type → (ctrs-length ctr-index ctr-unerased-arrows : ℕ) → ctxt-info

  -- for declaring the type that proves a type is a datatype (X/Mu)
--  mu-def : defParams → var → kind → ctxt-info

  -- for declaring a variable to have a given type (with no definition)
  term-decl : type → ctxt-info

  -- for defining a variable to equal a term with a given type
  -- maybe term, because datatype X/Mu and X/mu have params, etc... but no def
  term-def : defParams → opacity → maybe term → type → ctxt-info

  -- for untyped term definitions 
  term-udef : defParams → opacity → term → ctxt-info

  -- for declaring a variable to have a given kind (with no definition)
  type-decl : kind → ctxt-info

  -- for defining a variable to equal a type with a given kind
  type-def : defParams → opacity → maybe type → kind → ctxt-info

  -- for defining a variable to equal a kind
  kind-def : params → kind → ctxt-info

  -- to rename a variable at any level to another
  rename-def : var → ctxt-info

  -- representing a declaration of a variable with no other information about it
  var-decl : ctxt-info

sym-info : Set
sym-info = ctxt-info × location

is-term-level : ctxt-info → 𝔹
is-term-level (term-decl _) = tt
is-term-level (term-def _ _ _ _) = tt
is-term-level (term-udef _ _ _) = tt
is-term-level (ctr-def _ _ _ _ _ ) = tt
is-term-level _ = ff

record ctxt : Set where
  constructor mk-ctxt
  field
    -- current module fields
    fn : string
    mn : string
    ps : params
    qual : qualif

    -- filename → module name × symbols declared in that module,
    syms : trie (string × 𝕃 string)
    
    -- module name → filename × params,
    mod-map : trie (string × params)

    -- file ID's for use in to-string.agda
    id-map : trie ℕ
    id-current : ℕ
    id-list : 𝕍 string id-current

    -- symbols → ctxt-info × location
    i : trie sym-info

    -- concrete/global datatypes
    μ : trie (params × kind × kind × ctrs × encoding-defs × encoded-defs)
    -- abstract/local datatypes
    μ' : trie (var × args)
    -- Is/D map
    Is/μ : trie var
    -- encoding defs (needed to generate fmaps for some datatypes, like rose tree)
    μ~ : trie (𝕃 (var × tmtp))
    -- highlighting datatypes (μ̲ = \Gm \_--)
    μ̲ :  stringset


ctxt-binds-var : ctxt → var → 𝔹
ctxt-binds-var Γ x = trie-contains (ctxt.qual Γ) x || trie-contains (ctxt.i Γ) x

ctxt-var-decl : var → ctxt → ctxt
ctxt-var-decl v Γ =
  record Γ {
    qual = trie-insert (ctxt.qual Γ) v (v , []);
    i = trie-insert (ctxt.i Γ) v (var-decl , "missing" , "missing")
  }

ctxt-var-decl-loc : posinfo → var → ctxt → ctxt
ctxt-var-decl-loc pi v Γ =
  record Γ {
    qual = trie-insert (ctxt.qual Γ) v (v , []);
    i = trie-insert (ctxt.i Γ) v (var-decl , ctxt.fn Γ , pi)
  }

qualif-var : ctxt → var → var
qualif-var Γ v with trie-lookup (ctxt.qual Γ) v
...| just (v' , _) = v'
...| nothing = v

ctxt-get-current-mod : ctxt → string × string × params × qualif
ctxt-get-current-mod (mk-ctxt fn mn ps qual _ _ _ _ _ _ _ _ _ _ _) = fn , mn , ps , qual



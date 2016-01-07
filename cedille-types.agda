----------------------------------------------------------------------------------
-- Types for parse trees
----------------------------------------------------------------------------------

module cedille-types where

open import lib
open import parse-tree

posinfo = string
alpha = string
alpha-bar-3 = string
alpha-range-1 = string
alpha-range-2 = string
kvar = string
kvar-bar-9 = string
kvar-star-10 = string
numpunct = string
numpunct-bar-5 = string
numpunct-bar-6 = string
numpunct-range-4 = string
var = string
var-bar-7 = string
var-star-8 = string

mutual

  data binder : Set where 
    All : binder
    Pi : binder
    TpLambda : binder

  data cmd : Set where 
    Import : var → cmd
    KindCmd : maybeKvarEq → kind → cmd
    Normalize : term → cmd
    Rec : posinfo → var → decls → indices → ctordecls → type → udefs → posinfo → cmd
    TermCmd : maybeVarEq → term → type → cmd
    TypeCmd : maybeVarEq → type → kind → cmd

  data cmds : Set where 
    CmdsNext : cmd → cmds → cmds
    CmdsStart : cmd → cmds

  data ctordecl : Set where 
    Ctordecl : posinfo → var → type → ctordecl

  data ctordecls : Set where 
    Ctordeclse : posinfo → ctordecls
    Ctordeclsne : ctordeclsne → ctordecls

  data ctordeclsne : Set where 
    CtordeclsneNext : ctordecl → ctordeclsne → ctordeclsne
    CtordeclsneStart : ctordecl → ctordeclsne

  data decl : Set where 
    Decl : posinfo → var → tk → posinfo → decl

  data decls : Set where 
    DeclsCons : decl → decls → decls
    DeclsNil : posinfo → decls

  data indices : Set where 
    Indicese : posinfo → indices
    Indicesne : decls → indices

  data kind : Set where 
    KndArrow : kind → kind → kind
    KndParens : posinfo → kind → posinfo → kind
    KndPi : posinfo → var → tk → kind → kind
    KndTpArrow : type → kind → kind
    KndVar : posinfo → kvar → kind
    Star : posinfo → kind

  data lam : Set where 
    ErasedLambda : lam
    KeptLambda : lam

  data liftingType : Set where 
    LiftArrow : liftingType → liftingType → liftingType
    LiftParens : posinfo → liftingType → posinfo → liftingType
    LiftPi : posinfo → var → type → liftingType → liftingType
    LiftStar : posinfo → liftingType
    LiftTpArrow : type → liftingType → liftingType

  data maybeErased : Set where 
    Erased : maybeErased
    NotErased : maybeErased

  data maybeKvarEq : Set where 
    KvarEq : kvar → maybeKvarEq
    NoKvarEq : maybeKvarEq

  data maybeVarEq : Set where 
    NoVarEq : maybeVarEq
    VarEq : var → maybeVarEq

  data optClass : Set where 
    NoClass : optClass
    SomeClass : tk → optClass

  data start : Set where 
    Cmds : cmds → start

  data term : Set where 
    App : term → maybeErased → term → term
    AppTp : term → type → term
    Hole : posinfo → term
    Lam : posinfo → lam → var → optClass → term → term
    Parens : posinfo → term → posinfo → term
    Var : posinfo → var → term

  data tk : Set where 
    Tkk : kind → tk
    Tkt : type → tk

  data type : Set where 
    Abs : posinfo → binder → var → tk → type → type
    Iota : posinfo → var → type → type
    Lft : posinfo → term → liftingType → type
    TpApp : type → type → type
    TpAppt : type → term → type
    TpArrow : type → type → type
    TpEq : term → term → type
    TpParens : posinfo → type → posinfo → type
    TpVar : posinfo → var → type

  data udef : Set where 
    Udef : posinfo → var → term → udef

  data udefs : Set where 
    Udefse : posinfo → udefs
    Udefsne : udefsne → udefs

  data udefsne : Set where 
    UdefsneNext : udef → udefsne → udefsne
    UdefsneStart : udef → udefsne

-- embedded types:
lliftingType : Set
lliftingType = liftingType
lterm : Set
lterm = term
ltype : Set
ltype = type

data ParseTreeT : Set where
  parsed-binder : binder → ParseTreeT
  parsed-cmd : cmd → ParseTreeT
  parsed-cmds : cmds → ParseTreeT
  parsed-ctordecl : ctordecl → ParseTreeT
  parsed-ctordecls : ctordecls → ParseTreeT
  parsed-ctordeclsne : ctordeclsne → ParseTreeT
  parsed-decl : decl → ParseTreeT
  parsed-decls : decls → ParseTreeT
  parsed-indices : indices → ParseTreeT
  parsed-kind : kind → ParseTreeT
  parsed-lam : lam → ParseTreeT
  parsed-liftingType : liftingType → ParseTreeT
  parsed-maybeErased : maybeErased → ParseTreeT
  parsed-maybeKvarEq : maybeKvarEq → ParseTreeT
  parsed-maybeVarEq : maybeVarEq → ParseTreeT
  parsed-optClass : optClass → ParseTreeT
  parsed-start : start → ParseTreeT
  parsed-term : term → ParseTreeT
  parsed-tk : tk → ParseTreeT
  parsed-type : type → ParseTreeT
  parsed-udef : udef → ParseTreeT
  parsed-udefs : udefs → ParseTreeT
  parsed-udefsne : udefsne → ParseTreeT
  parsed-lliftingType : liftingType → ParseTreeT
  parsed-lterm : term → ParseTreeT
  parsed-ltype : type → ParseTreeT
  parsed-posinfo : posinfo → ParseTreeT
  parsed-alpha : alpha → ParseTreeT
  parsed-alpha-bar-3 : alpha-bar-3 → ParseTreeT
  parsed-alpha-range-1 : alpha-range-1 → ParseTreeT
  parsed-alpha-range-2 : alpha-range-2 → ParseTreeT
  parsed-kvar : kvar → ParseTreeT
  parsed-kvar-bar-9 : kvar-bar-9 → ParseTreeT
  parsed-kvar-star-10 : kvar-star-10 → ParseTreeT
  parsed-numpunct : numpunct → ParseTreeT
  parsed-numpunct-bar-5 : numpunct-bar-5 → ParseTreeT
  parsed-numpunct-bar-6 : numpunct-bar-6 → ParseTreeT
  parsed-numpunct-range-4 : numpunct-range-4 → ParseTreeT
  parsed-var : var → ParseTreeT
  parsed-var-bar-7 : var-bar-7 → ParseTreeT
  parsed-var-star-8 : var-star-8 → ParseTreeT
  parsed-anychar : ParseTreeT
  parsed-anychar-bar-11 : ParseTreeT
  parsed-anychar-bar-12 : ParseTreeT
  parsed-anychar-bar-13 : ParseTreeT
  parsed-anychar-bar-14 : ParseTreeT
  parsed-anychar-bar-15 : ParseTreeT
  parsed-anychar-bar-16 : ParseTreeT
  parsed-anychar-bar-17 : ParseTreeT
  parsed-anychar-bar-18 : ParseTreeT
  parsed-anychar-bar-19 : ParseTreeT
  parsed-anychar-bar-20 : ParseTreeT
  parsed-anychar-bar-21 : ParseTreeT
  parsed-anychar-bar-22 : ParseTreeT
  parsed-anychar-bar-23 : ParseTreeT
  parsed-anychar-bar-24 : ParseTreeT
  parsed-anychar-bar-25 : ParseTreeT
  parsed-anychar-bar-26 : ParseTreeT
  parsed-anychar-bar-27 : ParseTreeT
  parsed-anychar-bar-28 : ParseTreeT
  parsed-anychar-bar-29 : ParseTreeT
  parsed-anychar-bar-30 : ParseTreeT
  parsed-anychar-bar-31 : ParseTreeT
  parsed-anychar-bar-32 : ParseTreeT
  parsed-anychar-bar-33 : ParseTreeT
  parsed-anychar-bar-34 : ParseTreeT
  parsed-anychar-bar-35 : ParseTreeT
  parsed-anychar-bar-36 : ParseTreeT
  parsed-anychar-bar-37 : ParseTreeT
  parsed-anychar-bar-38 : ParseTreeT
  parsed-anychar-bar-39 : ParseTreeT
  parsed-anychar-bar-40 : ParseTreeT
  parsed-aws : ParseTreeT
  parsed-aws-bar-42 : ParseTreeT
  parsed-aws-bar-43 : ParseTreeT
  parsed-aws-bar-44 : ParseTreeT
  parsed-comment : ParseTreeT
  parsed-comment-star-41 : ParseTreeT
  parsed-ows : ParseTreeT
  parsed-ows-star-46 : ParseTreeT
  parsed-ws : ParseTreeT
  parsed-ws-plus-45 : ParseTreeT

------------------------------------------
-- Parse tree printing functions
------------------------------------------

posinfoToString : posinfo → string
posinfoToString x = "(posinfo " ^ x ^ ")"
alphaToString : alpha → string
alphaToString x = "(alpha " ^ x ^ ")"
alpha-bar-3ToString : alpha-bar-3 → string
alpha-bar-3ToString x = "(alpha-bar-3 " ^ x ^ ")"
alpha-range-1ToString : alpha-range-1 → string
alpha-range-1ToString x = "(alpha-range-1 " ^ x ^ ")"
alpha-range-2ToString : alpha-range-2 → string
alpha-range-2ToString x = "(alpha-range-2 " ^ x ^ ")"
kvarToString : kvar → string
kvarToString x = "(kvar " ^ x ^ ")"
kvar-bar-9ToString : kvar-bar-9 → string
kvar-bar-9ToString x = "(kvar-bar-9 " ^ x ^ ")"
kvar-star-10ToString : kvar-star-10 → string
kvar-star-10ToString x = "(kvar-star-10 " ^ x ^ ")"
numpunctToString : numpunct → string
numpunctToString x = "(numpunct " ^ x ^ ")"
numpunct-bar-5ToString : numpunct-bar-5 → string
numpunct-bar-5ToString x = "(numpunct-bar-5 " ^ x ^ ")"
numpunct-bar-6ToString : numpunct-bar-6 → string
numpunct-bar-6ToString x = "(numpunct-bar-6 " ^ x ^ ")"
numpunct-range-4ToString : numpunct-range-4 → string
numpunct-range-4ToString x = "(numpunct-range-4 " ^ x ^ ")"
varToString : var → string
varToString x = "(var " ^ x ^ ")"
var-bar-7ToString : var-bar-7 → string
var-bar-7ToString x = "(var-bar-7 " ^ x ^ ")"
var-star-8ToString : var-star-8 → string
var-star-8ToString x = "(var-star-8 " ^ x ^ ")"

mutual
  binderToString : binder → string
  binderToString (All) = "All" ^ ""
  binderToString (Pi) = "Pi" ^ ""
  binderToString (TpLambda) = "TpLambda" ^ ""

  cmdToString : cmd → string
  cmdToString (Import x0) = "(Import" ^ " " ^ (varToString x0) ^ ")"
  cmdToString (KindCmd x0 x1) = "(KindCmd" ^ " " ^ (maybeKvarEqToString x0) ^ " " ^ (kindToString x1) ^ ")"
  cmdToString (Normalize x0) = "(Normalize" ^ " " ^ (termToString x0) ^ ")"
  cmdToString (Rec x0 x1 x2 x3 x4 x5 x6 x7) = "(Rec" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (declsToString x2) ^ " " ^ (indicesToString x3) ^ " " ^ (ctordeclsToString x4) ^ " " ^ (typeToString x5) ^ " " ^ (udefsToString x6) ^ " " ^ (posinfoToString x7) ^ ")"
  cmdToString (TermCmd x0 x1 x2) = "(TermCmd" ^ " " ^ (maybeVarEqToString x0) ^ " " ^ (termToString x1) ^ " " ^ (typeToString x2) ^ ")"
  cmdToString (TypeCmd x0 x1 x2) = "(TypeCmd" ^ " " ^ (maybeVarEqToString x0) ^ " " ^ (typeToString x1) ^ " " ^ (kindToString x2) ^ ")"

  cmdsToString : cmds → string
  cmdsToString (CmdsNext x0 x1) = "(CmdsNext" ^ " " ^ (cmdToString x0) ^ " " ^ (cmdsToString x1) ^ ")"
  cmdsToString (CmdsStart x0) = "(CmdsStart" ^ " " ^ (cmdToString x0) ^ ")"

  ctordeclToString : ctordecl → string
  ctordeclToString (Ctordecl x0 x1 x2) = "(Ctordecl" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (typeToString x2) ^ ")"

  ctordeclsToString : ctordecls → string
  ctordeclsToString (Ctordeclse x0) = "(Ctordeclse" ^ " " ^ (posinfoToString x0) ^ ")"
  ctordeclsToString (Ctordeclsne x0) = "(Ctordeclsne" ^ " " ^ (ctordeclsneToString x0) ^ ")"

  ctordeclsneToString : ctordeclsne → string
  ctordeclsneToString (CtordeclsneNext x0 x1) = "(CtordeclsneNext" ^ " " ^ (ctordeclToString x0) ^ " " ^ (ctordeclsneToString x1) ^ ")"
  ctordeclsneToString (CtordeclsneStart x0) = "(CtordeclsneStart" ^ " " ^ (ctordeclToString x0) ^ ")"

  declToString : decl → string
  declToString (Decl x0 x1 x2 x3) = "(Decl" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (tkToString x2) ^ " " ^ (posinfoToString x3) ^ ")"

  declsToString : decls → string
  declsToString (DeclsCons x0 x1) = "(DeclsCons" ^ " " ^ (declToString x0) ^ " " ^ (declsToString x1) ^ ")"
  declsToString (DeclsNil x0) = "(DeclsNil" ^ " " ^ (posinfoToString x0) ^ ")"

  indicesToString : indices → string
  indicesToString (Indicese x0) = "(Indicese" ^ " " ^ (posinfoToString x0) ^ ")"
  indicesToString (Indicesne x0) = "(Indicesne" ^ " " ^ (declsToString x0) ^ ")"

  kindToString : kind → string
  kindToString (KndArrow x0 x1) = "(KndArrow" ^ " " ^ (kindToString x0) ^ " " ^ (kindToString x1) ^ ")"
  kindToString (KndParens x0 x1 x2) = "(KndParens" ^ " " ^ (posinfoToString x0) ^ " " ^ (kindToString x1) ^ " " ^ (posinfoToString x2) ^ ")"
  kindToString (KndPi x0 x1 x2 x3) = "(KndPi" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (tkToString x2) ^ " " ^ (kindToString x3) ^ ")"
  kindToString (KndTpArrow x0 x1) = "(KndTpArrow" ^ " " ^ (typeToString x0) ^ " " ^ (kindToString x1) ^ ")"
  kindToString (KndVar x0 x1) = "(KndVar" ^ " " ^ (posinfoToString x0) ^ " " ^ (kvarToString x1) ^ ")"
  kindToString (Star x0) = "(Star" ^ " " ^ (posinfoToString x0) ^ ")"

  lamToString : lam → string
  lamToString (ErasedLambda) = "ErasedLambda" ^ ""
  lamToString (KeptLambda) = "KeptLambda" ^ ""

  liftingTypeToString : liftingType → string
  liftingTypeToString (LiftArrow x0 x1) = "(LiftArrow" ^ " " ^ (liftingTypeToString x0) ^ " " ^ (liftingTypeToString x1) ^ ")"
  liftingTypeToString (LiftParens x0 x1 x2) = "(LiftParens" ^ " " ^ (posinfoToString x0) ^ " " ^ (liftingTypeToString x1) ^ " " ^ (posinfoToString x2) ^ ")"
  liftingTypeToString (LiftPi x0 x1 x2 x3) = "(LiftPi" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (typeToString x2) ^ " " ^ (liftingTypeToString x3) ^ ")"
  liftingTypeToString (LiftStar x0) = "(LiftStar" ^ " " ^ (posinfoToString x0) ^ ")"
  liftingTypeToString (LiftTpArrow x0 x1) = "(LiftTpArrow" ^ " " ^ (typeToString x0) ^ " " ^ (liftingTypeToString x1) ^ ")"

  maybeErasedToString : maybeErased → string
  maybeErasedToString (Erased) = "Erased" ^ ""
  maybeErasedToString (NotErased) = "NotErased" ^ ""

  maybeKvarEqToString : maybeKvarEq → string
  maybeKvarEqToString (KvarEq x0) = "(KvarEq" ^ " " ^ (kvarToString x0) ^ ")"
  maybeKvarEqToString (NoKvarEq) = "NoKvarEq" ^ ""

  maybeVarEqToString : maybeVarEq → string
  maybeVarEqToString (NoVarEq) = "NoVarEq" ^ ""
  maybeVarEqToString (VarEq x0) = "(VarEq" ^ " " ^ (varToString x0) ^ ")"

  optClassToString : optClass → string
  optClassToString (NoClass) = "NoClass" ^ ""
  optClassToString (SomeClass x0) = "(SomeClass" ^ " " ^ (tkToString x0) ^ ")"

  startToString : start → string
  startToString (Cmds x0) = "(Cmds" ^ " " ^ (cmdsToString x0) ^ ")"

  termToString : term → string
  termToString (App x0 x1 x2) = "(App" ^ " " ^ (termToString x0) ^ " " ^ (maybeErasedToString x1) ^ " " ^ (termToString x2) ^ ")"
  termToString (AppTp x0 x1) = "(AppTp" ^ " " ^ (termToString x0) ^ " " ^ (typeToString x1) ^ ")"
  termToString (Hole x0) = "(Hole" ^ " " ^ (posinfoToString x0) ^ ")"
  termToString (Lam x0 x1 x2 x3 x4) = "(Lam" ^ " " ^ (posinfoToString x0) ^ " " ^ (lamToString x1) ^ " " ^ (varToString x2) ^ " " ^ (optClassToString x3) ^ " " ^ (termToString x4) ^ ")"
  termToString (Parens x0 x1 x2) = "(Parens" ^ " " ^ (posinfoToString x0) ^ " " ^ (termToString x1) ^ " " ^ (posinfoToString x2) ^ ")"
  termToString (Var x0 x1) = "(Var" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ ")"

  tkToString : tk → string
  tkToString (Tkk x0) = "(Tkk" ^ " " ^ (kindToString x0) ^ ")"
  tkToString (Tkt x0) = "(Tkt" ^ " " ^ (typeToString x0) ^ ")"

  typeToString : type → string
  typeToString (Abs x0 x1 x2 x3 x4) = "(Abs" ^ " " ^ (posinfoToString x0) ^ " " ^ (binderToString x1) ^ " " ^ (varToString x2) ^ " " ^ (tkToString x3) ^ " " ^ (typeToString x4) ^ ")"
  typeToString (Iota x0 x1 x2) = "(Iota" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (typeToString x2) ^ ")"
  typeToString (Lft x0 x1 x2) = "(Lft" ^ " " ^ (posinfoToString x0) ^ " " ^ (termToString x1) ^ " " ^ (liftingTypeToString x2) ^ ")"
  typeToString (TpApp x0 x1) = "(TpApp" ^ " " ^ (typeToString x0) ^ " " ^ (typeToString x1) ^ ")"
  typeToString (TpAppt x0 x1) = "(TpAppt" ^ " " ^ (typeToString x0) ^ " " ^ (termToString x1) ^ ")"
  typeToString (TpArrow x0 x1) = "(TpArrow" ^ " " ^ (typeToString x0) ^ " " ^ (typeToString x1) ^ ")"
  typeToString (TpEq x0 x1) = "(TpEq" ^ " " ^ (termToString x0) ^ " " ^ (termToString x1) ^ ")"
  typeToString (TpParens x0 x1 x2) = "(TpParens" ^ " " ^ (posinfoToString x0) ^ " " ^ (typeToString x1) ^ " " ^ (posinfoToString x2) ^ ")"
  typeToString (TpVar x0 x1) = "(TpVar" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ ")"

  udefToString : udef → string
  udefToString (Udef x0 x1 x2) = "(Udef" ^ " " ^ (posinfoToString x0) ^ " " ^ (varToString x1) ^ " " ^ (termToString x2) ^ ")"

  udefsToString : udefs → string
  udefsToString (Udefse x0) = "(Udefse" ^ " " ^ (posinfoToString x0) ^ ")"
  udefsToString (Udefsne x0) = "(Udefsne" ^ " " ^ (udefsneToString x0) ^ ")"

  udefsneToString : udefsne → string
  udefsneToString (UdefsneNext x0 x1) = "(UdefsneNext" ^ " " ^ (udefToString x0) ^ " " ^ (udefsneToString x1) ^ ")"
  udefsneToString (UdefsneStart x0) = "(UdefsneStart" ^ " " ^ (udefToString x0) ^ ")"

ParseTreeToString : ParseTreeT → string
ParseTreeToString (parsed-binder t) = binderToString t
ParseTreeToString (parsed-cmd t) = cmdToString t
ParseTreeToString (parsed-cmds t) = cmdsToString t
ParseTreeToString (parsed-ctordecl t) = ctordeclToString t
ParseTreeToString (parsed-ctordecls t) = ctordeclsToString t
ParseTreeToString (parsed-ctordeclsne t) = ctordeclsneToString t
ParseTreeToString (parsed-decl t) = declToString t
ParseTreeToString (parsed-decls t) = declsToString t
ParseTreeToString (parsed-indices t) = indicesToString t
ParseTreeToString (parsed-kind t) = kindToString t
ParseTreeToString (parsed-lam t) = lamToString t
ParseTreeToString (parsed-liftingType t) = liftingTypeToString t
ParseTreeToString (parsed-maybeErased t) = maybeErasedToString t
ParseTreeToString (parsed-maybeKvarEq t) = maybeKvarEqToString t
ParseTreeToString (parsed-maybeVarEq t) = maybeVarEqToString t
ParseTreeToString (parsed-optClass t) = optClassToString t
ParseTreeToString (parsed-start t) = startToString t
ParseTreeToString (parsed-term t) = termToString t
ParseTreeToString (parsed-tk t) = tkToString t
ParseTreeToString (parsed-type t) = typeToString t
ParseTreeToString (parsed-udef t) = udefToString t
ParseTreeToString (parsed-udefs t) = udefsToString t
ParseTreeToString (parsed-udefsne t) = udefsneToString t
ParseTreeToString (parsed-lliftingType t) = liftingTypeToString t
ParseTreeToString (parsed-lterm t) = termToString t
ParseTreeToString (parsed-ltype t) = typeToString t
ParseTreeToString (parsed-posinfo t) = posinfoToString t
ParseTreeToString (parsed-alpha t) = alphaToString t
ParseTreeToString (parsed-alpha-bar-3 t) = alpha-bar-3ToString t
ParseTreeToString (parsed-alpha-range-1 t) = alpha-range-1ToString t
ParseTreeToString (parsed-alpha-range-2 t) = alpha-range-2ToString t
ParseTreeToString (parsed-kvar t) = kvarToString t
ParseTreeToString (parsed-kvar-bar-9 t) = kvar-bar-9ToString t
ParseTreeToString (parsed-kvar-star-10 t) = kvar-star-10ToString t
ParseTreeToString (parsed-numpunct t) = numpunctToString t
ParseTreeToString (parsed-numpunct-bar-5 t) = numpunct-bar-5ToString t
ParseTreeToString (parsed-numpunct-bar-6 t) = numpunct-bar-6ToString t
ParseTreeToString (parsed-numpunct-range-4 t) = numpunct-range-4ToString t
ParseTreeToString (parsed-var t) = varToString t
ParseTreeToString (parsed-var-bar-7 t) = var-bar-7ToString t
ParseTreeToString (parsed-var-star-8 t) = var-star-8ToString t
ParseTreeToString parsed-anychar = "[anychar]"
ParseTreeToString parsed-anychar-bar-11 = "[anychar-bar-11]"
ParseTreeToString parsed-anychar-bar-12 = "[anychar-bar-12]"
ParseTreeToString parsed-anychar-bar-13 = "[anychar-bar-13]"
ParseTreeToString parsed-anychar-bar-14 = "[anychar-bar-14]"
ParseTreeToString parsed-anychar-bar-15 = "[anychar-bar-15]"
ParseTreeToString parsed-anychar-bar-16 = "[anychar-bar-16]"
ParseTreeToString parsed-anychar-bar-17 = "[anychar-bar-17]"
ParseTreeToString parsed-anychar-bar-18 = "[anychar-bar-18]"
ParseTreeToString parsed-anychar-bar-19 = "[anychar-bar-19]"
ParseTreeToString parsed-anychar-bar-20 = "[anychar-bar-20]"
ParseTreeToString parsed-anychar-bar-21 = "[anychar-bar-21]"
ParseTreeToString parsed-anychar-bar-22 = "[anychar-bar-22]"
ParseTreeToString parsed-anychar-bar-23 = "[anychar-bar-23]"
ParseTreeToString parsed-anychar-bar-24 = "[anychar-bar-24]"
ParseTreeToString parsed-anychar-bar-25 = "[anychar-bar-25]"
ParseTreeToString parsed-anychar-bar-26 = "[anychar-bar-26]"
ParseTreeToString parsed-anychar-bar-27 = "[anychar-bar-27]"
ParseTreeToString parsed-anychar-bar-28 = "[anychar-bar-28]"
ParseTreeToString parsed-anychar-bar-29 = "[anychar-bar-29]"
ParseTreeToString parsed-anychar-bar-30 = "[anychar-bar-30]"
ParseTreeToString parsed-anychar-bar-31 = "[anychar-bar-31]"
ParseTreeToString parsed-anychar-bar-32 = "[anychar-bar-32]"
ParseTreeToString parsed-anychar-bar-33 = "[anychar-bar-33]"
ParseTreeToString parsed-anychar-bar-34 = "[anychar-bar-34]"
ParseTreeToString parsed-anychar-bar-35 = "[anychar-bar-35]"
ParseTreeToString parsed-anychar-bar-36 = "[anychar-bar-36]"
ParseTreeToString parsed-anychar-bar-37 = "[anychar-bar-37]"
ParseTreeToString parsed-anychar-bar-38 = "[anychar-bar-38]"
ParseTreeToString parsed-anychar-bar-39 = "[anychar-bar-39]"
ParseTreeToString parsed-anychar-bar-40 = "[anychar-bar-40]"
ParseTreeToString parsed-aws = "[aws]"
ParseTreeToString parsed-aws-bar-42 = "[aws-bar-42]"
ParseTreeToString parsed-aws-bar-43 = "[aws-bar-43]"
ParseTreeToString parsed-aws-bar-44 = "[aws-bar-44]"
ParseTreeToString parsed-comment = "[comment]"
ParseTreeToString parsed-comment-star-41 = "[comment-star-41]"
ParseTreeToString parsed-ows = "[ows]"
ParseTreeToString parsed-ows-star-46 = "[ows-star-46]"
ParseTreeToString parsed-ws = "[ws]"
ParseTreeToString parsed-ws-plus-45 = "[ws-plus-45]"

------------------------------------------
-- Reorganizing rules
------------------------------------------

mutual

  {-# NO_TERMINATION_CHECK #-}
  norm-udefsne : (x : udefsne) → udefsne
  norm-udefsne x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-udefs : (x : udefs) → udefs
  norm-udefs x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-udef : (x : udef) → udef
  norm-udef x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-type : (x : type) → type
  norm-type (TpApp x1 (TpAppt x2 x3)) = (norm-type (TpAppt  (norm-type (TpApp  x1 x2) ) x3) )
  norm-type (TpApp x1 (TpApp x2 x3)) = (norm-type (TpApp  (norm-type (TpApp  x1 x2) ) x3) )
  norm-type x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-tk : (x : tk) → tk
  norm-tk x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-term : (x : term) → term
  norm-term (AppTp (App x1 x2 (Lam x3 x4 x5 x6 x7)) x8) = (norm-term (App  x1 x2 (norm-term (Lam  x3 x4 x5 x6 (norm-term (AppTp  x7 x8) )) )) )
  norm-term (AppTp (Lam x1 x2 x3 x4 x5) x6) = (norm-term (Lam  x1 x2 x3 x4 (norm-term (AppTp  x5 x6) )) )
  norm-term (App x1 x2 (AppTp x3 x4)) = (norm-term (AppTp  (norm-term (App  x1 x2 x3) ) x4) )
  norm-term (App (App x1 x2 (Lam x3 x4 x5 x6 x7)) x8 x9) = (norm-term (App  x1 x2 (norm-term (Lam  x3 x4 x5 x6 (norm-term (App  x7 x8 x9) )) )) )
  norm-term (App (Lam x1 x2 x3 x4 x5) x6 x7) = (norm-term (Lam  x1 x2 x3 x4 (norm-term (App  x5 x6 x7) )) )
  norm-term (App x1 x2 (App x3 x4 x5)) = (norm-term (App  (norm-term (App  x1 x2 x3) ) x4 x5) )
  norm-term x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-start : (x : start) → start
  norm-start x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-posinfo : (x : posinfo) → posinfo
  norm-posinfo x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-optClass : (x : optClass) → optClass
  norm-optClass x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-maybeVarEq : (x : maybeVarEq) → maybeVarEq
  norm-maybeVarEq x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-maybeKvarEq : (x : maybeKvarEq) → maybeKvarEq
  norm-maybeKvarEq x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-maybeErased : (x : maybeErased) → maybeErased
  norm-maybeErased x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-ltype : (x : ltype) → ltype
  norm-ltype x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-lterm : (x : lterm) → lterm
  norm-lterm x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-lliftingType : (x : lliftingType) → lliftingType
  norm-lliftingType x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-liftingType : (x : liftingType) → liftingType
  norm-liftingType (LiftArrow (LiftPi x1 x2 x3 x4) x5) = (norm-liftingType (LiftPi  x1 x2 x3 (norm-liftingType (LiftArrow  x4 x5) )) )
  norm-liftingType (LiftTpArrow (TpArrow x1 x2) x3) = (norm-liftingType (LiftTpArrow  x1 (norm-liftingType (LiftTpArrow  x2 x3) )) )
  norm-liftingType (LiftArrow (LiftTpArrow x1 x2) x3) = (norm-liftingType (LiftTpArrow  x1 (norm-liftingType (LiftArrow  x2 x3) )) )
  norm-liftingType (LiftArrow (LiftArrow x1 x2) x3) = (norm-liftingType (LiftArrow  x1 (norm-liftingType (LiftArrow  x2 x3) )) )
  norm-liftingType x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-lam : (x : lam) → lam
  norm-lam x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-kind : (x : kind) → kind
  norm-kind (KndArrow (KndPi x1 x2 x3 x4) x5) = (norm-kind (KndPi  x1 x2 x3 (norm-kind (KndArrow  x4 x5) )) )
  norm-kind (KndArrow (KndTpArrow x1 x2) x3) = (norm-kind (KndTpArrow  x1 (norm-kind (KndArrow  x2 x3) )) )
  norm-kind (KndArrow (KndArrow x1 x2) x3) = (norm-kind (KndArrow  x1 (norm-kind (KndArrow  x2 x3) )) )
  norm-kind x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-indices : (x : indices) → indices
  norm-indices x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-decls : (x : decls) → decls
  norm-decls x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-decl : (x : decl) → decl
  norm-decl x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-ctordeclsne : (x : ctordeclsne) → ctordeclsne
  norm-ctordeclsne x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-ctordecls : (x : ctordecls) → ctordecls
  norm-ctordecls x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-ctordecl : (x : ctordecl) → ctordecl
  norm-ctordecl x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-cmds : (x : cmds) → cmds
  norm-cmds x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-cmd : (x : cmd) → cmd
  norm-cmd x = x

  {-# NO_TERMINATION_CHECK #-}
  norm-binder : (x : binder) → binder
  norm-binder x = x

isParseTree : ParseTreeT → 𝕃 char → string → Set
isParseTree p l s = ⊤ {- this will be ignored since we are using simply typed runs -}

ptr : ParseTreeRec
ptr = record { ParseTreeT = ParseTreeT ; isParseTree = isParseTree ; ParseTreeToString = ParseTreeToString }


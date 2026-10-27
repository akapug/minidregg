/-
# scripts/RanMintCensus.lean -- the one mint of `Ran`, by term, theorems included

`Compiler.CredentialSignatureAdmission.Ran config query answer` is the fact "the pinned process answered
`answer` on `query`".  It is a field-less Prop with a private constructor, and `TokenCensus` check 1 skips
theorems and proofs, so a forged proof (`⟨⟩`, `by constructor`, unfolding `oracleAnswered` or
`(receiverVerifier (.live c)).Answered`, or `Vouchers.ofAnswered _ _ (fun _ _ => ⟨⟩) _` at the live verifier)
is not caught there.  Every such forgery elaborates to a term containing the constant `Ran.mk`, whatever it
is spelled as.  This census scans EVERY constant of the research umbrella, theorems included, and refuses
unless the only constants that mention `Ran.mk` are `receiverVerifier` (and what the compiler generates
for it) and `Ran`'s own generated machinery.  A second site is a red gate.
-/
import AxiomCensusResearch

open Lean Elab Command

namespace RanMintCensus

def ranMk : Name := `Minidregg.Compiler.CredentialSignatureAdmission.Ran.mk
def ran : Name := `Minidregg.Compiler.CredentialSignatureAdmission.Ran
def home : Name := `Minidregg.Compiler.CredentialSignatureAdmission.receiverVerifier

/-- Generated auxiliaries (`match_1`, `_lambda_2`, `proof_3`, `eq_1`, ...) belong to the user definition. -/
partial def owner (n : Name) : Name :=
  let n := (privateToUserName? n).getD n
  match n with
  | .num p _ => owner p
  | .str p s =>
    if s.startsWith "_" || s.startsWith "match_" || s.startsWith "proof_" || s.startsWith "eq_"
        || s.startsWith "lam_" || s.startsWith "spec_" || s == "eq_def" || s == "sizeOf_spec"
        || s.startsWith "_cstage" then owner p
    else n
  | .anonymous => n

def userNames (e : Expr) : List Name :=
  e.getUsedConstants.toList.map fun n => (privateToUserName? n).getD n

def mentions (info : ConstantInfo) : Bool :=
  (userNames info.type).contains ranMk ||
    match info.value? with
    | some v => (userNames v).contains ranMk
    | none => false

/-- Owners of every constant (theorems included) that mentions `Ran.mk`, except `Ran`'s own machinery. -/
def users (env : Environment) : List Name :=
  env.constants.fold (init := ([] : List Name)) fun acc n info =>
    let o := owner n
    if ran.isPrefixOf o then acc
    else if mentions info then (if acc.contains o then acc else o :: acc)
    else acc

end RanMintCensus

open RanMintCensus in
run_cmd do
  let env ← getEnv
  let found := users env
  logInfo m!"ran-mint census: Ran.mk is mentioned by {found}"
  let mut failures : Array String := #[]
  for u in found do
    unless u == home do
      failures := failures.push s!"{u} mentions Ran.mk: the only mint of Ran is the live shim in receiverVerifier (a forged proof of the process-answered fact)"
  unless found.contains home do
    failures := failures.push s!"{home} no longer mentions Ran.mk: the census is stale (the live shim moved)"
  unless failures.isEmpty do
    for f in failures do logError f
    throwError s!"ran-mint census: {failures.size} failure(s)"

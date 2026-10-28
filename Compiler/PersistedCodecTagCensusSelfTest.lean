/- Teeth of the persisted-codec census's structural hashing (`Compiler.PersistedCodecTagCensus`,
`isCompilerAux` / `auxStructural` / `declarationHash`), as built checks: this module fails to build if
(a) renumbering a compiler auxiliary moves a hash, (b) changing an auxiliary's structure does NOT move it
(directly, or through an auxiliary nested inside another), or (c) a user-named constant stops contributing
its name. Name-insensitive for compiler numbering only, never for structure. Built by `CensusChecks`. -/
import Compiler.PersistedCodecTagCensus

namespace Minidregg.Compiler.PersistedCodecTagCensusSelfTest
open Lean Elab Command Minidregg.Compiler.PersistedCodecTagCensus

private def natFn : Expr := .forallE `n (.const ``Nat []) (.const ``Nat []) .default
private def addK (k : Nat) : Expr :=
  .lam `n (.const ``Nat []) (mkApp2 (.const ``Nat.add []) (.bvar 0) (mkNatLit k)) .default
private def callOf (f : Name) : Expr := .lam `n (.const ``Nat []) (.app (.const f []) (.bvar 0)) .default
private def define (n : Name) (type value : Expr) : CommandElabM Unit :=
  liftCoreM <| addDecl (.defnDecl { name := n, levelParams := [], type, value, hints := .opaque, safety := .safe })

run_cmd do
  let p := `Minidregg.Compiler.PersistedCodecTagCensusSelfTest.T
  -- the same auxiliary under two numberings, and one with a different structure
  define (p ++ `f ++ `match_1) natFn (addK 1)
  define (p ++ `g ++ `match_7) natFn (addK 1)
  define (p ++ `h ++ `match_2) natFn (addK 2)
  -- auxiliaries nested in auxiliaries (recursion: a nested auxiliary contributes ITS structure)
  define (p ++ `k ++ `match_3) natFn (callOf (p ++ `f ++ `match_1))
  define (p ++ `k ++ `match_9) natFn (callOf (p ++ `g ++ `match_7))
  define (p ++ `k ++ `match_4) natFn (callOf (p ++ `h ++ `match_2))
  -- user-named constants with equal values
  define (p ++ `userA) natFn (addK 1)
  define (p ++ `userB) natFn (addK 1)
  -- referrers: the hashed codec-like definitions
  for (r, f) in [(`r1, p ++ `f ++ `match_1), (`r2, p ++ `g ++ `match_7), (`r3, p ++ `h ++ `match_2),
                 (`r4, p ++ `k ++ `match_3), (`r5, p ++ `k ++ `match_9), (`r6, p ++ `k ++ `match_4),
                 (`r7, p ++ `userA), (`r8, p ++ `userB)] do
    define (p ++ r) natFn (callOf f)
  let env ← getEnv
  let h := fun (r : Name) => declarationHash env (p ++ r)
  unless isCompilerAux (p ++ `f ++ `match_1) && isCompilerAux (p ++ `x ++ `_sparseCasesOn_2) &&
      isCompilerAux (p ++ `x ++ `_proof_5) && !isCompilerAux (p ++ `userA) do
    throwError "census selftest: isCompilerAux classifies wrongly"
  unless h `r1 == h `r2 do throwError "census selftest (a): renumbering an auxiliary moved the hash"
  unless h `r1 != h `r3 do throwError "census selftest (b): changing an auxiliary's structure did not move the hash"
  unless h `r4 == h `r5 do throwError "census selftest (a, nested): renumbering a nested auxiliary moved the hash"
  unless h `r4 != h `r6 do throwError "census selftest (b, nested): a nested auxiliary's structure did not move the hash"
  unless h `r7 != h `r8 do throwError "census selftest (c): a user-named constant no longer contributes its name"
  logInfo "census selftest: (a) renumbering is invisible, (b) structure moves the hash (also nested), (c) user names count"

end Minidregg.Compiler.PersistedCodecTagCensusSelfTest

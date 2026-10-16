/-
# TokenCensus — every private constructor, minted only at home, every row reviewed

Runs `#assert_token_census` (checks 1, 2, 3, 5, 6 of `TokenCensus.Core`) over the
research umbrella (`AxiomCensusResearch`: Minidregg and every Host module but the
other exe roots) and `ObjectiveProofs`, against `TokenCensus.Table`.  The per-row
planted forgeries (check 4) live in `TokenCensus.SelfTest`.
-/
import AxiomCensusResearch
import ObjectiveProofs
import TokenCensus.Core
import TokenCensus.Table

namespace Minidregg.TokenCensus

open Lean Elab Command Meta

/-! A positive control for check 3.  `sound'` is intentionally nothing but a
proof-field projection: this is the good construction the former rule rejected. -/

structure ProjectionWitness (request result : Nat) where
  private mk ::
  sound : request = 0 ∧ result = 0

theorem ProjectionWitness.sound' {request result : Nat}
    (witness : ProjectionWitness request result) : request = 0 ∧ result = 0 :=
  witness.sound

#assert_axioms ProjectionWitness.sound'

-- A scan of every constant: its cost is the size of the tree, not a proof search. Each
-- constant's inspection runs from a fresh heartbeat count (`perConstant`) and each L1
-- witness under its own budget (`l1WitnessFaults`); there is no unbounded `maxHeartbeats 0`.
#assert_token_census Minidregg.TokenCensus.table

end Minidregg.TokenCensus

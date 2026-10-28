/-
# TokenCensus.SelfTest — the census instrument detects what it claims to

A planted forgery for EVERY private constructor (and a planted call for every
restricted minting function) must be flagged by the census' own checks.  This tests
the instrument, not the tree: the merge gate builds it only when `TokenCensus.Core`,
this module or the plant script change.
-/
import TokenCensus

namespace Minidregg.TokenCensus

-- each plant runs from a fresh heartbeat count (`perConstant`); no unbounded `maxHeartbeats 0`
#assert_token_census_plants Minidregg.TokenCensus.table

/-! ### Check 6 against a builder hidden behind a consumer

The inferred-index rule skips an implicit argument a CONSUMER reads off the type of an explicit one
(the `V` of `Receiver.intent (R : Receiver J V)`).  A module outside the allow-list that BUILDS the
family value itself, naming the restricted function at construction and then handing it to such a
consumer, must still be flagged at the construction site; a module that only consumes a value of
that type must not be. -/

namespace Check6Plant

def restrictedPlant (n : Nat) : Nat := n

structure Box (v : Nat) where
  val : Fin (v + 1)

def Box.read {v : Nat} (box : Box v) : Nat := box.val

/-- Builds `Box (restrictedPlant 0)` itself, then hands it to the consumer. -/
def builder : Nat := Box.read (v := restrictedPlant 0) ⟨⟨0, Nat.succ_pos _⟩⟩

/-- Only consumes a value of that type. -/
def consumer (box : Box (restrictedPlant 0)) : Nat := box.read

open Lean Meta Elab Command in
run_cmd liftTermElabM do
  let check (name : Name) : MetaM Bool := do
    restrictedCall ``restrictedPlant [`Kernel.Receiving] name (← getConstInfo name)
  unless ← check ``builder do
    throwError "check 6 self-test: a builder that names the restricted function at construction was NOT flagged"
  if ← check ``consumer then
    throwError "check 6 self-test: a pure consumer of the family value WAS flagged"
  logInfo "check 6 self-test: the builder is flagged at its construction site; the consumer is not"

end Check6Plant

end Minidregg.TokenCensus

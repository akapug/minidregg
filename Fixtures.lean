/-
# Fixtures -- recorded runs, replayed in Lean

A module here re-runs something a native process DID (a recorded world, a Store
prefix, a signed byte string) through this tree's code and checks it. Its data is
regenerated from a run, so it goes red whenever the implementation moves under
it, and stays red until the run is re-recorded.

That is why it is its own library. Nothing the deployed system is, and nothing a
census checks the tree with (`AxiomCensus`, `AxiomCensusResearch`,
`TokenCensus`), imports it: a stale recording cannot hide a census verdict. The
umbrella target list (`scripts/pipeline/umbrella-targets`) builds it explicitly,
and `TokenCensus.Fixtures` runs the token census over its modules.
-/
import Fixtures.NativeAcceptedFixture
import Fixtures.NativeDocWriteFixture
import Fixtures.BirthPlanPoles

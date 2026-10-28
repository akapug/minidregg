/-
The expected app state for a future checked dispatch receiver. The app is
observed under a current signed read grant and added as a durable read guard;
its lifecycle page is not mutated by a participant's request. This candidate
comparison is not delivery authority. The durable special event/nullifier
retains the complete pending request, without a bounded content atom.
-/
module

public import Kernel.ApplicationGrain
public import Kernel.ApplicationDispatchIngress

-- Bodies this file reduces or derives through, not exposed by their modules (module system).
import all Init.Data.Repr
import all Init.Data.ToString.Basic
import all Init.Data.ToString.Extra
import all Init.Data.Array.Basic
import all Init.Data.ByteArray.Basic
import all Init.Data.String.Decode
import all Init.Data.String.Defs
import all Init.Control.Except
import all Init.Data.List.Basic
import all Init.Data.Nat.Bitwise.Basic
import all Init.Data.String.Bootstrap
import all Init.Data.Format.Basic
import all Init.Data.List.Scan.Basic

@[expose] public section

namespace Minidregg.Kernel.ApplicationDispatchWitness

open Minidregg.Compiler
open Minidregg.Kernel.ApplicationDispatchCodec

set_option autoImplicit false

/-- The app phase is fixed at serving. The future native observation receiver
must parse all four coordinates from its actual loaded app page, then compare
to this value and guard that exact root in the same durable intent. -/
def servingState (dispatch : Dispatch) : ApplicationGrain.State where
  generation := dispatch.app.generation
  phase := 4
  packageVersion := dispatch.app.packageVersion
  snapshotVersion := dispatch.app.snapshotVersion

def matchesServing (dispatch : Dispatch) (actual : ApplicationGrain.State) : Bool :=
  decide (actual = servingState dispatch)

theorem matchesServing_exact (dispatch : Dispatch) (actual : ApplicationGrain.State)
    (accepted : matchesServing dispatch actual = true) :
    actual = servingState dispatch := by
  simpa [matchesServing] using accepted

end Minidregg.Kernel.ApplicationDispatchWitness

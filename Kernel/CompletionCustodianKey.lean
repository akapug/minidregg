/-
# Kernel.CompletionCustodianKey — the completion custodian key, read from the platform cell

The four lifecycle completion admissions (launch completion, completion v2, retry completion
v4, failed-start recovery) verify a physical report under the completion custodian key. That
key is the platform record's (`PlatformCellLayout.Platform.completionCustodianKey`), read on
the very ground the completion's guards are taken on (`Ground.view`), and the platform cell's
root on that ground is one of the completion's read guards: an install that rotates the key
between preparation and commit makes the completion stale.

A light ground's cells are its served state's whole cell state; its basis keys name only
transactions and nullifiers, so the record read does not depend on them
(`recordOn_light_keys`).
-/
import Compiler.ServedBasis
import Kernel.PlatformCellDomain

namespace Minidregg.Kernel.CompletionCustodianKey

open Minidregg.Compiler
open Minidregg.Compiler.ServedBasis (Ground Basis)
open Minidregg.Kernel.DurableDataIntent

set_option autoImplicit false

variable {deployment : CanonicalCellRegistry.Deployment}

/-- The custodian key a completion is verified under: the platform record on `ground`'s
state, and that record's key. The constructor is private: `select` is the only route. -/
structure Read (deployment : CanonicalCellRegistry.Deployment) (ground : Ground deployment) where
  private mk ::
  loaded : PlatformCellDomain.Loaded deployment ground.view
  record : PlatformCellLayout.Platform
  recordExact : PlatformCellLayout.recordOf loaded.cell.logical = some record
  key : List UInt8
  keyPinned : record.completionCustodianKey = some key

inductive Reject where
  /-- The ground holds no live platform cell, or the cell holds no record. -/
  | platformUnavailable
  /-- The platform record names no completion custodian key. -/
  | keyUnavailable
  deriving DecidableEq, Repr

def Reject.describe : Reject → String
  | .platformUnavailable => "platform cell unavailable (completion custodian key)"
  | .keyUnavailable => "physical custodian key unavailable in the platform record"

def select (deployment : CanonicalCellRegistry.Deployment) (ground : Ground deployment) :
    Except Reject (Read deployment ground) :=
  match PlatformCellDomain.load deployment ground.view with
  | none => .error .platformUnavailable
  | some loaded =>
      match recorded : PlatformCellLayout.recordOf loaded.cell.logical with
      | none => .error .platformUnavailable
      | some record =>
          match pinned : record.completionCustodianKey with
          | none => .error .keyUnavailable
          | some key => .ok ⟨loaded, record, recorded, key, pinned⟩

/-- The platform cell as the completion's read dependency, at `ground`'s root. -/
def Read.guard {ground : Ground deployment} (read : Read deployment ground) : ReadGuard :=
  read.loaded.readGuard

theorem Read.guard_cellId {ground : Ground deployment} (read : Read deployment ground) :
    read.guard.cellId = PlatformCellDomain.cellIdOf deployment := rfl

theorem Read.guard_current {ground : Ground deployment} (read : Read deployment ground) :
    read.guard.expectedRoot = ground.view.model.roots read.guard.cellId := rfl

/-- **The key is the record's on the ground.** -/
theorem Read.current {ground : Ground deployment} (read : Read deployment ground) :
    PlatformCellDomain.recordOn deployment ground.view = some read.record ∧
      read.record.completionCustodianKey = some read.key := by
  refine ⟨?_, read.keyPinned⟩
  have exact := read.loaded.observed
  unfold PlatformCellDomain.recordOn PlatformCellDomain.load
  split
  · rename_i decoded
    rw [exact, PlatformCellDomain.decodeCell_bytes] at decoded
    cases decoded
  · rename_i cell decoded
    rw [exact, PlatformCellDomain.decodeCell_bytes] at decoded
    cases decoded
    exact read.recordExact

/-- **Teeth: no other key.** Any key that is not the platform record's on the ground (the
genesis config's key after a rotating install, say) is not the key of any `Read`. -/
theorem Read.stale {ground : Ground deployment} (read : Read deployment ground) (k : List UInt8)
    (other : (PlatformCellDomain.recordOn deployment ground.view).bind
      (·.completionCustodianKey) ≠ some k) : read.key ≠ k := by
  intro same
  apply other
  rw [read.current.1, ← same]
  exact read.current.2

/-- **Teeth: an absent platform cell refuses by name.** -/
theorem select_unavailable (ground : Ground deployment)
    (absent : PlatformCellDomain.load deployment ground.view = none) :
    select deployment ground = .error .platformUnavailable := by
  unfold select
  split
  · rfl
  · rename_i loaded found
    rw [absent] at found
    cases found

/-- Satisfiable pole: a ground whose platform record pins a key selects exactly that key. -/
theorem select_pinned (ground : Ground deployment) (record : PlatformCellLayout.Platform)
    (key : List UInt8) (recorded : PlatformCellDomain.recordOn deployment ground.view = some record)
    (pinned : record.completionCustodianKey = some key) :
    ∃ read, select deployment ground = .ok read ∧ read.record = record ∧ read.key = key := by
  unfold PlatformCellDomain.recordOn at recorded
  unfold select
  cases found : PlatformCellDomain.load deployment ground.view with
  | none => rw [found] at recorded; cases recorded
  | some loaded =>
      rw [found] at recorded
      simp only [Option.bind_some] at recorded
      split
      · rename_i none' _; cases none'
      · rename_i loaded' same
        cases same
        split
        · rename_i missing; rw [recorded] at missing; cases missing
        · rename_i record' recorded'
          rw [recorded] at recorded'
          cases recorded'
          split
          · rename_i missing; rw [pinned] at missing; cases missing
          · rename_i key' pinned'
            rw [pinned] at pinned'
            cases pinned'
            exact ⟨_, rfl, rfl, rfl⟩

/-- **The light read is key-independent**: two bases over the same served state read the
same platform record whatever keys they declare (a basis's keys name only transactions and
nullifiers; its cells are the served state's). -/
theorem recordOn_light_keys {store : Minidregg.Compiler.DurableHistory.StoreIdentity}
    (a b : Basis deployment store) (same : a.served = b.served) :
    PlatformCellDomain.recordOn deployment (Ground.ofBasis a).view =
      PlatformCellDomain.recordOn deployment (Ground.ofBasis b).view := by
  apply PlatformCellDomain.recordOn_congr
  show a.view.canonicalBytes _ = b.view.canonicalBytes _
  rw [Basis.view_canonicalBytes, Basis.view_canonicalBytes, same]

#assert_axioms Read.current
#assert_axioms Read.stale
#assert_axioms select_unavailable
#assert_axioms select_pinned
#assert_axioms recordOn_light_keys

end Minidregg.Kernel.CompletionCustodianKey

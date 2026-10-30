/-
Conditional original-BEGIN admission for a later lifecycle claim. The original
record and its exact prefix state are read from the Store's authenticated
history (`NativeHistorySelection.select`: the record verified at height
`index + 1`, the prior state `Reader.stateAt index` served as a basis under the
same head), and the original BEGIN is freshly re-admitted on that prior state.
This is not a trusted history witness or a launch permit. The upper adapter
must also select the same step from `NativeHostReplay.Verified`.
-/
module

public import Kernel.ApplicationLifecycleClaimIngress
public import Kernel.ApplicationLifecycleBeginReceiver
public import Kernel.NativeHistorySelection

@[expose] public section

namespace Minidregg.Kernel.ApplicationLifecycleClaimHistory

open Minidregg.Compiler
open Minidregg.Kernel.NativeHost
open Minidregg.Kernel.NativeHistorySelection
open Minidregg.Kernel.ApplicationLifecycleClaim
open Minidregg.Compiler.DurableHistory (Head StoreIdentity)
open Minidregg.Compiler.DurableHistoryReader (Reader)

set_option autoImplicit false

structure Conditional (config : Config) {store : StoreIdentity} (head : Head store)
    (source : Source) where
  private mk ::
  selected : Candidate config head source.originalIndex
  admitted : ApplicationLifecycleBeginReceiver.Accepted config.deployment config.profile
    ⟨config.federation, config.genesisHeight + selected.ground.height⟩
    selected.ground source.begin
  exact : Matched selected admitted.intent

/-- The original record is equal to the full source-admitted BEGIN intent,
including its event, reads, writes, charges and nullifier. -/
theorem Conditional.original_record_exact {config : Config} {store : StoreIdentity}
    {head : Head store} {source : Source} (conditional : Conditional config head source) :
    conditional.selected.record =
      DurableReceiver.IntentRecord.ofIntent conditional.admitted.intent := by
  exact conditional.exact.selected.symm.trans conditional.exact.exact

/-- The original record is the one verified under `head` at height
`source.originalIndex + 1` (`Included` in the head's frontier) and it decodes to
exactly the record of the re-admitted original BEGIN, whose ingress is
`source.begin` under `config`'s domain and semantics. -/
theorem Conditional.original_under_head {config : Config} {store : StoreIdentity}
    {head : Head store} {source : Source} (conditional : Conditional config head source) :
    (∃ bytes chain root,
      DurableHistory.Included head.frontier head.height (source.originalIndex + 1) bytes chain root ∧
        DurableCheckpointCodec.recordFrame.decode bytes =
          some (DurableReceiver.IntentRecord.ofIntent conditional.admitted.intent)) ∧
      source.begin.domain = config.deployment.domain ∧
      source.begin.semantics = config.profile.semantics :=
  ⟨⟨conditional.selected.read.verified.record, conditional.selected.read.verified.chain,
      conditional.selected.read.verified.root, conditional.selected.read.verified.included,
      conditional.selected.read.decoded.trans (congrArg some (conditional.selected.recordExact.trans
        (NativeHistorySelection.Matched.candidateRecord conditional.exact)))⟩,
    conditional.admitted.profileExact.1, conditional.admitted.profileExact.2⟩

/-- The keys the original BEGIN reads on its prior state. -/
def keys (source : Source) : DurableView.Keys :=
  ApplicationLifecycleBeginReceiver.keys source.begin

def admit (config : Config) {store : StoreIdentity} (reader : Reader ResourceBirthCodec.rootBytes store)
    (bound : Nat) (source : Source) :
    IO (Except String (Conditional config reader.head source)) := do
  let selected ← match ← NativeHistorySelection.select config reader bound source.originalIndex
      (keys source) with
    | .error detail => return .error detail
    | .ok selected => pure selected
  let ambient : DeclaredResourceController.Ambient :=
    ⟨config.federation, config.genesisHeight + selected.ground.height⟩
  let admitted ← match ← ApplicationLifecycleBeginReceiver.admitLoaded
      config.deployment config.profile ambient config.signature selected.ground
      source.begin with
    | .error detail => return .error s!"original lifecycle begin refused: {detail}"
    | .ok admitted => pure admitted
  match NativeHistorySelection.matchIntent selected admitted.intent with
  | .error detail => return .error detail
  | .ok exact => return .ok ⟨selected, admitted, exact⟩

end Minidregg.Kernel.ApplicationLifecycleClaimHistory

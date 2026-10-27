import Compiler.DurableFastForwardSpec

/-!
# The fast-forward open: proofs toward `Spec` (HOT-PATH §2(h))

The snapshot clause of `Spec.exact`, from the resume theorems the open already rests on.
-/

namespace Minidregg.Compiler.DurableFastForwardSpec

open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.DurableReceiver
open Minidregg.Kernel.DurableCheckpoint

set_option autoImplicit false

variable {rootBytes : List UInt8 → Digest}

/-- **The executed head state over the records is the resumed snapshot**: whatever height a
resume starts from (a checkpoint, or genesis), the snapshot it reaches is the snapshot of its own
head state (`State.ofSnapshot`, the executed part) over every record (journal, history and
consumed set from the records, the non-executing part). -/
theorem headState_snapshot {image : Image} {height : Nat} {state : State}
    {snapshot : DataSnapshot rootBytes} (resumed : resume rootBytes image height state = some snapshot) :
    (State.ofSnapshot image snapshot).snapshot rootBytes image.accepted = snapshot := by
  have rebased := DurableEngine.resume_rebase resumed
  unfold resume at rebased
  rw [if_pos (ofSnapshot_admissible _ _), List.drop_length, List.take_length] at rebased
  simpa [DurableReceiver.replay] using rebased

/-- **An honest checkpoint resumes to the genesis replay**: a checkpoint state whose snapshot over
the prefix is the replay of the prefix (`Body4.Honest.state`), admissible for the whole image,
resumes over the suffix to the replay of the whole log. -/
theorem resume_honest {seed : Seed} {pre suf : List IntentRecord} {state : State}
    (seedValid : (seed.cells.map Prod.fst).Nodup)
    (admissible : state.Admissible ⟨seed, pre ++ suf⟩)
    (honest : replaySnapshot rootBytes ⟨seed, pre⟩ = some (state.snapshot rootBytes pre)) :
    resume rootBytes ⟨seed, pre ++ suf⟩ pre.length state = replaySnapshot rootBytes ⟨seed, pre ++ suf⟩ := by
  have prefixReplay : replay rootBytes (seed.snapshot rootBytes) pre = some (state.snapshot rootBytes pre) := by
    unfold replaySnapshot at honest
    rw [resume_genesis] at honest
    unfold Image.restore at honest
    simpa [if_pos seedValid] using honest
  unfold replaySnapshot
  rw [resume_genesis]
  apply resume_sound rootBytes ⟨seed, pre ++ suf⟩ pre.length state (state.snapshot rootBytes pre) seedValid
    admissible
  · simpa [List.take_left'] using prefixReplay
  · simp

#assert_axioms headState_snapshot
#assert_axioms resume_honest

end Minidregg.Compiler.DurableFastForwardSpec

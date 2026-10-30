/-
# How the stdio session answers a request that ended in an exception

`serveSession` answers every frame. A handler that throws instead of returning
its own answer is answered here, and the loop keeps serving:

* a request whose client bytes its operation's grammar refuses is thrown as
  `malformed detail` and answered `refused malformed` (phase `op N`). The detail
  is the decoder's position or field name — a fact about bytes the client sent,
  so it is within the pre-signature disclosure rule (a challenge publishes
  nothing the client does not already hold about its own frame);
* a frame past a static bound (`Kernel.Bounds`) is thrown as `overBound r` and
  answered `refused overBound` (phase `op N`) with `over-bound NAME VALUE > LIMIT`
  — a fact about the frame's length header, which the client sent;
* any other exception is answered `refused operationRejected` (phase `op N`)
  with its text, as the fn session dispatcher already answers its own failures.

Two cases are not answered here and still end the process, because the Host's
own state, not the request, decided them (`Main.serveSession`): a poisoned
session (a Store read, chain, tag or replay failure; a new process must reopen
from the MAC'd checkpoint) and a handler that throws after its reply frame has
already been written (a second frame would desynchronise the pipe).
`mini serve` restarts the Host in both cases.
-/
module

public import Compiler.NativeHostCodec
public import Compiler.NativeHostEffectClass
public import Host.HostOperations
public import Kernel.Bounds
public import Theory.AssertAxioms

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
import all Init.System.ST
import all Init.System.IO

@[expose] public section

namespace Minidregg.Host.RequestRefusal

open Minidregg.Compiler
open Minidregg.Compiler.NativeHostCodec

/-- The `IO.Error` filename slot that marks a malformed request. OS errors carry
a real path or `none` there; only `malformed` constructs this one. -/
def tag : String := "minidregg-host request"

/-- Thrown by a decoder when a request's client bytes fail its grammar. -/
def malformed (detail : String) : IO.Error :=
  .invalidArgument (some tag) 0 detail

/-- The `IO.Error` filename slot that marks a request past a static bound; only
`overBound` constructs it. -/
def boundTag : String := "minidregg-host bound"

/-- Thrown when a request is past a static bound (`Kernel.Bounds.check`). -/
def overBound (refusal : Kernel.Bounds.Refusal) : IO.Error :=
  .invalidArgument (some boundTag) 0 refusal.render

/-- Lift a decoder's verdict on client bytes into the session monad. -/
def clientBytes {ε α : Type} [ToString ε] (decoded : Except ε α) : IO α :=
  match decoded with
  | .ok value => pure value
  | .error detail => throw (malformed (toString detail))

/-- A refusal detail is at most this many characters, so the answer frame stays
far inside the Host frame bound whatever the exception text quotes. -/
def maxDetailChars : Nat := 1024

def phase (operation : UInt8) : List UInt8 := s!"op {operation}".toUTF8.toList

def clip (text : String) : List UInt8 := (String.ofList (text.toList.take maxDetailChars)).toUTF8.toList

/-- The answer to a request whose handler threw `error`. -/
def answer (operation : UInt8) (error : IO.Error) : Outcome :=
  match error with
  | .invalidArgument (some marker) _ detail =>
      if marker = tag then .refused .malformed (phase operation) (clip detail)
      else if marker = boundTag then .refused .overBound (phase operation) (clip detail)
      else .refused .operationRejected (phase operation) (clip (toString error))
  | other => .refused .operationRejected (phase operation) (clip (toString other))

/-- The frame payload `serveSession` writes under response operation 255. -/
def frame (operation : UInt8) (error : IO.Error) : List UInt8 :=
  outcomeCodec.encode (answer operation error)

/-- A malformed request is answered `refused malformed`, phase `op N`, with the
decoder's own detail. -/
theorem answer_malformed (operation : UInt8) (detail : String) :
    answer operation (malformed detail) =
      .refused .malformed (phase operation) (clip detail) := by
  simp [answer, malformed]

/-- A request past a static bound is answered `refused overBound`, phase `op N`,
with the bound's name, the value and the limit. -/
theorem answer_overBound (operation : UInt8) (refusal : Kernel.Bounds.Refusal) :
    answer operation (overBound refusal) =
      .refused .overBound (phase operation) (clip refusal.render) := by
  simp [answer, overBound, tag, boundTag]

/-- Every exception is answered by a refusal for that operation: never a
confirmation, never contention, unavailable or uncertain. -/
theorem answer_refused (operation : UInt8) (error : IO.Error) :
    ∃ reason detail, answer operation error = .refused reason (phase operation) detail := by
  unfold answer
  split
  · split
    · exact ⟨_, _, rfl⟩
    · split
      · exact ⟨_, _, rfl⟩
      · exact ⟨_, _, rfl⟩
  · exact ⟨_, _, rfl⟩

/-- The written frame decodes, under the current outcome version, to exactly
that refusal: the client reads the reason the Host chose. -/
theorem frame_decodes (operation : UInt8) (error : IO.Error) :
    outcomeCodec.decode (frame operation error) = some (answer operation error) :=
  outcomeCodec.decode_encode _

/-- The session operation a one-shot pure codec verb (`HOST CONFIG author KIND IN OUT`
and its siblings) is the argv form of. These read no Store and commit nothing: their
only effect is the named output file. -/
def oneShotOperation : List String → Option UInt8
  | _ :: "author" :: _ => some 7
  | _ :: "inspect" :: _ => some 8
  | _ :: "signatures" :: _ => some 9
  | _ :: "observe-assemble" :: _ => some 10
  | _ :: "assemble" :: _ => some 11
  | _ => none

/-- The answer to a one-shot pure verb that ended in an exception. A verb that reads no
Store cannot have been accepted by anything, so its end is always a definite refusal,
never an uncertain status. A grammar verdict on the client bytes (`IO.userError`, the
decoders' `Except String`) is `malformed`, as in the session; any other exception is
answered by `answer`, the session's own mapping. -/
def oneShotAnswer (operation : UInt8) (error : IO.Error) : Outcome :=
  match error with
  | .userError message => .refused .malformed (phase operation) (clip message)
  | other => answer operation other

/-- The encoded outcome a one-shot pure verb writes to stdout when it refuses. -/
def oneShotFrame (operation : UInt8) (error : IO.Error) : List UInt8 :=
  outcomeCodec.encode (oneShotAnswer operation error)

theorem oneShotAnswer_userError (operation : UInt8) (message : String) :
    oneShotAnswer operation (.userError message) =
      .refused .malformed (phase operation) (clip message) := rfl

/-- A one-shot pure verb's end is a refusal for that operation: never a confirmation,
contention, unavailable or uncertain. -/
theorem oneShotAnswer_refused (operation : UInt8) (error : IO.Error) :
    ∃ reason detail, oneShotAnswer operation error = .refused reason (phase operation) detail := by
  unfold oneShotAnswer
  split
  · exact ⟨_, _, rfl⟩
  · exact answer_refused operation _

theorem oneShotFrame_decodes (operation : UInt8) (error : IO.Error) :
    outcomeCodec.decode (oneShotFrame operation error) = some (oneShotAnswer operation error) :=
  outcomeCodec.decode_encode _

/-! ## The answer discipline: NO_RECORD (253) against the undecided envelope (255)

Until lane/lean-critical the session answered EVERY thrown handler `255 refused`
(`answer`), and so did the fn dispatcher's catch (`"fn-session"`), while 255 also
carried `unavailable` (session invalidated), `uncertain` and `contention` (op 125).
Four client sites read the byte 255 as "refused, author a fresh attempt"
(resource-client §4.7; SYNTHESIS §B row 4). The discipline below makes the byte
honest by making it say less and the payload say more:

* **`NO_RECORD` (`HostOperations.noRecordMarker`, 253)** carries a `refused`
  outcome and is answered ONLY when the request provably left no record:
  (i) a grammar verdict on the client's own bytes (`malformed`, `overBound`:
  constructed by this module alone, raised by the Host's decoders before any
  receiver runs; no module under `Kernel/` or `Compiler/` imports this file);
  (ii) a handler of an operation the registry declares append-free
  (`protocol/host-operations.json` `effect: none`, generated into
  `HostOperations.noAppendOperations`) that threw; (iii) a `refused` outcome a
  handler RETURNED under 255, i.e. a receiver's own `rejected`, which the durable
  receiver decides with no transport effect
  (`DurableReceiverIO.receiveCandidateWithFresh_rejected_at_prepare` /
  `_at_judge`).
* **NO_RECORD also carries a receiver's `contention` or `unavailable`** returned
  as a value: the durable receiver decides both before any append
  (`DurableReceiverIO.publishAfter_conflict`: a conflicting append writes nothing;
  every `unavailable` arm of `receiveCandidateWithFresh` precedes `publish`), and so
  does the dispatch receiver (`ApplicationDispatchReceiver.receiveVerified`, whose
  `contention`/`unavailable` arms precede the permit). The grain fence (spk-host)
  settles a dispatch on this frame.
* **255 (`hostRefusalMarker`)** carries only undecided outcomes: `uncertain`, a
  handler of an append operation that threw a non-grammar error (answered
  `uncertain`, "look up the exact call"), and the Host's own
  `unavailable "host session reopening"`, which `serveFrame` writes directly and
  never passes through `returnedMarker`.

The theorems: `exceptionAnswer_class` (a thrown handler is answered either
no-record under 253 or undecided under 255, never otherwise),
`exceptionAnswer_noRecord_sound` (253 only on (i) or (ii)),
`returnedMarker_noRecord_refused` / `returnedMarker_hostOutcome_undecided` (the
value path), and the teeth pair `exceptionAnswer_submit_fault_undecided` (the
previous mapping classes a submit fault as a refusal; this one does not). What
is NOT a theorem and is confessed as such: that every receiver's `refused`
value is decided before its append (true of the durable receiver by the two
theorems above; a per-receiver audit for the others), and that the registry's
`effect: none` set is correct (a declaration, checked by reading the arms). -/

/-- A grammar verdict on the client's own bytes: only `malformed` and `overBound`
construct these errors. -/
def grammarVerdict : IO.Error → Bool
  | .invalidArgument (some marker) _ _ => marker == tag || marker == boundTag
  | _ => false

/-- Whether the registry declares `operation`'s receiver append-free. -/
def noAppend (operation : UInt8) : Bool :=
  HostOperations.noAppendOperations.contains operation

/-- The detail of an undecided answer to a thrown handler. -/
def undecidedDetail (operation : UInt8) (error : IO.Error) : List UInt8 :=
  clip s!"op {operation}: handler ended by exception after dispatch; look up the exact call: {error}"

/-- The reply (response byte, payload) to a request whose handler threw `error`. -/
def exceptionAnswer (operation : UInt8) (error : IO.Error) : UInt8 × List UInt8 :=
  if grammarVerdict error || noAppend operation then
    (HostOperations.noRecordMarker, frame operation error)
  else
    (HostOperations.hostOutcomeMarker,
      outcomeCodec.encode (.uncertain (undecidedDetail operation error)))

/-- The outcomes a receiver decides before any append: a refusal, contention (a
conflicting append writes nothing) and unavailability (decided before `publish`). -/
def noRecordPayload : Outcome → Bool
  | .refused .. => true
  | .contention => true
  | .unavailable _ => true
  | _ => false

/-- The response byte for a handler that RETURNED `(responseOperation, payload)`:
a no-record outcome returned under 255 is a receiver's decision and goes out as
NO_RECORD; every other 255 payload stays undecided; an operation's own frame is
untouched. -/
def returnedMarker (responseOperation : UInt8) (payload : List UInt8) : UInt8 :=
  if responseOperation == HostOperations.hostOutcomeMarker then
    match outcomeCodec.decode payload with
    | some outcome => if noRecordPayload outcome then HostOperations.noRecordMarker
        else HostOperations.hostOutcomeMarker
    | none => HostOperations.hostOutcomeMarker
  else responseOperation

theorem exceptionAnswer_cases (operation : UInt8) (error : IO.Error) :
    exceptionAnswer operation error = (HostOperations.noRecordMarker, frame operation error) ∨
    exceptionAnswer operation error = (HostOperations.hostOutcomeMarker,
      outcomeCodec.encode (.uncertain (undecidedDetail operation error))) := by
  unfold exceptionAnswer
  split <;> simp

/-- A thrown handler is answered a no-record refusal under NO_RECORD or an undecided
outcome under 255: never a refusal under 255, never an undecided outcome under NO_RECORD. -/
theorem exceptionAnswer_class (operation : UInt8) (error : IO.Error) (outcome : Outcome)
    (decoded : outcomeCodec.decode (exceptionAnswer operation error).2 = some outcome) :
    ((exceptionAnswer operation error).1 = HostOperations.noRecordMarker ∧
        outcome.effectClass = .noRecord) ∨
    ((exceptionAnswer operation error).1 = HostOperations.hostOutcomeMarker ∧
        outcome.effectClass = .undecided) := by
  rcases exceptionAnswer_cases operation error with e | e <;> rw [e] at decoded ⊢
  · left
    refine ⟨rfl, ?_⟩
    simp only [frame_decodes, Option.some.injEq] at decoded
    obtain ⟨reason, detail, answered⟩ := answer_refused operation error
    rw [← decoded, answered]
    rfl
  · right
    refine ⟨rfl, ?_⟩
    rw [outcomeCodec.decode_encode, Option.some.injEq] at decoded
    rw [← decoded]
    rfl

/-- NO_RECORD for a thrown handler needs a grammar verdict or an append-free operation. -/
theorem exceptionAnswer_noRecord_sound (operation : UInt8) (error : IO.Error)
    (marked : (exceptionAnswer operation error).1 = HostOperations.noRecordMarker) :
    grammarVerdict error = true ∨ noAppend operation = true := by
  unfold exceptionAnswer at marked
  split at marked
  · rename_i condition
    simpa [Bool.or_eq_true] using condition
  · exact absurd marked (by dsimp only; decide)

/-- The undecided envelope for a thrown handler means neither held. -/
theorem exceptionAnswer_undecided_sound (operation : UInt8) (error : IO.Error)
    (marked : (exceptionAnswer operation error).1 = HostOperations.hostOutcomeMarker) :
    grammarVerdict error = false ∧ noAppend operation = false := by
  unfold exceptionAnswer at marked
  split at marked
  · exact absurd marked (by dsimp only; decide)
  · rename_i condition
    simp only [Bool.or_eq_true, not_or, Bool.not_eq_true] at condition
    exact condition

/-- A returned frame goes out as NO_RECORD only when it was a no-record outcome
(refused, contention or unavailable) under 255. -/
theorem returnedMarker_noRecord_sound (responseOperation : UInt8) (payload : List UInt8)
    (own : responseOperation ≠ HostOperations.noRecordMarker)
    (marked : returnedMarker responseOperation payload = HostOperations.noRecordMarker) :
    responseOperation = HostOperations.hostOutcomeMarker ∧
      ∃ outcome, outcomeCodec.decode payload = some outcome ∧ noRecordPayload outcome = true := by
  unfold returnedMarker at marked
  split at marked
  · rename_i envelope
    refine ⟨by simpa using envelope, ?_⟩
    split at marked
    · rename_i outcome decoded
      split at marked
      · exact ⟨outcome, decoded, by assumption⟩
      · exact absurd marked (by decide)
    · exact absurd marked (by decide)
  · exact absurd marked own

/-- A payload that stays under 255 is never a refusal, contention or unavailability:
it is uncertain (or a receipt no site returns under 255). -/
theorem returnedMarker_hostOutcome_undecided (payload : List UInt8) (outcome : Outcome)
    (kept : returnedMarker HostOperations.hostOutcomeMarker payload = HostOperations.hostOutcomeMarker)
    (decoded : outcomeCodec.decode payload = some outcome) :
    noRecordPayload outcome = false := by
  cases h : noRecordPayload outcome
  · rfl
  · simp [returnedMarker, decoded, h, HostOperations.noRecordMarker,
      HostOperations.hostOutcomeMarker] at kept

/-- A refusal is a no-record payload, so the class the client reads off the
constructor agrees with the marker on every refusal. -/
theorem noRecordPayload_of_refused (outcome : Outcome) (refused : outcome.effectClass = .noRecord) :
    noRecordPayload outcome = true := by
  obtain ⟨_, _, _, _, rfl⟩ := (effectClass_noRecord_iff outcome).mp refused
  rfl

/-- Satisfiable: a submit (op 2, an append operation) whose call bytes the decoder
refused is a proven no-append refusal under NO_RECORD. -/
theorem exceptionAnswer_submit_malformed :
    exceptionAnswer 2 (malformed "noncanonical native host call") =
      (HostOperations.noRecordMarker, frame 2 (malformed "noncanonical native host call")) := by
  simp [exceptionAnswer, grammarVerdict, malformed]

/-- Teeth: a submit whose handler threw a non-grammar error after dispatch is answered
undecided under 255, while `answer` (the previous discipline, kept for the no-record
cases) classes the same end as a refusal: the masquerade SYNTHESIS §B row 4 names. -/
theorem exceptionAnswer_submit_fault_undecided :
    (exceptionAnswer 2 (.userError "durable append failed")).1 =
        HostOperations.hostOutcomeMarker ∧
      (answer 2 (.userError "durable append failed")).effectClass = .noRecord :=
  ⟨rfl, rfl⟩

/-! ## The rate refusal (`Kernel.SubjectRate`; docs/PD-HOST-RATE-DESIGN.md)

`serveFrame` checks the subject a signed read claims before dispatch; a full window is
answered here, as a returned decision under NO_RECORD, before any receiver or Store work.
After the receiver answers, `chargeable` says whether that answer proves the claimed subject's
signature verified: the operation's own reply, or a refusal the disclosure order
(`Compiler.RefusalReason`) tells only after verification. A forgery is answered
`badSignature` or `unknownKey` and charges nobody. -/

/-- The detail of a rate refusal: the milliseconds until the window reopens. -/
def rateLimitedDetail (retryAfterMs : Nat) : List UInt8 :=
  s!"rate-limited retry-after-ms {retryAfterMs}".toUTF8.toList

def rateLimitedAnswer (operation : UInt8) (retryAfterMs : Nat) : Outcome :=
  .refused .rateLimited (phase operation) (rateLimitedDetail retryAfterMs)

def rateLimitedFrame (operation : UInt8) (retryAfterMs : Nat) : List UInt8 :=
  outcomeCodec.encode (rateLimitedAnswer operation retryAfterMs)

theorem rateLimitedFrame_decodes (operation : UInt8) (retryAfterMs : Nat) :
    outcomeCodec.decode (rateLimitedFrame operation retryAfterMs) =
      some (rateLimitedAnswer operation retryAfterMs) :=
  outcomeCodec.decode_encode _

/-- A rate refusal is a no-record refusal: the client may retry it as a fresh attempt. -/
theorem rateLimitedAnswer_noRecord (operation : UInt8) (retryAfterMs : Nat) :
    noRecordPayload (rateLimitedAnswer operation retryAfterMs) = true := rfl

/-- The reasons told before a request's signature verified for the subject it claims. -/
def preVerification : RefusalReason → Bool
  | .malformed | .unknownKey | .staleRoot | .badSignature | .overBound | .rateLimited => true
  | _ => false

/-- Whether a rated request's answer charges the subject it claimed: its operation's own reply,
or a refusal reached only after verification. Anything else (a pre-verification refusal, an
undecided or unavailable outcome, an undecodable payload) charges nobody. -/
def chargeable (operation responseOperation : UInt8) (payload : List UInt8) : Bool :=
  if responseOperation == operation then true
  else match outcomeCodec.decode payload with
    | some (.refused reason _ _ _) => !preVerification reason
    | _ => false

/-- Teeth: a forged signature charges nobody. -/
theorem chargeable_badSignature (operation : UInt8) (phase detail : List UInt8)
    (h : operation ≠ HostOperations.hostOutcomeMarker) :
    chargeable operation HostOperations.hostOutcomeMarker
      (outcomeCodec.encode (.refused .badSignature phase detail)) = false := by
  have : (HostOperations.hostOutcomeMarker == operation) = false := beq_false_of_ne (Ne.symm h)
  simp [chargeable, this, outcomeCodec.decode_encode, preVerification]

/-- Satisfiable: a verified holder refused by the law is charged. -/
theorem chargeable_lawDenied (operation : UInt8) (phase detail : List UInt8)
    (h : operation ≠ HostOperations.hostOutcomeMarker) :
    chargeable operation HostOperations.hostOutcomeMarker
      (outcomeCodec.encode (.refused .lawDenied phase detail)) = true := by
  have : (HostOperations.hostOutcomeMarker == operation) = false := beq_false_of_ne (Ne.symm h)
  simp [chargeable, this, outcomeCodec.decode_encode, preVerification]

#assert_axioms rateLimitedFrame_decodes
#assert_axioms rateLimitedAnswer_noRecord
#assert_axioms chargeable_badSignature
#assert_axioms chargeable_lawDenied

#assert_axioms exceptionAnswer_cases
#assert_axioms exceptionAnswer_class
#assert_axioms exceptionAnswer_noRecord_sound
#assert_axioms exceptionAnswer_undecided_sound
#assert_axioms returnedMarker_noRecord_sound
#assert_axioms returnedMarker_hostOutcome_undecided
#assert_axioms noRecordPayload_of_refused
#assert_axioms exceptionAnswer_submit_malformed
#assert_axioms exceptionAnswer_submit_fault_undecided

#assert_axioms answer_malformed
#assert_axioms answer_overBound
#assert_axioms answer_refused
#assert_axioms frame_decodes
#assert_axioms oneShotAnswer_userError
#assert_axioms oneShotAnswer_refused
#assert_axioms oneShotFrame_decodes

end Minidregg.Host.RequestRefusal

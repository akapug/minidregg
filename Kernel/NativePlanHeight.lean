/-
An opt-in exact-height deadline for a canonical invocation signing plan.

The ordinary plan deliberately tolerates unrelated accepted turns. A caller
relying on a history observation must instead bind admission to that observed
height: first check the observation's world root equals this original plan's
world root, then pin the plan, sign its new headers, and submit it unchanged.
This helper is pure authoring, not a continuity check or an admission receipt.

NativeHost admission reconstructs request.height from the loaded durable
prefix; CredentialSignedEnvelopeController.prepare rejects a greater height.
NativeHost's invocation continuation passes that SAME loaded prefix to
DurableReceiverIO.receiveLoaded: one append against that head, with no rebase.
Thus a commit before admission expires the signature; a competing append after
admission contends. Retry must preserve the signed call; fresh signing requires
fresh continuity. Recorded exact invocation replay precedes deadline admission.
-/
module

public import Kernel.NativeHost
public import Kernel.NativeHostSession

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

namespace Minidregg.Kernel.NativePlanHeight

open Minidregg.Compiler
open Minidregg.Compiler.NativeHostCodec
open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel.DurableDataIntent

set_option autoImplicit false

def pinHeader (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    CredentialSignedEnvelopeController.SignedHeader :=
  { header with validUntil := min header.validUntil height }

theorem pinHeader_deadline (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    (pinHeader height header).validUntil ≤ height := Nat.min_le_right _ _

theorem pinHeader_never_extends (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    (pinHeader height header).validUntil ≤ header.validUntil := Nat.min_le_left _ _

theorem pinHeader_only_deadline (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    { pinHeader height header with validUntil := header.validUntil } = header := by
  cases header
  rfl

theorem pinHeader_expired_after (height current : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (advanced : height < current) :
    (pinHeader height header).validUntil < current :=
  Nat.lt_of_le_of_lt (pinHeader_deadline height header) advanced

def pinSlot (height : Nat) (slot : SigningSlot) : Except String SigningSlot := do
  let some header := CredentialSignedEnvelopeController.headerCodec.decode slot.header
    | .error "noncanonical signing header"
  return { slot with header := (CredentialSignedEnvelopeController.headerCodec.encode
    (pinHeader height header)) }

/-- `pinSlot` changes the slot's header only, to the same header with its deadline
pinned (`pinHeader`); role and index are untouched. -/
theorem pinSlot_only_header (height : Nat) (slot pinned : SigningSlot)
    (ok : pinSlot height slot = .ok pinned) :
    pinned.role = slot.role ∧ pinned.index = slot.index ∧
      ∃ header, CredentialSignedEnvelopeController.headerCodec.decode slot.header = some header ∧
        pinned.header =
          CredentialSignedEnvelopeController.headerCodec.encode (pinHeader height header) := by
  unfold pinSlot at ok
  split at ok
  · rename_i header decoded
    simp only [pure, Except.pure, Except.ok.injEq] at ok
    subst ok
    exact ⟨rfl, rfl, header, decoded, rfl⟩
  · cases ok

private theorem mapM_ok_pointwise {α β : Type} (f : α → Except String β) :
    ∀ (l : List α) (l' : List β), l.mapM f = .ok l' →
      l'.length = l.length ∧
        ∀ i (hi : i < l.length) (hi' : i < l'.length), f l[i] = .ok l'[i]
  | [], l', ok => by
      simp only [List.mapM_nil, pure, Except.pure, Except.ok.injEq] at ok
      subst ok
      exact ⟨rfl, fun i hi _ => absurd hi (Nat.not_lt_zero _)⟩
  | a :: as, l', ok => by
      rw [List.mapM_cons] at ok
      cases fa : f a with
      | error e => simp [fa, bind, Except.bind] at ok
      | ok b =>
        cases fas : as.mapM f with
        | error e => simp [fa, fas, bind, Except.bind] at ok
        | ok bs =>
          simp only [fa, fas, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at ok
          subst ok
          obtain ⟨len, point⟩ := mapM_ok_pointwise f as bs fas
          refine ⟨by simp [len], ?_⟩
          intro i hi hi'
          cases i with
          | zero => simpa using fa
          | succ j => exact point j (Nat.lt_of_succ_lt_succ hi) (Nat.lt_of_succ_lt_succ hi')

/-- Reject non-invocations and malformed/empty plans; never change the signed
command, role ordering, subject, nonce, keys, footprint or request bytes. -/
def pin (plan : SigningPlan) : Except String SigningPlan := do
  let .invoke bytes := plan.finalizedDraft
    | .error "height pin requires an invocation plan"
  let some command := DeclaredResourceController.commandCodec.decode bytes
    | .error "noncanonical finalized invocation"
  let targetCount := command.signedTargetCount
  let observeCount := if command.requiresObservation then command.targets.length else 0
  if command.targets.isEmpty || plan.slots.length != targetCount + observeCount + 1 then
    .error "invocation signing slots mismatch"
  else
    let slots ← plan.slots.mapM (pinSlot plan.height)
    return { plan with slots := slots }

/-- **The pin changes nothing but the slot deadlines.** A pinned plan is the local plan
with its slot list replaced, slot for slot, by `pinSlot plan.height`: same domain,
semantics, world root, height and finalized draft; the same number of slots, each with
its role and index and with its header re-encoded at a deadline no later than the plan's
height (`pinHeader_deadline`) and no later than before (`pinHeader_never_extends`). -/
theorem pin_only_slots (plan pinned : SigningPlan) (ok : pin plan = .ok pinned) :
    pinned = { plan with slots := pinned.slots } ∧
      pinned.slots.length = plan.slots.length ∧
      ∀ i (hi : i < plan.slots.length) (hi' : i < pinned.slots.length),
        pinSlot plan.height plan.slots[i] = .ok pinned.slots[i] := by
  unfold pin at ok
  cases m : plan.slots.mapM (pinSlot plan.height) with
  | error e =>
    simp only [m, bind, Except.bind] at ok
    repeat' split at ok
    all_goals cases ok
  | ok slots =>
    simp only [m, bind, Except.bind, pure, Except.pure] at ok
    obtain ⟨len, point⟩ := mapM_ok_pointwise _ _ _ m
    repeat' split at ok
    all_goals cases ok
    all_goals exact ⟨rfl, len, point⟩

/-- The deadline a plan authored at `height` carries
(`CredentialSignatureAdmission.signingHeader`: authoring height plus the validity window). -/
def authoredDeadline (height : Nat) : Nat :=
  height + CredentialSignatureAdmission.planValidityWindow

/-- The enrollment pin's header move: the deadline becomes the one a plan authored at the
observed `height` carries, never later than before. It does NOT cut the deadline to the
observed height (`pinHeader` does, which expired an enrollment plan at the next tick). -/
def pinHeaderAt (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    CredentialSignedEnvelopeController.SignedHeader :=
  { header with validUntil := min header.validUntil (authoredDeadline height) }

theorem pinHeaderAt_never_extends (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    (pinHeaderAt height header).validUntil ≤ header.validUntil := Nat.min_le_left _ _

theorem pinHeaderAt_only_deadline (height : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader) :
    { pinHeaderAt height header with validUntil := header.validUntil } = header := by
  cases header
  rfl

/-- A header re-derived at a LATER height and pinned at the observed one is exactly the
header authored at the observed height: provider and client agree whatever ticks passed. -/
theorem pinHeaderAt_rederived (seen later : Nat) (le : seen ≤ later)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (derived : header.validUntil = authoredDeadline later) :
    pinHeaderAt seen header = { header with validUntil := authoredDeadline seen } := by
  have : min (authoredDeadline later) (authoredDeadline seen) = authoredDeadline seen := by
    unfold authoredDeadline; omega
  simp [pinHeaderAt, derived, this]

/-- Liveness: the pinned header stays admissible (`height ≤ validUntil`) at every height up
to the observed height's deadline, the ticks between included. -/
theorem pinHeaderAt_live (seen later current : Nat) (le : seen ≤ later)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (derived : header.validUntil = authoredDeadline later)
    (within : current ≤ authoredDeadline seen) :
    current ≤ (pinHeaderAt seen header).validUntil := by
  rw [pinHeaderAt_rederived seen later le header derived]
  exact within

/-- Teeth: the old cut (`pinHeader`) expires the plan at the first height after the
observation, the `expired 13 12` the box run saw; the new pin keeps it. -/
theorem old_cut_expires_new_pin_lives (seen : Nat)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (derived : header.validUntil = authoredDeadline seen) :
    (pinHeader seen header).validUntil < seen + 1 ∧
      seen + 1 ≤ (pinHeaderAt seen header).validUntil := by
  refine ⟨Nat.lt_succ_of_le (pinHeader_deadline seen header), ?_⟩
  rw [pinHeaderAt_rederived seen seen le_rfl header derived]
  simp [authoredDeadline, CredentialSignatureAdmission.planValidityWindow]

/-- The enrollment plan's pin (op 86): only the sponsor header's deadline moves, to the
deadline a plan authored at the observed height carries (`pinHeaderAt`); the possession
frame is a fixed function of the command (`NativeHost.enrollmentAssemble` checks it) and is
untouched, as are the command bytes. -/
def pinEnrollment (height : Nat) (plan : ParticipantKeyEnrollment.SigningPlan) :
    Except String ParticipantKeyEnrollment.SigningPlan := do
  let some header := CredentialSignedEnvelopeController.headerCodec.decode plan.sponsorHeader
    | .error "noncanonical enrollment sponsor header"
  return { plan with sponsorHeader :=
    CredentialSignedEnvelopeController.headerCodec.encode (pinHeaderAt height header) }

/-- The enrollment pin changes nothing but the sponsor header's deadline. -/
theorem pinEnrollment_only_sponsor_deadline (height : Nat)
    (plan pinned : ParticipantKeyEnrollment.SigningPlan)
    (ok : pinEnrollment height plan = .ok pinned) :
    pinned.domain = plan.domain ∧ pinned.semantics = plan.semantics ∧
      pinned.commandBytes = plan.commandBytes ∧ pinned.possessionHeader = plan.possessionHeader ∧
      ∃ header, CredentialSignedEnvelopeController.headerCodec.decode plan.sponsorHeader = some header ∧
        pinned.sponsorHeader =
          CredentialSignedEnvelopeController.headerCodec.encode (pinHeaderAt height header) := by
  unfold pinEnrollment at ok
  split at ok
  · rename_i header decoded
    simp only [pure, Except.pure, Except.ok.injEq] at ok
    subst ok
    exact ⟨rfl, rfl, rfl, rfl, header, decoded, rfl⟩
  · cases ok

/-- The provider's plan re-derived at a later height, pinned at the observed height, is the
plan authored at the observed height. -/
theorem pinEnrollment_rederived_later (seen later : Nat) (le : seen ≤ later)
    (plan : ParticipantKeyEnrollment.SigningPlan)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (decoded : CredentialSignedEnvelopeController.headerCodec.decode plan.sponsorHeader = some header)
    (derived : header.validUntil = authoredDeadline later) :
    pinEnrollment seen plan = .ok { plan with sponsorHeader :=
      (CredentialSignedEnvelopeController.headerCodec.encode
        { header with validUntil := authoredDeadline seen }) } := by
  unfold pinEnrollment
  rw [decoded]
  simp only [pure, Except.pure]
  rw [pinHeaderAt_rederived seen later le header derived]

#assert_axioms pinSlot_only_header
#assert_axioms pinEnrollment_only_sponsor_deadline
#assert_axioms pinHeaderAt_never_extends pinHeaderAt_rederived pinHeaderAt_live
  old_cut_expires_new_pin_lives pinEnrollment_rederived_later
#assert_axioms pin_only_slots

/-- Invert one refusal guard without simplifying any symbolic codec terms. -/
private theorem refusal_else {E A : Type} {condition : Prop} [Decidable condition]
    {reason : E} {rest : Except E A} {value : A}
    (accepted : (if condition then Except.error reason else rest) = .ok value) :
    ¬ condition ∧ rest = .ok value := by
  by_cases selected : condition
  · rw [if_pos selected] at accepted
    contradiction
  · exact ⟨selected, by simpa only [if_neg selected] using accepted⟩

/-- This is the actual receiving controller, not a second deadline predicate.
Successful parsing/admission preparation entails its signed deadline check. -/
theorem receiving_prepare_deadline {NativeError : Type}
    (subject : Nat) (domain message state registry envelope : List UInt8)
    (prepared : CredentialSignedEnvelopeController.Prepared)
    (accepted : CredentialSignedEnvelopeController.prepare (NativeError := NativeError)
      subject domain message state registry envelope = .ok prepared) :
    prepared.state.height ≤ prepared.envelope.header.validUntil := by
  unfold CredentialSignedEnvelopeController.prepare at accepted
  cases stateDecoded : CredentialSignedEnvelopeController.stateCodec.decode state with
  | none => simp only [stateDecoded] at accepted; contradiction
  | some current =>
    simp only [stateDecoded] at accepted
    cases registryDecoded : CredentialSignedEnvelopeController.registryCodec.decode registry with
    | none => simp only [registryDecoded] at accepted; contradiction
    | some keys =>
      simp only [registryDecoded] at accepted
      cases envelopeDecoded : CredentialSignedEnvelopeController.envelopeCodec.decode envelope with
      | none => simp only [envelopeDecoded] at accepted; contradiction
      | some signed =>
        simp only [envelopeDecoded] at accepted
        -- Each inversion retains the original receiver expression. In
        -- particular, it never evaluates symbolic wire re-encoding guards.
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨notExpired, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        obtain ⟨_, accepted⟩ := refusal_else accepted
        cases keyFound : keys.findKey signed.header.keyId with
        | none => simp only [keyFound] at accepted; contradiction
        | some key =>
          simp only [keyFound] at accepted
          obtain ⟨_, accepted⟩ := refusal_else accepted
          obtain ⟨_, accepted⟩ := refusal_else accepted
          obtain ⟨_, accepted⟩ := refusal_else accepted
          obtain ⟨_, accepted⟩ := refusal_else accepted
          cases accepted
          exact Nat.le_of_not_lt notExpired

/-- Exact historical replay takes the recorded branch before any new
preparation, key verification or deadline check. This is the actual invoked
receiver, so a lost acknowledgement does not require re-signing an old plan. -/
theorem recorded_replay_before_deadline {F : Type} [Field F] [DecidableEq F] {R : Type}
    (deployment : DeclaredResourceController.Deployment)
    (profile : CanonicalRuntimeProfile.Profile F)
    (ambient : DeclaredResourceController.Ambient)
    (native : CredentialSignatureIO.NativeConfig)
    (ground : DeclaredResourceController.Ground deployment)
    (signed : DeclaredResourceController.SignedCommand)
    (command : DeclaredResourceController.Command)
    (record : DurableCommitProtocol.Intent Digest Digest StableNullifier ReplayEnvelope)
    (acceptedResult : {command : DeclaredResourceController.Command} →
      (prepared : DeclaredResourceController.PreparedInvocation deployment profile ambient ground command) →
      (shape : DeclaredResourceController.PhysicalShape prepared) →
      DeclaredResourceController.AcceptedInvocation prepared signed → IO R)
    (ordinaryResult : DeclaredResourceController.ReceiveResult → IO R)
    (decoded : DeclaredResourceController.commandCodec.decode signed.commandBytes = some command)
    (declared : ground.declaresTransaction
      (DeclaredResourceController.transactionId deployment.domain profile.semantics command) = true)
    (recorded : DeclaredResourceController.recordedInvocation deployment.domain profile.semantics
      command signed ground = .ok (some record)) :
    DeclaredResourceController.withAcceptedOn deployment profile ambient native ground
      signed acceptedResult ordinaryResult = ordinaryResult (.replayed record) := by
  simp only [DeclaredResourceController.withAcceptedOn, decoded, declared, recorded]
  rfl

/-!
Retiring an old *pending settlement attempt* needs more than native contention.
`NativeConfig.append` maps a native conflict to contention, and
`receiveLoadedDetailedWithFresh` also returns contention for differing readback.
Neither result alone says that the head advanced or that the call is absent.

The caller first performs exact replay lookup, then obtains fresh API17
continuity for the original reserve and optional exact fence. That verifier
checks the original prefix receipts and excludes any other provider write;
the retained pending call must be the exact settlement, not the allowed fence.
Its original signed headers must be bound to the retained pinned plan.

The lemmas below consume the real receiving deadline gate and a verifier-minted
prefix at a strictly greater logical height, with ONE fixed config/genesis.
An already-admitted old call can only append at a position covered by that
prefix. A future admission of the same deadline is impossible in an extension
of that exact image (seed and all prior records, not just a numeric height).

The physical connection is explicit, not an assumed theorem about Rust:
SQLite `durable_read` validates and publishes its retained head under the
anchor lock before returning. `durable_append_with_hook` takes the same lock
and BEGIN IMMEDIATE, never replaces an existing log entry, and inserts only
at head+1. `anchor_head` rejects rollback or a changed retained entry/seed.
`NativeHostSession.refresh` rejects shrinking history; `extendVerified` checks
the exact seed and accepted-record prefix. Thus a delayed already-admitted
append to a covered, different entry cannot install. Replaced Stores, changed
genesis/config, unavailable/absent/unknown outcomes, and naked counters do not
supply this evidence. Only Pending may retire; the response, hold and all
unrelated uncertainty remain. A new signing attempt requires fresh continuity.
-/

/-- Any old in-flight admission's one append position is already within the
freshly checked prefix. The exact continuity witness separately excludes that
settlement from this prefix, and the physical append contract forbids overwrite. -/
theorem admitted_append_within_checked_prefix {NativeError : Type}
    {config : NativeHost.Config} (checked : NativeHostSession.Walked config)
    (subject : Nat) (domain message state registry oldEnvelope : List UInt8)
    (prepared : CredentialSignedEnvelopeController.Prepared) (admittedCount : Nat)
    (accepted : CredentialSignedEnvelopeController.prepare (NativeError := NativeError)
      subject domain message state registry oldEnvelope = .ok prepared)
    (sameGenesisHeight : prepared.state.height = config.genesisHeight + admittedCount)
    (beyondDeadline : prepared.envelope.header.validUntil <
      NativeHost.logicalHeight config checked.target) :
    admittedCount + 1 ≤ checked.target.image.accepted.length := by
  have bounded := receiving_prepare_deadline subject domain message state registry oldEnvelope
    prepared accepted
  rw [sameGenesisHeight] at bounded
  unfold NativeHost.logicalHeight DurableReceiverIO.Loaded.height at beyondDeadline
  omega

/-- The same old signed deadline cannot be admitted against any extension of
the exact checked image. Both walked images share the fixed configuration;
the explicit image equality retains the same seed and every old record. -/
theorem no_new_admission_after_checked_prefix {NativeError : Type}
    {config : NativeHost.Config} (checked future : NativeHostSession.Walked config)
    (samePrefix : ∃ suffix, future.target.image =
      { checked.target.image with accepted := checked.target.image.accepted ++ suffix })
    (subject : Nat) (domain message state registry oldEnvelope : List UInt8)
    (prepared : CredentialSignedEnvelopeController.Prepared) (oldDeadline : Nat)
    (accepted : CredentialSignedEnvelopeController.prepare (NativeError := NativeError)
      subject domain message state registry oldEnvelope = .ok prepared)
    (sameSignedDeadline : prepared.envelope.header.validUntil = oldDeadline)
    (sameGenesisHeight : prepared.state.height = NativeHost.logicalHeight config future.target)
    (beyondDeadline : oldDeadline < NativeHost.logicalHeight config checked.target) : False := by
  have bounded := receiving_prepare_deadline subject domain message state registry oldEnvelope
    prepared accepted
  rw [sameGenesisHeight, sameSignedDeadline] at bounded
  rcases samePrefix with ⟨suffix, exactImage⟩
  have lengthExact := congrArg (fun image : DurableReceiver.Image => image.accepted.length) exactImage
  simp only [List.length_append] at lengthExact
  unfold NativeHost.logicalHeight DurableReceiverIO.Loaded.height at bounded beyondDeadline
  omega

end Minidregg.Kernel.NativePlanHeight

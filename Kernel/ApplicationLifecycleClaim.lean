/-
Source-authored identity for one durable claim of a previously admitted
application lifecycle BEGIN. A claim changes the app's pending phase to a
claimed phase in Mini; it does not assert a host effect or permit a retry after
uncertain physical execution.
-/
module

public import Kernel.ApplicationLifecycleBeginIngress

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

namespace Minidregg.Kernel.ApplicationLifecycleClaim

open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Compiler.IntStream (intStream)
open Minidregg.Theory
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel.DurableDataIntent

set_option autoImplicit false

abbrev Begin := ApplicationLifecycleBeginIngress.Ingress
abbrev Kind := ApplicationLifecycleBegin.Kind

def Kind.pendingPhase : Kind → Int
  | .install => 1
  | .start => 3
  | .stop => 5
  | .upgrade => 6

def Kind.claimedPhase : Kind → Int
  | .install => 8
  | .start => 9
  | .stop => 10
  | .upgrade => 11

def Kind.claimOperation : Kind → ApplicationGrain.Operation
  | .install => .claimInstall
  | .start => .claimStart
  | .stop => .claimStop
  | .upgrade => .claimUpgrade

theorem Kind.claimed_ne_pending (kind : Kind) :
    Kind.claimedPhase kind ≠ Kind.pendingPhase kind := by
  cases kind <;> decide

/-- `originalIndex` selects a record from a semantically verified durable
history. A later receiver must reconstruct the actual original prefix and
compare the source-derived BEGIN intent to that exact record. Current roots
and the full image boundary are checked against one newly loaded image. -/
structure Source where
  begin : Begin
  originalIndex : Nat
  before : ApplicationGrain.State
  currentAppRoot : Digest
  currentPackageRoot : Digest
  currentWorldRoot : Digest
  appObserveCapability : CapabilityId
  packageObserveCapability : CapabilityId
  queryNonce : Nat
  deriving DecidableEq, Repr

def Source.valid (source : Source) : Bool :=
  source.begin.source.valid &&
  decide (source.before =
    source.begin.source.kind.operation.after source.begin.source.before ∧
    source.before.phase = Kind.pendingPhase source.begin.source.kind ∧
    source.before.generation = source.begin.source.processGeneration ∧
    source.currentPackageRoot = source.begin.source.packageRoot)

theorem Source.valid_generation (source : Source) (valid : source.valid = true) :
    source.before.generation = source.begin.source.processGeneration := by
  simp only [Source.valid, Bool.and_eq_true, decide_eq_true_eq] at valid
  exact valid.2.2.2.1

theorem Source.valid_pending (source : Source) (valid : source.valid = true) :
    source.before.phase = Kind.pendingPhase source.begin.source.kind := by
  simp only [Source.valid, Bool.and_eq_true, decide_eq_true_eq] at valid
  exact valid.2.2.1

def sourceStream : StreamCodec Source :=
  StreamCodec.xmap
    (StreamCodec.product ApplicationLifecycleBeginIngress.ingressStream
      (StreamCodec.product StreamCodec.nat
        (StreamCodec.product ApplicationLifecycleBegin.stateStream
          (StreamCodec.product digestStream
            (StreamCodec.product digestStream
              (StreamCodec.product digestStream
                  (StreamCodec.product CredentialAuthorityEntryCodec.capabilityIdStream
                    (StreamCodec.product CredentialAuthorityEntryCodec.capabilityIdStream
                      StreamCodec.nat))))))))
    (fun source => (source.begin, source.originalIndex, source.before,
      source.currentAppRoot,
      source.currentPackageRoot, source.currentWorldRoot,
      source.appObserveCapability, source.packageObserveCapability,
      source.queryNonce))
    (fun (begin, originalIndex, before, currentAppRoot,
          currentPackageRoot, currentWorldRoot, appObserveCapability,
          packageObserveCapability, queryNonce) =>
      ⟨begin, originalIndex, before, currentAppRoot,
        currentPackageRoot, currentWorldRoot, appObserveCapability,
        packageObserveCapability, queryNonce⟩)
    (by intro source; cases source; rfl)

private def frame : List UInt8 :=
  "DREGG/APPLICATION/LIFECYCLE-CLAIM/v2".toUTF8.toList

def codec : LawfulCodec Source := (StreamCodec.framed frame sourceStream).toLawful

def Source.canonicalBytes (source : Source) : List UInt8 := codec.encode source

theorem decode_encode (source : Source) :
    codec.decode source.canonicalBytes = some source := codec.decode_encode source

theorem decoded_canonical {bytes : List UInt8} {source : Source}
    (decoded : codec.decode bytes = some source) :
    source.canonicalBytes = bytes := StreamCodec.toLawful_canonical _ _ _ decoded

def sourceDigest (domain semantics : Digest) (source : Source) : Digest :=
  (Sp800185Cshake256.hash "DREGG/APPLICATION/LIFECYCLE-CLAIM-SOURCE/v1".toUTF8.toList
    ((StreamCodec.product digestStream (StreamCodec.product digestStream bytesStream)).encode
      (domain, semantics, source.canonicalBytes))).digest

def command (domain semantics : Digest) (source : Source) :
    DeclaredResourceController.Command :=
  ApplicationGrain.Operation.command (Kind.claimOperation source.begin.source.kind)
    source.begin.source.subject
    (sourceDigest domain semantics source).value source.begin.source.app
    source.begin.source.capability source.currentAppRoot source.before

/-- The key is stable for one historical BEGIN and app generation even if a
different current image, observation envelope or physical identity is later
presented. Canonical bytes remain part of the replay nullifier. -/
def keyBytes (domain semantics : Digest) (source : Source) : List UInt8 :=
  (StreamCodec.product digestStream (StreamCodec.product digestStream
    (StreamCodec.product digestStream
      (StreamCodec.product StreamCodec.nat intStream)))).encode
    (domain, semantics, (ApplicationLifecycleBeginIngress.event source.begin).eventId,
      source.begin.source.app, source.begin.source.processGeneration)

def stableNullifier (domain semantics : Digest) (source : Source) : StableNullifier where
  codecVersion := 16
  domain := domain
  nullifierId := (Sp800185Cshake256.hash
    "DREGG/APPLICATION/LIFECYCLE-CLAIM-KEY/v1".toUTF8.toList
    (keyBytes domain semantics source)).digest
  canonicalBytes := "DREGG/APPLICATION/LIFECYCLE-CLAIM-NULLIFIER/v1".toUTF8.toList ++
    keyBytes domain semantics source

end Minidregg.Kernel.ApplicationLifecycleClaim

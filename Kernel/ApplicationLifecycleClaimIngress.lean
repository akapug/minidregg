/-
Canonical signed one-shot lifecycle claim. The separate current app and
package observation envelopes are part of the same special event; neither an
old BEGIN receipt nor a generic DRC invocation can stand in for this ingress.
-/
module

public import Kernel.ApplicationLifecycleClaim
public import Compiler.NativeHostCodec

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

namespace Minidregg.Kernel.ApplicationLifecycleClaimIngress

open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Theory
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.ApplicationLifecycleClaim

set_option autoImplicit false

structure Ingress where
  domain : Digest
  semantics : Digest
  source : Source
  signed : DeclaredResourceController.SignedCommand
  appObservationEnvelope : List UInt8
  packageObservationEnvelope : List UInt8
  deriving DecidableEq, Repr

def ingressStream : StreamCodec Ingress :=
  StreamCodec.xmap
    (StreamCodec.product digestStream
      (StreamCodec.product digestStream
        (StreamCodec.product sourceStream
          (StreamCodec.product NativeHostCodec.signedInvocationStream
            (StreamCodec.product bytesStream bytesStream)))))
    (fun ingress => (ingress.domain, ingress.semantics, ingress.source,
      ingress.signed, ingress.appObservationEnvelope, ingress.packageObservationEnvelope))
    (fun (domain, semantics, source, signed, appObservationEnvelope,
          packageObservationEnvelope) =>
      ⟨domain, semantics, source, signed, appObservationEnvelope,
        packageObservationEnvelope⟩)
    (by intro ingress; cases ingress; rfl)

private def frame : List UInt8 :=
  "DREGG/APPLICATION/LIFECYCLE-CLAIM-INGRESS/v1".toUTF8.toList

def codec : LawfulCodec Ingress := (StreamCodec.framed frame ingressStream).toLawful

def Ingress.canonicalBytes (ingress : Ingress) : List UInt8 := codec.encode ingress

theorem decode_encode (ingress : Ingress) :
    codec.decode ingress.canonicalBytes = some ingress := codec.decode_encode ingress

theorem decoded_canonical {bytes : List UInt8} {ingress : Ingress}
    (decoded : codec.decode bytes = some ingress) :
    ingress.canonicalBytes = bytes := StreamCodec.toLawful_canonical _ _ _ decoded

def event (ingress : Ingress) : StableEvent where
  codecVersion := 16
  domain := ingress.domain
  eventId := (Sp800185Cshake256.hash
    "DREGG/APPLICATION/LIFECYCLE-CLAIM-EVENT/v1".toUTF8.toList
    ingress.canonicalBytes).digest
  canonicalBytes := ingress.canonicalBytes

theorem event_retains_ingress (ingress : Ingress) :
    (event ingress).canonicalBytes = ingress.canonicalBytes := rfl

def Ingress.transactionId (ingress : Ingress) : Digest :=
  ⟨DeclaredResourceController.operationMarker ingress.domain ingress.semantics
    (command ingress.domain ingress.semantics ingress.source)⟩

end Minidregg.Kernel.ApplicationLifecycleClaimIngress

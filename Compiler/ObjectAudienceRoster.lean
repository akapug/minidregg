module

public import Theory.ObjectAudienceRoster
public import Compiler.StoreCodec
public import Compiler.Sp800185Cshake256

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

namespace Minidregg.Compiler.ObjectAudienceRoster
open Minidregg.Theory.ObjectAudienceRoster
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization
open Minidregg.Compiler.Tower256ConcreteBackend
set_option autoImplicit false
def entryStream : StreamCodec Entry :=
  StreamCodec.xmap
    (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
      (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat StreamCodec.nat))))
    (fun e => (e.subject, e.capability, e.deviceSource, e.deviceGeneration, e.keyCommitment))
    (fun (s,c,d,g,k) => ⟨s,c,d,g,k⟩) (by intro e; cases e; rfl)
def rosterStream : StreamCodec Roster :=
  StreamCodec.xmap
    (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
      (StreamCodec.product StreamCodec.nat (StreamCodec.list entryStream))))
    (fun r => (r.object,r.epoch,r.transition,r.entries))
    (fun (o,e,t,es) => ⟨o,e,t,es⟩) (by intro r; cases r; rfl)
def encode (r : Roster) : List UInt8 := rosterStream.encode r
/-- `rosterStream` is canonical, so its top-level decoder already accepts
exactly the encodings (`decode_canonical`). -/
def decode (bytes : List UInt8) : Option Roster := rosterStream.toLawful.decode bytes
@[simp] theorem decode_encode (r : Roster) : decode (encode r) = some r :=
  rosterStream.toLawful.decode_encode r
theorem decode_canonical {bytes : List UInt8} {r : Roster}
    (accepted : decode bytes = some r) : encode r = bytes :=
  rosterStream.toLawful_canonical bytes r accepted
def codec : LawfulCodec Roster where
  encode := encode
  decode := decode
  decode_encode := decode_encode
/-- Exported domains are shared with the canonical runtime identity. -/
def digestCustomization : List UInt8 := "LOOM.OBJECT.AUDIENCE.ROSTER/v1".toUTF8.toList
def deviceCustomization : List UInt8 := "LOOM.OBJECT.AUDIENCE.DEVICES/v1".toUTF8.toList
def digest (r : Roster) : Digest :=
  (Sp800185Cshake256.hash digestCustomization (encode r)).digest
def deviceDigest (r : Roster) : Digest :=
  (Sp800185Cshake256.hash deviceCustomization
    ((StreamCodec.list entryStream).encode r.entries)).digest
/-- Exact package-list equality prevents omitting an offline retained holder.
Enrollment must authenticate these bytes and the device sources separately. -/
def Bound (state : Minidregg.Theory.ObjectAudience.State) (r : Roster)
    (packageRecipients : List Entry) : Prop :=
  Valid r ∧ r.object = state.object ∧ r.epoch = state.epoch ∧
  r.transition = state.transition ∧ (digest r).value = state.audience ∧
  (deviceDigest r).value = state.devices ∧ packageRecipients = r.entries
instance (s : Minidregg.Theory.ObjectAudience.State) (r : Roster) (p : List Entry) :
    Decidable (Bound s r p) := by unfold Bound; infer_instance
end Minidregg.Compiler.ObjectAudienceRoster

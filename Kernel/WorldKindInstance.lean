/-
Executable instance payload and guarded mutations for world-resident kinds.
Uses the exact descriptor-generated Store, its canonical wire, and Patch.run.
This is preparation, not authority: the native receiver must add current kind
export law, capability admission and durable read guards to the resulting turn.
-/
module

public import Compiler.WorldKindDescriptor

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

namespace Minidregg.Kernel.WorldKindInstance

open Minidregg.Theory.Store
open Minidregg.Compiler
open Minidregg.Compiler.WorldKindDescriptor
open Minidregg.Compiler.Tower256ConcreteBackend

set_option autoImplicit false

/-- The immutable descriptor is retained with each instance, so the decoder
never consults a mutable kind head to reinterpret old payload bytes. -/
structure Instance where
  descriptor : Descriptor
  valid : descriptor.Valid
  store : Store (layout descriptor)

def frame : List UInt8 := "DREGG/WORLD/INSTANCE".toUTF8.toList ++ [1]

def encode (value : Instance) : List UInt8 :=
  frame ++ (StreamCodec.product bytesStream bytesStream).encode
    (descriptorCodec.encode value.descriptor,
      StoreCodec.encode (wire value.descriptor) value.store)

def decode (bytes : List UInt8) : Option Instance := do
  if bytes.take frame.length != frame then none else do
    let (definition, payload) ← (StreamCodec.product bytesStream bytesStream).toLawful.decode
      (bytes.drop frame.length)
    let ⟨descriptor, valid⟩ ← decodeDefinition definition
    let store ← StoreCodec.decode (wire descriptor) payload
    some (Instance.mk descriptor valid store)

theorem decodeDefinition_canonical {bytes : List UInt8}
    {definition : { descriptor : Descriptor // descriptor.Valid }}
    (decoded : decodeDefinition bytes = some definition) :
    descriptorCodec.encode definition.val = bytes := by
  unfold decodeDefinition at decoded
  simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at decoded
  obtain ⟨descriptor, raw, decoded⟩ := decoded
  split at decoded
  · cases decoded
    exact descriptorStream.toLawful_canonical _ _ raw
  · cases decoded

/-- **Canonicity.** The frame is compared exactly and every component decoder
is canonical, so an accepted string is exactly the instance's encoding; the
decoder needs no re-encode. -/
theorem decode_canonical {bytes : List UInt8} {value : Instance}
    (decoded : decode bytes = some value) : encode value = bytes := by
  unfold decode at decoded
  split at decoded
  · cases decoded
  · rename_i framed
    have framed : bytes.take frame.length = frame := by simpa using framed
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at decoded
    obtain ⟨⟨definition, payload⟩, pair, decoded⟩ := decoded
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at decoded
    obtain ⟨⟨descriptor, valid⟩, described, decoded⟩ := decoded
    simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at decoded
    obtain ⟨store, stored, decoded⟩ := decoded
    cases decoded
    have pairBytes := (StreamCodec.product bytesStream bytesStream).toLawful_canonical _ _ pair
    have definitionBytes := decodeDefinition_canonical described
    have storeBytes := StoreCodec.decode_reencodes _ stored
    calc encode ⟨descriptor, valid, store⟩
        = bytes.take frame.length ++ bytes.drop frame.length := by
          unfold encode
          rw [definitionBytes, storeBytes, pairBytes, framed]
      _ = bytes := List.take_append_drop _ _

/-- Transport actions name a semantic field, not a positional namespace.
The expected value is mandatory for replacement/deletion. -/
inductive Action where
  | read (field key : Nat) (expected : Option (List UInt8))
  | create (field key : Nat) (value : List UInt8)
  | write (field key : Nat) (before after : List UInt8)
  | erase (field key : Nat) (before : List UInt8)
  deriving DecidableEq, Repr

def actionStream : StreamCodec Action where
  encode
    | .read field key expected => 0 :: (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat (StreamCodec.option bytesStream))).encode
          (field, key, expected)
    | .create field key value => 1 :: (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat bytesStream)).encode (field, key, value)
    | .write field key before after => 2 :: (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat (StreamCodec.product bytesStream bytesStream))).encode
          (field, key, before, after)
    | .erase field key before => 3 :: (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat bytesStream)).encode (field, key, before)
  decodePrefix
    | 0 :: bytes => do
        let ((field, key, expected), suffix) ← (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat (StreamCodec.option bytesStream))).decodePrefix bytes
        some (.read field key expected, suffix)
    | 1 :: bytes => do
        let ((field, key, value), suffix) ← (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat bytesStream)).decodePrefix bytes
        some (.create field key value, suffix)
    | 2 :: bytes => do
        let ((field, key, before, after), suffix) ← (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat (StreamCodec.product bytesStream bytesStream))).decodePrefix bytes
        some (.write field key before after, suffix)
    | 3 :: bytes => do
        let ((field, key, before), suffix) ← (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat bytesStream)).decodePrefix bytes
        some (.erase field key before, suffix)
    | _ => none
  decodePrefix_encode := by
    intro action suffix
    cases action <;> simp [StreamCodec.decodePrefix_encode]

def Action.field : Action → Nat
  | .read field _ _ | .create field _ _ | .write field _ _ _ | .erase field _ _ => field

def findField (descriptor : Descriptor) (id : Nat) : Option (Fin descriptor.fields.length) :=
  (List.finRange descriptor.fields.length).find? fun index =>
    (descriptor.fields.get index).id == id

def decodeValue (descriptor : Descriptor) (space : Fin descriptor.fields.length)
    (bytes : List UInt8) : Option ((layout descriptor).Value space) :=
  (descriptor.fields.get space).codec.stream.toLawful.decode bytes

/-- One source lowering; clients cannot supply an independent field footprint
or a differently typed post. Unknown fields and noncanonical values refuse. -/
def lower (descriptor : Descriptor) (action : Action) : Option (Op (layout descriptor)) := do
  let space ← findField descriptor action.field
  match action with
  | .read _ key none => some (.read space key none)
  | .read _ key (some expected) => do
      let value ← decodeValue descriptor space expected
      some (.read space key (some value))
  | .create _ key value => do
      let value ← decodeValue descriptor space value
      some (.allocate space key value)
  | .write _ key before after => do
      let before ← decodeValue descriptor space before
      let after ← decodeValue descriptor space after
      some (.write space key before after)
  | .erase _ key before => do
      let before ← decodeValue descriptor space before
      some (.free space key before)

def lowerAll (descriptor : Descriptor) : List Action → Option (Patch (layout descriptor))
  | [] => some []
  | action :: rest => do
      let head ← lower descriptor action
      let tail ← lowerAll descriptor rest
      some (head :: tail)

structure Prepared (value : Instance) where
  patch : Patch (layout value.descriptor)
  valid : Patch.ValidFrom value.store patch

def prepare (value : Instance) (actions : List Action) : Option (Prepared value) := do
  let patch ← lowerAll value.descriptor actions
  if valid : Patch.ValidFrom value.store patch then some ⟨patch, valid⟩ else none

def Prepared.post {value : Instance} (prepared : Prepared value) : Instance :=
  ⟨value.descriptor, value.valid, Patch.run value.store prepared.patch⟩

theorem prepared_preserves_descriptor {value : Instance} (prepared : Prepared value) :
    prepared.post.descriptor = value.descriptor := rfl

theorem prepared_preserves_rom {value : Instance} (prepared : Prepared value)
    (address : Address (layout value.descriptor))
    (rom : (value.descriptor.fields.get address.1).discipline = .rom) :
    prepared.post.store address = value.store address :=
  instance_rom_preserved value.descriptor value.store prepared.patch address prepared.valid rom

end Minidregg.Kernel.WorldKindInstance

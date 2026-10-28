/-
Canonical source coordinates for the native grain-backed birth draft. This is
input data, never an authority verdict or a proposed post-state. The receiver
recomputes the command, checks both old grain cells, and admits signatures.
-/
module

public import Compiler.GrainResourceBirthController
public import Compiler.CanonicalResourcePageMaterializer

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

namespace Minidregg.Compiler.GrainResourceBirthHostCodec

open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.IndexedProgram
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel

set_option autoImplicit false

abbrev Source := GrainResourceBirthController.Source
abbrev SourceWire := List UInt8 × List Nat × List Int

def sourceWireStream : StreamCodec SourceWire :=
  StreamCodec.product bytesStream
    (StreamCodec.product (StreamCodec.list StreamCodec.nat)
      (StreamCodec.list IntStream.intStream))

def sourceFrame : List UInt8 :=
  "DREGG/GRAIN-RESOURCE-BIRTH/HOST-SOURCE/v6".toUTF8.toList

def toWire (source : Source) : SourceWire :=
  ((ResourceBirthCodec.descriptorCodec CanonicalCellRegistry.registry).encode source.birth,
    [source.toolTask, source.toolCapability.value,
      source.toolObserveCapability.value, source.toolRoot.value,
      source.parentTask, source.parentCapability.value,
      source.parentObserveCapability.value, source.parentRoot.value],
    source.toolBefore.values ++ source.parentBefore.values)

def fromWire : SourceWire → Option Source
  | (birthBytes, [toolTask, toolCapability, toolObserveCapability,
      toolRoot, parentTask, parentCapability, parentObserveCapability, parentRoot],
      [toolGeneration, toolStatus, toolRemaining, toolReserved,
        parentGeneration, parentStatus, parentRemaining, parentReserved]) => do
      let birth ← (ResourceBirthCodec.descriptorCodec CanonicalCellRegistry.registry).decode birthBytes
      some {
        birth := birth,
        toolTask := toolTask, toolCapability := ⟨toolCapability⟩,
        toolObserveCapability := ⟨toolObserveCapability⟩, toolRoot := ⟨toolRoot⟩,
        toolBefore := ⟨toolGeneration, toolStatus, toolRemaining, toolReserved⟩,
        parentTask := parentTask, parentCapability := ⟨parentCapability⟩,
        parentObserveCapability := ⟨parentObserveCapability⟩,
        parentRoot := ⟨parentRoot⟩,
        parentBefore := ⟨parentGeneration, parentStatus, parentRemaining, parentReserved⟩ }
  | _ => none

theorem fromWire_toWire (source : Source) : fromWire (toWire source) = some source := by
  cases source with
  | mk birth toolTask toolCapability toolObserveCapability toolRoot toolBefore
      parentTask parentCapability parentObserveCapability parentRoot parentBefore =>
      have decoded := (ResourceBirthCodec.descriptorCodec CanonicalCellRegistry.registry).decode_encode birth
      cases toolBefore
      cases parentBefore
      simp [fromWire, toWire, Kernel.AgentGrain.State.values,
        decoded]

/-- `fromWire` keeps no choice of its own: what it accepts is a `toWire` image
(the birth descriptor is read by a canonical codec). -/
theorem toWire_fromWire {wire : SourceWire} {source : Source}
    (decoded : fromWire wire = some source) : toWire source = wire := by
  unfold fromWire at decoded
  split at decoded
  · simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at decoded
    obtain ⟨birth, birthOk, same⟩ := decoded
    cases Option.some.inj same
    simp [toWire, Kernel.AgentGrain.State.values,
      ResourceBirthCodec.descriptor_decode_canonical _ birthOk]
  · cases decoded

/-- The source stream: the wire stream refined by `fromWire`, canonical because
`fromWire` only accepts `toWire` images (`toWire_fromWire`). -/
def sourceStream : StreamCodec Source where
  encode source := sourceWireStream.encode (toWire source)
  decodePrefix bytes := do
    let (wire, suffix) ← sourceWireStream.decodePrefix bytes
    let source ← fromWire wire
    some (source, suffix)
  decodePrefix_encode := by
    intro source suffix
    simp [sourceWireStream.decodePrefix_encode, fromWire_toWire]
  encode_decodePrefix := by
    intro bytes source suffix decoded
    cases wireOk : sourceWireStream.decodePrefix bytes with
    | none => simp [wireOk] at decoded
    | some pair =>
      obtain ⟨wire, rest⟩ := pair
      cases sourceOk : fromWire wire with
      | none => simp [wireOk, sourceOk] at decoded
      | some decodedSource =>
        simp only [wireOk, sourceOk, bind, Option.bind, Option.some.injEq, Prod.mk.injEq] at decoded
        obtain ⟨rfl, rfl⟩ := decoded
        rw [toWire_fromWire sourceOk]
        exact sourceWireStream.encode_decodePrefix _ _ _ wireOk

def sourceCodec : LawfulCodec Source := (StreamCodec.framed sourceFrame sourceStream).toLawful

theorem sourceCodec_canonical {bytes : List UInt8} {source : Source}
    (decoded : sourceCodec.decode bytes = some source) :
    sourceCodec.encode source = bytes :=
  StreamCodec.toLawful_canonical _ _ _ decoded

/-- The signing plan retains the finalized canonical source and exactly the
derived command bytes used for its headers. Detached assembly has no access
to operator configuration; the receiver rechecks this command against its
currently pinned tariff before a fresh installation. -/
structure Finalized where
  sourceBytes : List UInt8
  commandBytes : List UInt8
  deriving DecidableEq, Repr

def finalizedStream : StreamCodec Finalized :=
  StreamCodec.xmap (StreamCodec.product bytesStream bytesStream)
    (fun value => (value.sourceBytes, value.commandBytes))
    (fun pair => ⟨pair.1, pair.2⟩)
    (by intro value; cases value; rfl)

def finalizedFrame : List UInt8 :=
  "DREGG/GRAIN-RESOURCE-BIRTH/FINALIZED-DRAFT/v1".toUTF8.toList

def finalizedCodec : LawfulCodec Finalized :=
  (StreamCodec.framed finalizedFrame finalizedStream).toLawful

theorem finalizedCodec_canonical {bytes : List UInt8} {value : Finalized}
    (decoded : finalizedCodec.decode bytes = some value) :
    finalizedCodec.encode value = bytes :=
  StreamCodec.toLawful_canonical _ _ _ decoded

end Minidregg.Compiler.GrainResourceBirthHostCodec

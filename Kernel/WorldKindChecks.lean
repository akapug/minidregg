/- Narrow executable refutations for descriptor and instance preparation.
These are not native admission journeys. -/
import Kernel.WorldKindInstance
import Theory.AssertCompiled

namespace Minidregg.Kernel.WorldKindChecks

open Minidregg.Compiler
open Minidregg.Compiler.WorldKindDescriptor
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel.WorldKindInstance

def poll : Descriptor :=
  ⟨500, 0,
    [⟨1, "question", "The question this poll asks", .bytes, .rom⟩,
     ⟨2, "votes", "Each subject's recorded choice", .natural, .appendOnly⟩,
     ⟨3, "open", "Whether this poll accepts votes", .natural, .ram⟩]⟩

def emptyPoll : Instance := ⟨poll, by decide, 0⟩

/-! ## The general facts the instance checks specialise

Every trailing-byte refusal and every unknown-field refusal below is an instance of a ∀ proved
here; the instances stay as named corollaries. The remaining instances (a duplicate or empty
field name, a value that does not decode, a ROM write, a double create, a stale expected value,
a changed StoreCodec frame) are closed evaluations: kernel `decide` where it reaches, and
`native_decide` + `#assert_compiled` where they run through the layout digest. -/

/-- A prefix codec made top-level refuses every trailing byte after a value's encoding. -/
theorem toLawful_decode_encode_append {α : Type} (codec : StreamCodec α) (value : α)
    {rest : List UInt8} (nonempty : rest ≠ []) :
    codec.toLawful.decode (codec.encode value ++ rest) = none := by
  simp [StreamCodec.toLawful, codec.decodePrefix_encode, nonempty]

/-- The definition decoder refuses every encoding followed by trailing bytes. -/
theorem decodeDefinition_encode_append (descriptor : Descriptor) {rest : List UInt8}
    (nonempty : rest ≠ []) :
    decodeDefinition (descriptorCodec.encode descriptor ++ rest) = none := by
  have refused : descriptorCodec.decode (descriptorCodec.encode descriptor ++ rest) = none := by
    show descriptorStream.toLawful.decode (descriptorStream.encode descriptor ++ rest) = none
    exact toLawful_decode_encode_append descriptorStream descriptor nonempty
  unfold decodeDefinition
  rw [refused]
  rfl

/-- The definition decoder accepts a canonical encoding exactly when the descriptor is valid. -/
theorem decodeDefinition_encode_isSome_iff (descriptor : Descriptor) :
    (decodeDefinition (descriptorCodec.encode descriptor)).isSome = true ↔ descriptor.Valid := by
  unfold decodeDefinition
  rw [descriptor_roundtrip]
  by_cases valid : descriptor.Valid <;> simp [valid]

/-- The instance decoder inverts the encoder, for every instance. -/
theorem decode_encode (value : Instance) : decode (encode value) = some value := by
  obtain ⟨descriptor, valid, store⟩ := value
  have definition : decodeDefinition (descriptorCodec.encode descriptor) =
      some ⟨descriptor, valid⟩ := by
    simp [decodeDefinition, descriptor_roundtrip, valid]
  have pair := (StreamCodec.product bytesStream bytesStream).toLawful.decode_encode
    (descriptorCodec.encode descriptor, StoreCodec.encode (wire descriptor) store)
  simp only [decode, encode, List.take_left', List.drop_left', bne_self_eq_false]
  simp [StreamCodec.toLawful] at pair ⊢
  simp [pair, definition, StoreCodec.decode_encode, bytesEqual_eq_true_iff]

/-- The instance decoder refuses every encoding followed by trailing bytes. -/
theorem decode_encode_append (value : Instance) {rest : List UInt8} (nonempty : rest ≠ []) :
    decode (encode value ++ rest) = none := by
  have refused := (StreamCodec.product bytesStream bytesStream).decodePrefix_encode
    (descriptorCodec.encode value.descriptor, StoreCodec.encode (wire value.descriptor) value.store) rest
  unfold decode encode
  rw [List.append_assoc]
  simp [StreamCodec.toLawful, refused, nonempty]

/-- An action naming no field of the descriptor lowers to nothing. -/
theorem lower_unknown_field {descriptor : Descriptor} {action : Action}
    (unknown : findField descriptor action.field = none) :
    WorldKindInstance.lower descriptor action = none := by
  unfold WorldKindInstance.lower
  rw [unknown]
  rfl

/-- One refused action refuses the whole batch, wherever it sits. -/
theorem lowerAll_eq_none_of_mem {descriptor : Descriptor} {action : Action} :
    ∀ {actions : List Action}, action ∈ actions → WorldKindInstance.lower descriptor action = none →
      lowerAll descriptor actions = none
  | _ :: _, .head _, refused => by simp [lowerAll, refused]
  | head :: _, .tail _ mem, refused => by
      cases h : WorldKindInstance.lower descriptor head <;>
        simp [lowerAll, h, lowerAll_eq_none_of_mem mem refused]

theorem prepare_eq_none_of_mem {value : Instance} {actions : List Action} {action : Action}
    (mem : action ∈ actions) (refused : WorldKindInstance.lower value.descriptor action = none) :
    prepare value actions = none := by
  simp [prepare, lowerAll_eq_none_of_mem mem refused]

#assert_axioms toLawful_decode_encode_append decodeDefinition_encode_append
  decodeDefinition_encode_isSome_iff decode_encode decode_encode_append lower_unknown_field
  lowerAll_eq_none_of_mem prepare_eq_none_of_mem

/-! ## Instances -/

theorem poll_valid : poll.Valid := by decide

theorem poll_definition_accepted : (decodeDefinition (descriptorCodec.encode poll)).isSome = true :=
  (decodeDefinition_encode_isSome_iff poll).2 poll_valid

theorem duplicate_field_name_refused : (decodeDefinition (descriptorCodec.encode { poll with
    fields := poll.fields ++ [⟨2, "duplicate", "Duplicates the votes field", .natural, .ram⟩] })).isSome
      = false := by
  rw [Bool.eq_false_iff, ne_eq, decodeDefinition_encode_isSome_iff]
  decide

theorem empty_field_name_refused : (decodeDefinition (descriptorCodec.encode { poll with
    fields := [⟨1, "", "Meaning", .natural, .ram⟩] })).isSome = false := by
  rw [Bool.eq_false_iff, ne_eq, decodeDefinition_encode_isSome_iff]
  decide

theorem empty_field_meaning_refused : (decodeDefinition (descriptorCodec.encode { poll with
    fields := [⟨1, "title", "", .natural, .ram⟩] })).isSome = false := by
  rw [Bool.eq_false_iff, ne_eq, decodeDefinition_encode_isSome_iff]
  decide

theorem poll_definition_trailing_refused :
    decodeDefinition (descriptorCodec.encode poll ++ [0]) = none :=
  decodeDefinition_encode_append poll (List.cons_ne_nil _ _)

theorem emptyPoll_roundtrip : decode (encode emptyPoll) = some emptyPoll := decode_encode emptyPoll

theorem emptyPoll_trailing_refused : decode (encode emptyPoll ++ [0]) = none :=
  decode_encode_append emptyPoll (List.cons_ne_nil _ _)

/- No operation invents a field or writes ROM after birth. -/
theorem create_unknown_field_refused :
    prepare emptyPoll [.create 99 0 (StreamCodec.nat.encode 1)] = none :=
  prepare_eq_none_of_mem (List.mem_singleton.2 rfl) (lower_unknown_field (by decide))

#assert_axioms poll_valid poll_definition_accepted duplicate_field_name_refused
  empty_field_name_refused empty_field_meaning_refused poll_definition_trailing_refused
  emptyPoll_roundtrip emptyPoll_trailing_refused create_unknown_field_refused

theorem rom_create_after_birth_refused :
    (prepare emptyPoll [.create 1 0 (bytesStream.encode [65])]).isSome = false := by native_decide
theorem noncanonical_value_refused :
    (prepare emptyPoll [.create 2 7 [255, 0]]).isSome = false := by native_decide
theorem append_only_create_accepted :
    (prepare emptyPoll [.create 2 7 (StreamCodec.nat.encode 1)]).isSome = true := by native_decide
theorem append_only_write_refused :
    (prepare emptyPoll [.create 2 7 (StreamCodec.nat.encode 1),
      .write 2 7 (StreamCodec.nat.encode 1) (StreamCodec.nat.encode 2)]).isSome = false := by
  native_decide
theorem double_create_refused :
    (prepare emptyPoll [.create 2 7 (StreamCodec.nat.encode 1),
      .create 2 7 (StreamCodec.nat.encode 2)]).isSome = false := by native_decide
theorem ram_write_accepted :
    (prepare emptyPoll [.create 3 0 (StreamCodec.nat.encode 1),
      .write 3 0 (StreamCodec.nat.encode 1) (StreamCodec.nat.encode 0)]).isSome = true := by
  native_decide
theorem ram_write_stale_expected_refused :
    (prepare emptyPoll [.create 3 0 (StreamCodec.nat.encode 1),
      .write 3 0 (StreamCodec.nat.encode 2) (StreamCodec.nat.encode 0)]).isSome = false := by
  native_decide
#assert_compiled rom_create_after_birth_refused
#assert_compiled noncanonical_value_refused
#assert_compiled append_only_create_accepted
#assert_compiled append_only_write_refused
#assert_compiled double_create_refused
#assert_compiled ram_write_accepted
#assert_compiled ram_write_stale_expected_refused

/- Merely retaining a field's integer codec and address does not preserve its
meaning. The descriptor and StoreCodec frame both change. -/
def changedMeaning : Descriptor :=
  { poll with fields := [⟨3, "membership", "Membership administration", .natural, .ram⟩] }

/-- Distinct descriptors have distinct encodings (the codec is lawful, so injective). -/
theorem changedMeaning_encoding_differs :
    descriptorCodec.encode poll ≠ descriptorCodec.encode changedMeaning := by
  intro same
  have := congrArg (fun d => d.fields.length)
    (ResourceBirthCodec.lawful_encode_injective descriptorCodec same)
  simp [poll, changedMeaning] at this
#assert_axioms changedMeaning_encoding_differs

theorem changedMeaning_frame_differs :
    (StoreCodec.frame (wire poll) != StoreCodec.frame (wire changedMeaning)) = true := by
  native_decide
#assert_compiled changedMeaning_frame_differs

end Minidregg.Kernel.WorldKindChecks

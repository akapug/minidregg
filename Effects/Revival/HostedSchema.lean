/- A bounded transport-descriptor vocabulary. Authority remains current Mini admission. -/
module
public import Lean.Data.Json
@[expose] public section
namespace Minidregg.Effects.Revival.HostedSchema
inductive Schema where
  | text (minimum maximum : Nat) (choices : List String)
  | natural (minimum maximum : Nat)
  | identifier (maximum : Nat)
  | hex (maximum : Nat)
  | array (maximum : Nat) (element : Schema)
  | object (fields : List (String × Schema))
  | oneOf (schemas : List Schema)

def validate : Nat → Schema → Lean.Json → Bool
  | 0, _, _ => false
  | fuel + 1, schema, value =>
    match schema with
    | .text minimum maximum choices =>
      match value.getStr? with
      | .error _ => false
      | .ok text => decide (minimum ≤ text.utf8ByteSize ∧ text.utf8ByteSize ≤ maximum) &&
          (choices.isEmpty || choices.contains text)
    | .natural minimum maximum =>
      match value.getNat? with
      | .error _ => false
      | .ok number => decide (minimum ≤ number ∧ number ≤ maximum)
    | .identifier maximum =>
      match value.getStr? with
      | .error _ => false
      | .ok text => !text.isEmpty && decide (text.utf8ByteSize ≤ maximum) &&
          text.toList.all (fun c => c.isAlphanum && decide (c.toNat < 128) || c == '-' || c == '_')
    | .hex maximum =>
      match value.getStr? with
      | .error _ => false
      | .ok text => decide (text.utf8ByteSize ≤ 2 * maximum) &&
          decide (text.utf8ByteSize % 2 = 0) &&
          text.toList.all (fun c => c.isDigit || decide ('a' ≤ c ∧ c ≤ 'f'))
    | .array maximum element =>
      match value.getArr? with
      | .error _ => false
      | .ok values => decide (values.size ≤ maximum) && values.all (validate fuel element)
    | .oneOf schemas => schemas.any (fun schema => validate fuel schema value)
    | .object fields =>
      match value.getObj? with
      | .error _ => false
      | .ok object => decide (object.size = fields.length) && fields.all (fun (name, field) =>
          match object.get? name with
          | none => false
          | some child => validate fuel field child)
end Minidregg.Effects.Revival.HostedSchema

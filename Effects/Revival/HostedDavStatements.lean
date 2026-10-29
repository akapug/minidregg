/- Hosted DAV declaration contract. The receiver supplies origin/prefix custody. -/
module
public import Effects.Revival.HostedDav
@[expose] public section
namespace Minidregg.Effects.Revival.HostedDav
/-- Any candidate header evaluator must discriminate method and exact parameter value. -/
def Keystone (evaluate : List UInt8 → List UInt8 → List UInt8 → Bool) : Prop :=
  ∀ method name value, evaluate method name value = headerAllowed method name value
def Satisfiable : Prop :=
  headerAllowed "MOVE".toUTF8.toList "overwrite".toUTF8.toList "F".toUTF8.toList = true
def Teeth : Prop :=
  headerAllowed "MOVE".toUTF8.toList "depth".toUTF8.toList "1".toUTF8.toList = false ∧
  headerAllowed "COPY".toUTF8.toList "overwrite".toUTF8.toList "maybe".toUTF8.toList = false
def Premise : Prop := ∃ evaluate, Keystone evaluate
end Minidregg.Effects.Revival.HostedDav

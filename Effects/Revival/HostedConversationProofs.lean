/- Inhabited trace poles. These do not assert the native receiving refinement. -/
module
public import Effects.Revival.HostedConversationStatements
public import Theory.AxiomPin
import all Init.Data.List.Basic
@[expose] public section
namespace Minidregg.Effects.Revival.HostedConversation
theorem satisfiable : Satisfiable := by
  simp [Satisfiable, Receives, checks, delivered, exactPole]
theorem teeth : Teeth := by
  simp [Teeth, Receives, checks, delivered, replayed, ghost, exactPole,
    sameOperation, poleIntent, poleBinding]
theorem premise : Premise := ⟨(fun _ => True), poleIntent, trivial, satisfiable⟩
#assert_axioms satisfiable
#assert_axioms teeth
#assert_axioms premise
end Minidregg.Effects.Revival.HostedConversation

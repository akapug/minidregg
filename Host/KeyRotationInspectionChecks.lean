/- Signature-critical inspection checks: canonical framing alone does not
bind a possession header to the command that a client displays. -/
import Host.Json

namespace Minidregg.Host.KeyRotationInspectionChecks
open Minidregg.Kernel

private def command : SubjectKeyRotation.Command :=
  ⟨⟨9⟩, 31, ⟨18, 5, 1, 9, List.replicate 32 (2 : UInt8), 0, 100, some ⟨77⟩⟩⟩
private def plan : SubjectKeyRotation.SigningPlan :=
  ⟨⟨8501⟩, ⟨27⟩, SubjectKeyRotation.commandCodec.encode command,
    SubjectKeyRotation.possessionFrame ⟨8501⟩ ⟨27⟩ command⟩
private def accepts (value : SubjectKeyRotation.SigningPlan) : Bool :=
  (Minidregg.Host.Json.inspect "subject-key-rotation-plan"
    (SubjectKeyRotation.signingPlanCodec.encode value)).isOk

/-! The inspection route runs the Host's JSON renderer over the canonical plan bytes, so only the
compiled evaluator reaches these instances: `native_decide` + `#assert_compiled`. -/

theorem canonical_plan_accepted : accepts plan = true := by native_decide
theorem foreign_possession_header_refused :
    accepts { plan with possessionHeader := [0] } = false := by native_decide
theorem other_domain_refused : accepts { plan with domain := ⟨8502⟩ } = false := by native_decide
theorem other_command_refused :
    accepts { plan with
      commandBytes := SubjectKeyRotation.commandCodec.encode { command with nonce := 32 } }
      = false := by
  native_decide
#assert_compiled canonical_plan_accepted
#assert_compiled foreign_possession_header_refused
#assert_compiled other_domain_refused
#assert_compiled other_command_refused

end Minidregg.Host.KeyRotationInspectionChecks

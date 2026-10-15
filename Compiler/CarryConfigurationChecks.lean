import Compiler.CarryConfiguration
import Theory.AssertCompiled

namespace Minidregg.Compiler.CarryConfigurationChecks
open Lean
open CarryConfiguration
set_option autoImplicit false

private def source : Json := Json.mkObj [
  ("domain", toJson (1 : Nat)),
  ("expectedSeed", toJson (123456789012345678901234567890123456789 : Nat)),
  ("disabledEvaluators", toJson (["nock"] : List String)),
  ("storageRoot", .str "/retained/source"),
  ("extension", .str "must remain bound")]
private def target : Json :=
  (source.setObjVal! "birthSlack" (toJson (0 : Nat))).setObjVal!
    "storageRoot" (.str "/isolated/target")
private def accepts (next : Json) : Bool :=
  match checkLegacy source next with
  | .ok () => true
  | .error _ => false

/-! `checkLegacy` walks `Lean.Json` objects (an RB-map), so these instances are compiled
evaluations: `native_decide` + `#assert_compiled`. -/

-- Relocation is permitted while all authority-affecting settings remain fixed.
theorem relocation_accepted : accepts target = true := by native_decide
-- A new default must not expand the old birth window.
theorem missing_birth_slack_refused : accepts source = false := by native_decide
theorem wider_birth_slack_refused :
    accepts (target.setObjVal! "birthSlack" (toJson (64 : Nat))) = false := by native_decide
-- Disabled evaluators and unknown extension settings remain in the gate.
theorem enabled_evaluators_refused :
    accepts (target.setObjVal! "disabledEvaluators" (toJson ([] : List String))) = false := by
  native_decide
theorem changed_extension_refused :
    accepts (target.setObjVal! "extension" (.str "changed")) = false := by native_decide
-- Adjacent values far above IEEE754 integer precision remain distinguishable.
theorem adjacent_seed_refused : accepts (target.setObjVal! "expectedSeed"
    (toJson (123456789012345678901234567890123456788 : Nat))) = false := by native_decide
#assert_compiled relocation_accepted
#assert_compiled missing_birth_slack_refused
#assert_compiled wider_birth_slack_refused
#assert_compiled enabled_evaluators_refused
#assert_compiled changed_extension_refused
#assert_compiled adjacent_seed_refused

end Minidregg.Compiler.CarryConfigurationChecks

/- Receiving poles for the actual Store2 paid payload boundary. The shared
PayCellUpgrade proofs cover typed rows; these checks also exercise the frozen
source frame and the final target decoder path. -/
import Compiler.LegacyStoreCarry
import Theory.AssertCompiled

namespace Minidregg.Compiler.LegacyStoreCarryChecks
open Minidregg.Kernel
open LegacyStoreCarry
set_option autoImplicit false

private def sourceBytes : List UInt8 :=
  encodeV2 PayCellLegacyV4.wire PayCellLegacyV4.enrolledFixture

private def refuses (bytes : List UInt8) : Bool :=
  match decodePay bytes with
  | .error _ => true
  | .ok _ => false

private def enrolledCarry : Bool :=
  match decodePay sourceBytes with
  | .error _ => false
  | .ok store =>
      PayCell.enrolmentAt store PayEnrolMemo.fixtureMemo.miniKey ==
          some ⟨PayEnrolMemo.fixtureMemo.sshBlob, 108, some 1, 500168, 900⟩ &&
        PayCell.sshIndexAt store PayEnrolMemo.fixtureMemo.sshBlob ==
          some PayEnrolMemo.fixtureMemo.miniKey &&
        PayCell.tariffOf store ==
          (PayCellLegacyV4.tariffOf PayCellLegacyV4.enrolledFixture).map
            PayCellUpgrade.liftTariff &&
        (PayCell.tariffOf store).map (·.nodeWeekRate) == some (168 * 5952380) &&
        (PayCell.computeActivationOf store).isNone &&
        (PayCell.computeUsageAt store 108).isNone &&
        (PayCell.chainTipOf store).isNone &&
        (PayCell.claimAt store [1, 2, 3]).isNone &&
        (PayCell.claimConsumptionAt store [1, 2, 3]).isNone

/-! `decodePay` checks the frozen layout descriptor (and the frame carries its digest), so these
instances are compiled evaluations: `native_decide` + `#assert_compiled`. -/

theorem enrolled_carry : enrolledCarry = true := by native_decide
-- A newer outer frame does not silently widen the source language.
theorem current_frame_old_payload_refused :
    refuses (StoreCodec.encode PayCellLegacyV4.wire PayCellLegacyV4.enrolledFixture) = true := by
  native_decide
-- Neither current target bytes nor a current payload in an old frame is old v4.
theorem current_target_bytes_refused : refuses (StoreCodec.encode PayCell.wire
    (PayCellUpgrade.lift PayCellLegacyV4.enrolledFixture)) = true := by native_decide
theorem current_payload_old_frame_refused : refuses (encodeV2 PayCell.wire
    (PayCellUpgrade.lift PayCellLegacyV4.enrolledFixture)) = true := by native_decide
theorem trailing_byte_refused : refuses (sourceBytes ++ [0]) = true := by native_decide
theorem truncated_source_refused : refuses sourceBytes.dropLast = true := by native_decide
#assert_compiled enrolled_carry
#assert_compiled current_frame_old_payload_refused
#assert_compiled current_target_bytes_refused
#assert_compiled current_payload_old_frame_refused
#assert_compiled trailing_byte_refused
#assert_compiled truncated_source_refused

end Minidregg.Compiler.LegacyStoreCarryChecks

/- The operator's Objective invocation pin, one definition for every process
that opens a Store under it: the native Host (`Host.Main`) and the local
consent provider (`Host.ClientConsentCore`). The pin enters the runtime
semantics (`NativeHost.Config.invocationBindings`), so a provider that parsed a
different policy, or none, would verify against other semantics. -/
module

public import Kernel.ObjectiveBendNativeAdmission
public import Kernel.NativeHost
public import Host.SourceAgreementJson
public import Lean.Data.Json

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

namespace Minidregg.Host
open Lean

/-- Canonical deployment policy for the Objective invocation family. Its
edition and full capacities enter the native runtime semantics. A network
request cannot choose or replace this operator pin. -/
structure ObjectiveInvocationSettings where
  policy : Minidregg.Kernel.ObjectiveBendNativeAdmission.Policy

instance : FromJson ObjectiveInvocationSettings where
  fromJson? json := do
    let value ← json.getStr?
    unless value.utf8ByteSize ≤ 8192 do
      throw "objectiveInvocation exceeds the 4096-byte policy envelope"
    let bytes ← Minidregg.Host.SourceAgreementJson.decodeHex "objectiveInvocation" json
    unless Minidregg.Host.SourceAgreementJson.encodeHex bytes == value do
      throw "objectiveInvocation must use canonical lowercase hex"
    let some policy := Minidregg.Kernel.ObjectiveBendNativeAdmission.decodePolicy bytes
      | throw "objectiveInvocation is not a canonical Objective policy"
    unless policy.edition == Minidregg.Kernel.ObjectiveBendNativeAdmission.semanticsId do
      throw "objectiveInvocation has an unsupported Objective edition"
    unless decide policy.outputs.Nodup do
      throw "objectiveInvocation contains duplicate output schemas"
    pure ⟨policy⟩

instance : ToJson ObjectiveInvocationSettings where
  toJson pin := .str (Minidregg.Host.SourceAgreementJson.encodeHex
    (Minidregg.Kernel.ObjectiveBendNativeAdmission.encodePolicy pin.policy))

/-- The runtime binding the pin installs. -/
def ObjectiveInvocationSettings.bindings (pin : Option ObjectiveInvocationSettings) :
    Option (List (Minidregg.Compiler.NativeInvocationStatement.Route × List UInt8)) :=
  pin.map fun pin =>
    [(Minidregg.Compiler.NativeInvocationStatement.Route.objectiveMethod,
      Minidregg.Kernel.ObjectiveBendNativeAdmission.encodePolicy pin.policy)]

end Minidregg.Host

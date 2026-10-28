/- Authenticate the command-bound authority envelope before preparing effects.

This is an early cryptographic refusal boundary, not a replacement for the
receiver's current capability, field, observation, audience or execution checks.
The request is the existing authority incidence request; it hashes the complete
canonical command without running its content actions or claimed computation.
-/
module

public import Kernel.ResourceTransaction
public import Compiler.CredentialSignatureAdmission
public import Theory.AssertAxioms

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
import all Init.System.ST
import all Init.System.IO

@[expose] public section

namespace Minidregg.Kernel.ResourceInvocationSignatureFirst

open Minidregg.Kernel.DeclaredResourceController
open Minidregg.Compiler
open Minidregg.Compiler.CredentialAuthorityDomainReceiver
open Minidregg.Theory.TypedAuthorization

set_option autoImplicit false

def authenticate (native : CredentialSignatureIO.NativeConfig)
    (deployment : Deployment) (semantics : Digest)
    (ambient : Ambient) (ground : Ground deployment) (command : Command)
    (authorityEnvelope : List UInt8) : IO (Except Reject Unit) := do
  if command.targets.isEmpty then
    return .error .emptyTargets
  let snapshot := ground.authority
  match ← CredentialSignatureAdmission.verifyNative native snapshot
      (operationMarker snapshot.domain semantics command)
      (request snapshot semantics ambient command snapshot.cell.root)
      authorityEnvelope with
  | .error reason => return .error (.authoritySignature reason)
  | .ok _ => return .ok ()

/-- The expensive continuation is selected only after authentication succeeds.
No positive result here bypasses the continuation's full native admission. -/
def continueAfter {R : Type} (result : Except Reject Unit)
    (onRefusal : Reject → IO R) (prepareAndAdmit : IO R) : IO R :=
  match result with
  | .error reason => onRefusal reason
  | .ok () => prepareAndAdmit

theorem refused_skipsPreparation {R : Type} (reason : Reject)
    (onRefusal : Reject → IO R) (prepareAndAdmit : IO R) :
    continueAfter (.error reason) onRefusal prepareAndAdmit = onRefusal reason := rfl

theorem authenticated_keepsFullAdmission {R : Type}
    (onRefusal : Reject → IO R) (prepareAndAdmit : IO R) :
    continueAfter (.ok ()) onRefusal prepareAndAdmit = prepareAndAdmit := rfl

/-- The precheck request is precisely the existing authority incidence family,
including the complete canonical command digests and the shared marker. -/
theorem request_isAuthorityIncidence (snapshot : AuthoritySnapshot) (semantics : Digest)
    (ambient : Ambient) (command : Command) :
    (markerFamily snapshot semantics ambient).request command =
      ⟨command.first.kind, request snapshot semantics ambient command snapshot.cell.root⟩ := rfl

#assert_axioms refused_skipsPreparation
#assert_axioms authenticated_keepsFullAdmission
#assert_axioms request_isAuthorityIncidence

end Minidregg.Kernel.ResourceInvocationSignatureFirst

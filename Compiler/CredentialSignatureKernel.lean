/-
# Compiler.CredentialSignatureKernel — the minimal native signature seam

Kept separate from `CredentialSignatureIO` so the mini-kernel dynlib needs only
this module's `Init` closure when `lean --run` resolves the extern wrappers.
The Lean bodies refuse; compiled code calls the strict Ed25519/SSHSIG kernels
in `native/mini-kernels` through the C shim.
-/
module

public import Init

@[expose] public section

namespace Minidregg.Compiler.CredentialSignatureIO

set_option autoImplicit false

/-- Plain Ed25519 `verify_strict` over the opaque frame. -/
@[extern "mini_ed25519_verify"]
def ed25519Kernel (publicKey frame signature : @& ByteArray) : UInt8 :=
  2

/-- SSHSIG signed-data construction (including SHA-512) and `verify_strict`. -/
@[extern "mini_sshsig_verify"]
def sshsigKernel (publicKey nameSpace message signature : @& ByteArray) : UInt8 :=
  2

end Minidregg.Compiler.CredentialSignatureIO

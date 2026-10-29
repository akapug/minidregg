/-
# Compiler.CredentialSignatureKernel — the minimal native signature seam

Kept separate from `CredentialSignatureIO` so the mini-kernel dynlib needs only
this module's `Init` closure when `lean --run` resolves the extern wrappers.
They are `opaque`: the logic knows nothing about a verdict (there is no Lean model of
Ed25519 to state one against), so no theorem can conclude anything about what the
live verifier answers; compiled code calls the strict Ed25519/SSHSIG kernels in
`native/mini-kernels` through the C shim.
-/
module

public import Init

@[expose] public section

namespace Minidregg.Compiler.CredentialSignatureIO

set_option autoImplicit false

/-- Plain Ed25519 `verify_strict` over the opaque frame. -/
@[extern "mini_ed25519_verify"]
opaque ed25519Kernel (publicKey frame signature : @& ByteArray) : UInt8

/-- SSHSIG signed-data construction (including SHA-512) and `verify_strict`. -/
@[extern "mini_sshsig_verify"]
opaque sshsigKernel (publicKey nameSpace message signature : @& ByteArray) : UInt8

end Minidregg.Compiler.CredentialSignatureIO

/-
# Compiler.Sp800185Kmac256 -- KMAC256 on the Lean-owned Keccak core

NIST SP 800-185 KMAC256 with a 256-bit output:

  KMAC256(K, X, 256, S) = cSHAKE256(bytepad(encode_string(K), 136) ‖ X ‖ right_encode(256),
                                    256, "KMAC", S)

The permutation, padding and `bytepad`/`encode_string` framing are the ones
`Sp800185Cshake256Core` already exports; this module adds `right_encode`, the
function-name field, and the byte-array fast path proved equal to it
(`kmac256Fast_eq`, attached with `@[csimp]`).  It is the host's checkpoint and log
authenticator (`Compiler.DurableCheckpointCodec`).  No unforgeability theorem
is stated here: KMAC's PRF security is the standard's, not a Lean proof.

The two conformance theorems compare against an independent implementation
(pycryptodome 3.x `Crypto.Hash.KMAC256`, `mac_len=32`); NIST publishes KMAC256
samples only at L = 512, and L enters the MAC through `right_encode(L)`.
-/
module

public import Theory.Sp800185Cshake256Core
meta import Theory.Sp800185Cshake256Core

@[expose] public section

namespace Minidregg.Compiler.Sp800185Cshake256

set_option autoImplicit false

/-- SP 800-185 `right_encode`: the minimal big-endian bytes, then their count. -/
def rightEncode (value : Nat) : List UInt8 :=
  let bytes := natBytesBE value
  bytes ++ [UInt8.ofNat bytes.length]

/-- The encoded function name and customization for KMAC. -/
def kmacPrefix (customization : List UInt8) : List UInt8 :=
  bytepad (encodeString "KMAC".toUTF8.toList ++ encodeString customization) rateBytes

/-- KMAC256 with a 32-byte tag. -/
def kmac256Bytes (key customization input : List UInt8) : List UInt8 :=
  let newX := bytepad (encodeString key) rateBytes ++ input ++ rightEncode 256
  squeeze32 (absorbPadded (padForRate (kmacPrefix customization ++ newX) 0x04))

theorem kmac256Bytes_length (key customization input : List UInt8) :
    (kmac256Bytes key customization input).length = 32 := by
  simp [kmac256Bytes, squeeze32, outputBytes]

/-! ## The compiled path -/

open Fast in
/-- KMAC256 on the fast path: the key block, the input and the length suffix are
pushed once into a byte array and absorbed by the word permutation. -/
def kmac256Fast (key customization input : List UInt8) : List UInt8 :=
  spongeBytes (pushList (pushList (pushList (pushList ByteArray.empty (kmacPrefix customization))
    (bytepad (encodeString key) rateBytes)) input) (rightEncode 256)) 0x04

open Fast in
/-- **KMAC refinement**: for every key, customization and message, the fast
path is `kmac256Bytes`. -/
theorem kmac256Fast_eq (key customization input : List UInt8) :
    kmac256Fast key customization input = kmac256Bytes key customization input := by
  simp only [kmac256Fast, kmac256Bytes, sponge_fast_eq, pushList_data, empty_data,
    List.nil_append, List.append_assoc]

/-- The fast path is `kmac256Bytes`; not the `@[csimp]` attachment (that is the kernel seam
below, whose Lean body is this fast path). -/
theorem kmac256Bytes_eq_fast : kmac256Bytes = kmac256Fast := by
  funext key customization input
  exact (kmac256Fast_eq key customization input).symm

/-! ## The kernel seam (HOT-PATH 2d, as `Theory.Sp800185Cshake256Native`) -/

open Native in
/-- **The kernel seam.** KMAC256 with a 32-byte tag on byte arrays: the Lean body is the proved
fast path; the compiled code is `mini_kmac256_32` (`native/mini-kernels`). The equality of the
Rust to this body is pinned by the Lean vectors and by the two `native_decide` conformance
theorems below, which evaluate the compiled path. -/
@[extern "mini_kmac256_32"]
def kmac256Kernel (key customization input : @& ByteArray) : ByteArray :=
  bytesOfList (kmac256Fast key.data.toList customization.data.toList input.data.toList)

open Native in
/-- The spec's shape over the kernel: what the compiled `kmac256Bytes` runs. -/
def kmac256Native (key customization input : List UInt8) : List UInt8 :=
  (kmac256Kernel (bytesOfList key) (bytesOfList customization) (bytesOfList input)).data.toList

open Native in
/-- **The seam's Lean body is `kmac256Bytes`**, for every key, customization and message. -/
theorem kmac256Native_eq (key customization input : List UInt8) :
    kmac256Native key customization input = kmac256Bytes key customization input := by
  unfold kmac256Native kmac256Kernel
  rw [bytesOfList_toList, bytesOfList_toList, bytesOfList_toList, bytesOfList_toList,
    kmac256Fast_eq]

/-- The compiled Host's KMAC256 is the kernel seam. -/
@[csimp] theorem kmac256Bytes_eq_native : kmac256Bytes = kmac256Native := by
  funext key customization input
  exact (kmac256Native_eq key customization input).symm

/-! The conformance vectors (`kmacVectorKey`, the two pycryptodome rows, `kmac256_key_separates`)
live in `Compiler.Sp800185Kmac256Conformance`: they are `native_decide` facts about the compiled
path, which after `kmac256Bytes_eq_native` is the kernel seam of THIS module, and the interpreter
resolves that seam through this module's compiled object (`scripts/build-mini-kernels.sh`), which
cannot exist while this module is still being elaborated. -/

end Minidregg.Compiler.Sp800185Cshake256

/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_length' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_length
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256Fast_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256Fast_eq
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_eq_fast' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_eq_fast
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256Native_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256Native_eq
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_eq_native' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256Bytes_eq_native

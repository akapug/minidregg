/-
# Compiler.Sp800185Kmac256Conformance -- KMAC256 known answers, evaluated through the kernel seam

The three `native_decide` facts below evaluate the COMPILED `kmac256Bytes`, which after
`kmac256Bytes_eq_native` (`Compiler.Sp800185Kmac256`) is the Rust kernel `mini_kmac256_32`
(native/mini-kernels) behind the seam: with the seam library loaded (`scripts/build-mini-kernels.sh`,
the lakefile's `--load-dynlib`) every build of this module is the kernel's known-answer test against
an independent implementation (pycryptodome 3.x `Crypto.Hash.KMAC256`, `mac_len=32`). They sit in
their own module because the seam's compiled object must exist before anything evaluates it.
NIST publishes KMAC256 samples only at L = 512, and L enters the MAC through `right_encode(L)`.
-/
import Compiler.Sp800185Kmac256

namespace Minidregg.Compiler.Sp800185Cshake256

set_option autoImplicit false

def kmacVectorKey : List UInt8 := (List.range 32).map fun i => UInt8.ofNat (0x40 + i)

/-- pycryptodome: `KMAC256.new(key=bytes(range(0x40,0x60)), mac_len=32,
custom=b"My Tagged Application").update(bytes([0,1,2,3]))`. -/
def kmacVectorTagged : List UInt8 :=
  [0xf2, 0xd9, 0x5c, 0x33, 0xc9, 0xa2, 0x01, 0xeb, 0x10, 0xc5, 0x24, 0xb9, 0x08, 0x4b, 0x4b, 0xac,
   0xae, 0x00, 0x92, 0xf8, 0x69, 0x12, 0x2d, 0xf7, 0xd7, 0x87, 0x0b, 0x92, 0xc8, 0x42, 0xe0, 0x5b]

/-- pycryptodome, same key, `custom=b"DREGG/NATIVE-HOST/CHECKPOINT-MAC/v1"`,
message `b"abc"`. -/
def kmacVectorCheckpoint : List UInt8 :=
  [0xb1, 0x86, 0x2d, 0xc6, 0x69, 0x01, 0xcf, 0x8a, 0xd0, 0xde, 0x93, 0x23, 0x5e, 0x93, 0xa4, 0x87,
   0xec, 0x11, 0x0f, 0x46, 0xa6, 0x68, 0xa9, 0xb5, 0x12, 0x2e, 0x0d, 0xcb, 0x1e, 0xfa, 0x71, 0x1f]

theorem kmac256_conforms_tagged :
    kmac256Bytes kmacVectorKey "My Tagged Application".toUTF8.toList [0, 1, 2, 3] =
      kmacVectorTagged := by native_decide

theorem kmac256_conforms_checkpoint_customization :
    kmac256Bytes kmacVectorKey "DREGG/NATIVE-HOST/CHECKPOINT-MAC/v1".toUTF8.toList
      "abc".toUTF8.toList = kmacVectorCheckpoint := by native_decide

/-- The key is load-bearing: the same message and customization under a
different key gives a different tag. -/
theorem kmac256_key_separates :
    kmac256Bytes (kmacVectorKey.map (· + 1)) "My Tagged Application".toUTF8.toList
      [0, 1, 2, 3] ≠ kmacVectorTagged := by native_decide

end Minidregg.Compiler.Sp800185Cshake256

/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_tagged' depends on axioms: [propext, Quot.sound, Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_tagged._native.native_decide.ax_1_1] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_tagged
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_checkpoint_customization' depends on axioms: [propext, Quot.sound, Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_checkpoint_customization._native.native_decide.ax_1_1] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256_conforms_checkpoint_customization
/-- info: 'Minidregg.Compiler.Sp800185Cshake256.kmac256_key_separates' depends on axioms: [propext, Quot.sound, Minidregg.Compiler.Sp800185Cshake256.kmac256_key_separates._native.native_decide.ax_1_1] -/
#guard_msgs (whitespace := lax) in #print axioms Minidregg.Compiler.Sp800185Cshake256.kmac256_key_separates

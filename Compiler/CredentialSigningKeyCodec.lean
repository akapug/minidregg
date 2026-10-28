/-
# Compiler.CredentialSigningKeyCodec — the shared key-record codec

Extracted unchanged from CredentialSignedEnvelopeController. Both its signed
registry projection and the actual authority entry codec consume this one
stream; there is no independently encoded host key directory.
-/
module

public import Compiler.Tower256ConcreteBackend
public import Theory.CredentialSigningKey

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

namespace Minidregg.Compiler.CredentialSigningKeyCodec

open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Theory.CredentialSigningKey
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization (Digest)

set_option autoImplicit false

/-- Record v3: v2 plus the pre-rotation commitment `nextKeyDigest` as an
optional digest.  A v2 record does not decode as v3 (the option tag is missing
or misread and the strict codecs refuse the residue), so an authority cell
written before pre-rotation must be re-genesised. -/
abbrev KeyRecordTuple := Nat × Nat × Nat × Nat × List UInt8 × Nat × Nat × Option Digest

def keyRecordTupleStream : StreamCodec KeyRecordTuple :=
  StreamCodec.product StreamCodec.nat
    (StreamCodec.product StreamCodec.nat
      (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat
          (StreamCodec.product bytesStream
            (StreamCodec.product StreamCodec.nat
              (StreamCodec.product StreamCodec.nat (StreamCodec.option digestStream)))))))

def toTuple (key : KeyRecord) : KeyRecordTuple :=
  (key.keyId, key.keyEpoch, key.algorithm, key.subject, key.publicKey,
    key.activeFrom, key.activeUntil, key.nextKeyDigest)

def ofTuple : KeyRecordTuple → KeyRecord
  | (keyId, keyEpoch, algorithm, subject, publicKey, activeFrom, activeUntil, nextKeyDigest) =>
      { keyId, keyEpoch, algorithm, subject, publicKey, activeFrom, activeUntil, nextKeyDigest }

@[simp] theorem ofTuple_toTuple (key : KeyRecord) : ofTuple (toTuple key) = key := by
  cases key
  rfl

def keyRecordStream : StreamCodec KeyRecord :=
  StreamCodec.xmap keyRecordTupleStream toTuple ofTuple ofTuple_toTuple

def codec : LawfulCodec KeyRecord := keyRecordStream.toLawful

@[simp] theorem decode_encode (key : KeyRecord) :
    codec.decode (codec.encode key) = some key := codec.decode_encode key

end Minidregg.Compiler.CredentialSigningKeyCodec

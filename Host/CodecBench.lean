/-
# codec-bench -- the compiled Objective record decoder

`codec-bench <inputBytes> <checkpointBytes> <iterations>` builds one awaiting
`Kernel.ObjectiveActivity.Record` (four 32-octet digests, an await with a
32-octet id and two 8-octet heights) with payloads of the given sizes, encodes it
once outside the timed region, then runs `decodeRecord` on those bytes
`iterations` times and prints the decode count and the wall time. Run under
`perf stat -e instructions:u` to compare two builds. Not part of the umbrella gate.
-/
import Kernel.ObjectiveActivity

open Minidregg.Kernel.ObjectiveActivity
open Minidregg.Theory.TypedAuthorization (Digest SubjectId)

def benchBytes (n seed : Nat) : List UInt8 := Id.run do
  let mut acc : Array UInt8 := Array.mkEmpty n
  let mut x : UInt64 := UInt64.ofNat (seed * 2654435761 + 12345)
  for _ in [0:n] do
    x := x * 6364136223846793005 + 1442695040888963407
    acc := acc.push (x >>> 56).toUInt8
  return acc.toList

def digestOf (seed : Nat) : Digest := ⟨(seed * 0x9e3779b97f4a7c15 + 7) ^ 3 % 2 ^ 256⟩

def benchRecord (inputBytes checkpointBytes : Nat) : Record :=
  { object := digestOf 1, activity := digestOf 2, pin := digestOf 3,
    input := benchBytes inputBytes 1, generation := 3,
    checkpoint := benchBytes checkpointBytes 2, checkpointDigest := digestOf 4,
    escrow := { payer := ⟨5⟩, account := 6, resume := Minidregg.Kernel.ObjectiveTariff.zeroCapacity,
                timeout := Minidregg.Kernel.ObjectiveTariff.zeroCapacity, resumeFee := 7, timeoutFee := 8 },
    tried := 0,
    phase := .awaiting { id := digestOf 9, source := .reply (digestOf 10) ⟨11⟩, deadline := 1000, yieldedAt := 900 } }

def main (args : List String) : IO UInt32 := do
  let nums := args.filterMap String.toNat?
  let (inputBytes, checkpointBytes, iterations) :=
    match nums with
    | [a, b, c] => (a, b, c)
    | _ => (4096, 4096, 1000)
  let record := benchRecord inputBytes checkpointBytes
  let bytes := encodeRecord record
  if bytes.isEmpty then
    IO.eprintln "record does not fit"; return 2
  unless decodeRecord bytes == some record do
    IO.eprintln "record does not round-trip"; return 3
  let cell ← IO.mkRef bytes
  let t0 ← IO.monoNanosNow
  let mut decoded := 0
  for _ in [0:iterations] do
    let input ← cell.get
    if (decodeRecord input).isSome then decoded := decoded + 1
  let t1 ← IO.monoNanosNow
  IO.println s!"record {bytes.length} octets, decoded {decoded}/{iterations}, {(t1 - t0).toFloat / 1.0e6} ms"
  return 0

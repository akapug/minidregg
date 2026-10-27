import Lean

-- Exact isolated extractions from the reviewed source; no project imports.
namespace Minidregg.Compiler.Tower256ConcreteBackend
def sliceOnto (bytes : ByteArray) (start : Nat) :
    (count : Nat) -> start + count ≤ bytes.size -> List UInt8 -> List UInt8
  | 0, _, acc => acc
  | count + 1, fits, acc =>
      sliceOnto bytes start count (by omega) (bytes[start + count]'(by omega) :: acc)
end Minidregg.Compiler.Tower256ConcreteBackend

structure Entry where
  record : List UInt8
  tag : List UInt8
  deriving DecidableEq, Repr

structure HistoryRead where
  head : Nat
  entries : List (Nat × Entry)
  nodes : List (Nat × List UInt8 × Option (Nat × List UInt8))

private def u64At (bytes : ByteArray) (position : Nat) : Option Nat :=
  if position + 8 ≤ bytes.size then
    some <| (List.range 8).foldl (fun value index => value * 256 + (bytes.get! (position + index)).toNat) 0
  else none

/-- A length-prefixed blob, sliced straight out of the read buffer into a list
(`Tower256ConcreteBackend.sliceOnto`: one cell per octet, no intermediate copy). -/
private def blobAt (bytes : ByteArray) (position : Nat) : Option (List UInt8 × Nat) := do
  let length ← u64At bytes position
  let start := position + 8
  if fits : start + length ≤ bytes.size then
    some (Minidregg.Compiler.Tower256ConcreteBackend.sliceOnto bytes start length fits [], start + length)
  else none

private def u64Bytes (value : Nat) : List UInt8 :=
  (List.range 8).reverse.map fun index => (value / 256 ^ index % 256).toUInt8

private def blobBytes (bytes : List UInt8) : List UInt8 := u64Bytes bytes.length ++ bytes

private def historyEntriesAt (bytes : ByteArray) : Nat → Nat → List (Nat × Entry) →
    Option (List (Nat × Entry) × Nat)
  | 0, position, acc => some (acc.reverse, position)
  | count + 1, position, acc => do
      let height ← u64At bytes position
      let (record, afterRecord) ← blobAt bytes (position + 8)
      let (tag, afterTag) ← blobAt bytes afterRecord
      historyEntriesAt bytes count afterTag ((height, ⟨record, tag⟩) :: acc)

private def historyNodesAt (bytes : ByteArray) :
    Nat → Nat → List (Nat × List UInt8 × Option (Nat × List UInt8)) →
    Option (List (Nat × List UInt8 × Option (Nat × List UInt8)))
  | 0, position, acc => if position = bytes.size then some acc.reverse else none
  | count + 1, position, acc => do
      let space ← u64At bytes position
      let (key, afterKey) ← blobAt bytes (position + 8)
      let flag ← u64At bytes afterKey
      if flag = 0 then historyNodesAt bytes count (afterKey + 8) ((space, key, none) :: acc)
      else if flag = 1 then do
        let height ← u64At bytes (afterKey + 8)
        let (value, afterValue) ← blobAt bytes (afterKey + 16)
        historyNodesAt bytes count afterValue ((space, key, some (height, value)) :: acc)
      else none

/-- The `durable-history` output: u64 head; entries; nodes (see the helper). -/
def parseHistory (bytes : ByteArray) : Option HistoryRead := do
  let head ← u64At bytes 0
  let entryCount ← u64At bytes 8
  let (entries, afterEntries) ← historyEntriesAt bytes entryCount 16 []
  let nodeCount ← u64At bytes afterEntries
  let nodes ← historyNodesAt bytes nodeCount (afterEntries + 8) []
  some ⟨head, entries, nodes⟩

-- The audit's positional zip/value comparison, with already-encoded expected
-- values substituted for the unrelated Digest/index codecs. Counts actual
-- comparisons; it is NOT the full Store audit or its cryptographic replay.
def primitiveAudit (expectedValues : List (List UInt8)) (read : HistoryRead) : Except String Nat := do
  let mut checked := 0
  for (expected, found) in expectedValues.zip read.nodes do
    if found.2.2.map (·.2) ≠ some expected then
      throw "nonempty returned value differs"
    checked := checked + 1
  return checked

def zeroNodes : ByteArray := (u64Bytes 0 ++ u64Bytes 0 ++ u64Bytes 0).toByteArray

def singleNode (value : List UInt8) : ByteArray :=
  -- Deliberately unrelated head/space/key/future-version; the parser and
  -- positional value check never compare them with a request.
  (u64Bytes 0 ++ u64Bytes 0 ++ u64Bytes 1 ++ u64Bytes 99 ++
    blobBytes [255] ++ u64Bytes 1 ++ u64Bytes 999 ++ blobBytes value).toByteArray

instance : BEq (Except String Nat) where
  beq left right := match left, right with
    | .ok a, .ok b => a == b
    | .error a, .error b => a == b
    | _, _ => false

def main : IO Unit := do
  let some empty := parseHistory zeroNodes | throw (IO.userError "zero payload did not parse")
  let expected : List (List UInt8) := [[42], [43]]
  unless primitiveAudit expected empty == .ok 0 do
    throw (IO.userError "omission did not reproduce")
  IO.println s!"OMISSION accepted: expected={expected.length}, checked=0, returnedHead={empty.head}"
  let some short := parseHistory (singleNode [42]) | throw (IO.userError "short payload did not parse")
  unless primitiveAudit expected short == .ok 1 do
    throw (IO.userError "short prefix did not reproduce")
  IO.println "SHORT PREFIX accepted: expected=2, checked=1"
  unless primitiveAudit [[42]] short == .ok 1 do
    throw (IO.userError "identity mismatch did not reproduce")
  IO.println "IDENTITY MISMATCH accepted: head=0, space=99, key=[255], version=999; value=[42]"
  let some wrong := parseHistory (singleNode [99]) | throw (IO.userError "wrong-value payload did not parse")
  unless primitiveAudit [[42]] wrong == .error "nonempty returned value differs" do
    throw (IO.userError "negative control was not rejected")
  IO.println "NEGATIVE CONTROL refused: one returned value [99] differs from expected [42]"
  unless (parseHistory ((zeroNodes.toList ++ [1]).toByteArray)).isNone do
    throw (IO.userError "trailing-byte control was not rejected")
  IO.println "FRAMING CONTROL refused: trailing byte"
  IO.println "PASS: exact parser + List.zip primitive only; no full Store audit executed"

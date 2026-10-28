/- Explicit source-selected invocation-family edition. Legacy parameter bytes
are retained whole inside a new canonical outer frame, never substring-searched.
Route bindings are source policy bytes, not an invocation-supplied allow list.
This registration is necessary but not sufficient: each nonordinary route still
requires its closed current native admission producer.
-/
module

public import Theory.AssertAxioms
public import Compiler.NativeInvocationStatement
public import Compiler.ContentControlFrame

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

namespace Minidregg.Compiler.NativeInvocationProfile
open Minidregg.Theory.IndexedProgram
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Compiler.NativeInvocationStatement
set_option autoImplicit false

structure Policy where
  legacyParameters : List UInt8
  activityControl : Option ContentControlFrame.Pin
  bindings : List (Route × List UInt8)
  deriving DecidableEq

def stream : StreamCodec Policy :=
  StreamCodec.xmap (StreamCodec.product bytesStream
    (StreamCodec.product (StreamCodec.option ContentControlFrame.pinStream)
      (StreamCodec.list (StreamCodec.product routeStream bytesStream))))
    (fun p => (p.legacyParameters,p.activityControl,p.bindings))
    (fun (b,a,r) => ⟨b,a,r⟩) (by intro p; cases p; rfl)

def frame : List UInt8 := "DREGG/NATIVE/REGISTERED-INVOCATION-PROFILE/v1".toUTF8.toList

def codec : LawfulCodec Policy := (StreamCodec.framed frame stream).toLawful
abbrev encode := codec.encode
abbrev decode := codec.decode

/-- Duplicate route declarations are refused, not resolved by first/last wins.
The whole old manifest remains covered by the new semantics commitment. -/
def select (parameters : List UInt8) : Option Policy := do
  let policy ← decode parameters
  if (policy.bindings.map Prod.fst).Nodup then some policy else none

def binding (parameters : List UInt8) (route : Route) : Option (List UInt8) := do
  let policy ← select parameters
  policy.bindings.lookup route

def registered (parameters : List UInt8) (route : Route) : Bool :=
  (binding parameters route).isSome

/-- Controller derives this pin from its ACTUAL profile receiverParameters.
A call never gets to select the protected coordinate. -/
def activityPin (parameters : List UInt8) : Option ContentControlFrame.Pin := do
  let policy ← select parameters
  let _ ← policy.bindings.lookup .activityDispatch
  policy.activityControl

@[simp] theorem decode_encode (p : Policy) : decode (encode p) = some p := codec.decode_encode p

theorem encode_injective {left right : Policy} (same : encode left = encode right) : left = right := by
  have same := congrArg decode same
  simpa only [decode_encode,Option.some.injEq] using same

theorem select_encoded (p : Policy) (unique : (p.bindings.map Prod.fst).Nodup) :
    select (encode p) = some p := by simp [select,unique]

theorem activityPin_encoded (p : Policy) (unique : (p.bindings.map Prod.fst).Nodup)
    (route : (p.bindings.lookup .activityDispatch).isSome = true) :
    activityPin (encode p) = p.activityControl := by
  cases found : p.bindings.lookup .activityDispatch with
  | none => simp [found] at route
  | some bytes => simp [activityPin, select_encoded p unique, found]

#assert_axioms decode_encode
#assert_axioms encode_injective
#assert_axioms select_encoded
#assert_axioms activityPin_encoded
end Minidregg.Compiler.NativeInvocationProfile

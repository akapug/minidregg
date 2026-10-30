/-
# Kernel.Bounds -- every static limit, in one module (HP-DESIGN §1.6, §6)

One named constant per limit, the relations between them as named theorems, one
check that refuses a value past its limit BY NAME (`Refusal.overBound name value
limit`), and the Rust constants the client reads, emitted from this module
(`native/resource-client/src/bounds.rs`, drift-checked by
`scripts/check-prover-glue.sh`). This module imports nothing, so every decoder,
receiver and the client can read it.

The choke points that refuse by these names:

* `Host.Main.serveSession` / `serveCodec`: a frame past `frameBytesMax` (or, for
  carried exact-call recovery, `lookupFrameBytesMax`) is refused before its payload
  is read, answered `refused over-bound` (`Host.RequestRefusal.answer_overBound`);
* `Kernel.DurableCheckpoint.prepare` (the durable admission every append and every
  replay goes through): an intent past `legsPerTurnMax`, `cellsTouchedMax`,
  `cellBytesMax` or `nullifiersPerTurnMax` is rejected
  `DurableDataIntent.RejectReason.overBound` before the snapshot is consulted
  (`DataIntent.checkBounds`, `prepare_overBound`), answered `refused over-bound`
  (`NativeHost.durableRefusal_overBound`);
* `Kernel.DeployedTurnCompact.decodeEntry` (the follower's log-entry decoder): an
  entry past `turnBytesMax` is refused before a byte of it is decoded, and a turn
  past `legsPerTurnMax`, `nullifiersPerTurnMax` or `cellsTouchedMax` is refused
  whole, never returned in part.

Values (ASSUMED, HP-DESIGN §6, unless a provenance says otherwise) are generous
against the measured journey sizes: the largest durable record over the seven
TURN-LOG j1 journey Stores (2026-10-14, `durable_log.record`) is 128,346 bytes
(send), 54,174 (domain), 33,066 (activity); a record carries every post image in
full, so a compact Turn is no larger. The workload holds 166 cells of ~4 KB.

Owned by later ranges and NOT here yet (each keeps its existing home until the
range that consumes it lands): `batchWaitMs`, `sealMinBytes`, `heldBytesMax`,
`retainedWorldsMax`, `trieDepth` (`deployedIx_length`), `tailBound`
(`Host/ApplicationBirthAuthoringCheck.lean`), the meter lanes (`meterLanes`).
`framesPerRequestMax`, `requestBytesMax`, `batchTurnsMax` and `stateBytesMax` are
named here for the resident loop (HP-3) and the store-full refusal; today one
request is exactly one frame (`one_frame_per_request`).
-/
module

public import Theory.AssertAxioms
meta import Theory.AssertAxioms

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

namespace Minidregg.Kernel.Bounds

set_option autoImplicit false

/-! ## The limits -/

/-- A frame's bytes (operation byte + payload). Provenance: MEASURED requirement,
`Compiler.FnEvidenceCodec.maxHostFrameBytes` (two fn consumer reports + 256 KiB,
`selected_poll_envelope_exact`); the design's ASSUMED 8 MiB is below what the fn
consumer route already carries, so the frame keeps the derived value and
`Host.Main.fnFrame_eq_bound` pins the two equal. -/
def frameBytesMax : Nat := 12102760

/-- A carried exact-call recovery frame (operation 153): the raw call, its length
header and a bounded identity header. Provenance:
`Host.RetainedSegmentInspection.maxLookupFrame` (pinned equal in `Host.Main`). -/
def lookupFrameBytesMax : Nat := 12103788

/-- Frames per request at the resident loop's drain (HP-3). ASSUMED 16. -/
def framesPerRequestMax : Nat := 16

/-- A request's bytes: its frames at the frame bound (DERIVED). -/
def requestBytesMax : Nat := framesPerRequestMax * frameBytesMax

/-- A persisted Turn entry's bytes (compact encoding, `encodeTurnAt`). DERIVED:
the frame bound, so a turn that creates one cell at `cellBytesMax` is persisted
(`cellBytes_le_turnBytes`) and every persisted turn fits in one frame
(`turnBytes_le_frameBytes`). The largest measured record is 128,346 B. -/
def turnBytesMax : Nat := frameBytesMax

/-- Legs per turn. ASSUMED 256 (the workload's whole Store is 166 cells). -/
def legsPerTurnMax : Nat := 256

/-- Cells a turn touches: creates + legs + retires + absence pins (or, on the
record path, written + guarded cells). ASSUMED 512. -/
def cellsTouchedMax : Nat := 512

/-- One cell's canonical post bytes: 8 MiB (ROOT ruling 10-15). The single home of
the per-cell cap: the grain-backed birth's source carrier is held to it
(`Kernel.GrainResourceBirthPolicyController.DecodedIngress.sourceSizeBound`), and a
package is one cell (`packageBytesMax`). Cells measure ~4 KB. -/
def cellBytesMax : Nat := 8388608

/-- Nullifiers per turn. ASSUMED 64. -/
def nullifiersPerTurnMax : Nat := 64

/-- Requests per batch at the resident loop (HP-3). ASSUMED 64. -/
def batchTurnsMax : Nat := 64

/-- A package's bytes: one cell (DERIVED). The fn route keeps its own tighter cap,
`Compiler.FnEvidenceCodec.maxPackageBytes` (1 MiB), within it (`Host.Main.fnPackage_le_bound`). -/
def packageBytesMax : Nat := cellBytesMax

/-- A Store's state bytes this epoch (creates refused past it, HP-3). ASSUMED 64 MiB. -/
def stateBytesMax : Nat := 67108864

/-! ## Names -/

/-- The name a refusal carries. -/
inductive Name where
  | frameBytes
  | lookupFrameBytes
  | framesPerRequest
  | requestBytes
  | turnBytes
  | legsPerTurn
  | cellsTouched
  | cellBytes
  | nullifiersPerTurn
  | batchTurns
  | packageBytes
  | stateBytes
  deriving DecidableEq, Repr, Inhabited

namespace Name

/-- The limit a name stands for. -/
def limit : Name → Nat
  | .frameBytes => frameBytesMax
  | .lookupFrameBytes => lookupFrameBytesMax
  | .framesPerRequest => framesPerRequestMax
  | .requestBytes => requestBytesMax
  | .turnBytes => turnBytesMax
  | .legsPerTurn => legsPerTurnMax
  | .cellsTouched => cellsTouchedMax
  | .cellBytes => cellBytesMax
  | .nullifiersPerTurn => nullifiersPerTurnMax
  | .batchTurns => batchTurnsMax
  | .packageBytes => packageBytesMax
  | .stateBytes => stateBytesMax

/-- The Lean constant's name, which is also the rendered refusal's name. -/
def ident : Name → String
  | .frameBytes => "frameBytesMax"
  | .lookupFrameBytes => "lookupFrameBytesMax"
  | .framesPerRequest => "framesPerRequestMax"
  | .requestBytes => "requestBytesMax"
  | .turnBytes => "turnBytesMax"
  | .legsPerTurn => "legsPerTurnMax"
  | .cellsTouched => "cellsTouchedMax"
  | .cellBytes => "cellBytesMax"
  | .nullifiersPerTurn => "nullifiersPerTurnMax"
  | .batchTurns => "batchTurnsMax"
  | .packageBytes => "packageBytesMax"
  | .stateBytes => "stateBytesMax"

/-- The Rust constant's name. -/
def rustIdent : Name → String
  | .frameBytes => "FRAME_BYTES_MAX"
  | .lookupFrameBytes => "LOOKUP_FRAME_BYTES_MAX"
  | .framesPerRequest => "FRAMES_PER_REQUEST_MAX"
  | .requestBytes => "REQUEST_BYTES_MAX"
  | .turnBytes => "TURN_BYTES_MAX"
  | .legsPerTurn => "LEGS_PER_TURN_MAX"
  | .cellsTouched => "CELLS_TOUCHED_MAX"
  | .cellBytes => "CELL_BYTES_MAX"
  | .nullifiersPerTurn => "NULLIFIERS_PER_TURN_MAX"
  | .batchTurns => "BATCH_TURNS_MAX"
  | .packageBytes => "PACKAGE_BYTES_MAX"
  | .stateBytes => "STATE_BYTES_MAX"

def all : List Name :=
  [.frameBytes, .lookupFrameBytes, .framesPerRequest, .requestBytes, .turnBytes, .legsPerTurn,
    .cellsTouched, .cellBytes, .nullifiersPerTurn, .batchTurns, .packageBytes, .stateBytes]

theorem mem_all (name : Name) : name ∈ all := by
  cases name <;> decide

/-- Rendered names are pairwise distinct, so a refusal's text names one bound. -/
theorem ident_injective : Function.Injective ident := by
  intro left right same
  cases left <;> cases right <;> first | rfl | (simp [ident] at same)

theorem rustIdent_injective : Function.Injective rustIdent := by
  intro left right same
  cases left <;> cases right <;> first | rfl | (simp [rustIdent] at same)

end Name

/-! ## Relations -/

/-- A persisted turn fits in one frame. -/
theorem turnBytes_le_frameBytes : turnBytesMax ≤ frameBytesMax := by decide
/-- A turn carrying one whole cell fits in a persisted turn. -/
theorem cellBytes_le_turnBytes : cellBytesMax ≤ turnBytesMax := by decide
/-- Every leg is a touched cell. -/
theorem legsPerTurn_le_cellsTouched : legsPerTurnMax ≤ cellsTouchedMax := by decide
/-- A carried exact-call recovery frame is the only frame above the frame bound. -/
theorem frameBytes_le_lookupFrameBytes : frameBytesMax ≤ lookupFrameBytesMax := by decide
/-- Today one request is one frame (`Host.Main.serveSession`). -/
theorem one_frame_per_request : 1 ≤ framesPerRequestMax := by decide
theorem frameBytes_le_requestBytes : frameBytesMax ≤ requestBytesMax := by decide
/-- A package fits in one frame. -/
theorem packageBytes_le_frameBytes : packageBytesMax ≤ frameBytesMax := by decide
/-- One cell fits in the state bound. -/
theorem cellBytes_le_stateBytes : cellBytesMax ≤ stateBytesMax := by decide

/-! ## The refusal and the check -/

/-- A value past its limit, by the limit's name. -/
inductive Refusal where
  | overBound (name : Name) (value limit : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- `over-bound NAME VALUE > LIMIT`, the text a refusal detail carries. -/
def Refusal.render : Refusal → String
  | .overBound name value limit => s!"over-bound {name.ident} {value} > {limit}"

instance : ToString Refusal := ⟨Refusal.render⟩

/-- Refuse `value` past `name`'s limit. -/
def check (name : Name) (value : Nat) : Except Refusal Unit :=
  if value ≤ name.limit then .ok () else .error (.overBound name value name.limit)

/-- **No false refusal**: a value within its limit is accepted. -/
theorem check_accepts {name : Name} {value : Nat} (h : value ≤ name.limit) :
    check name value = .ok () := by
  simp [check, h]

/-- A value past its limit is refused by exactly that name, value and limit. -/
theorem check_refuses {name : Name} {value : Nat} (h : name.limit < value) :
    check name value = .error (.overBound name value name.limit) := by
  simp [check, Nat.not_le.mpr h]

theorem check_ok_iff (name : Name) (value : Nat) : check name value = .ok () ↔ value ≤ name.limit := by
  unfold check; split <;> simp_all

/-- Check a list of (name, value) pairs in order; the first value past its limit
is the refusal. -/
def checkAll : List (Name × Nat) → Except Refusal Unit
  | [] => .ok ()
  | (name, value) :: rest => do check name value; checkAll rest

/-- **`withinBounds_accepts`**: values all within their limits are accepted. -/
theorem withinBounds_accepts : ∀ (checks : List (Name × Nat)),
    (∀ p ∈ checks, p.2 ≤ p.1.limit) → checkAll checks = .ok ()
  | [], _ => rfl
  | (name, value) :: rest, h => by
      have head := h (name, value) (by simp)
      have tail := withinBounds_accepts rest fun p hp => h p (by simp [hp])
      simp [checkAll, check_accepts head, tail]
      rfl

/-- An accepted list is within bounds (the check is not vacuous). -/
theorem checkAll_ok : ∀ (checks : List (Name × Nat)),
    checkAll checks = .ok () → ∀ p ∈ checks, p.2 ≤ p.1.limit
  | [], _, _, hp => by simp at hp
  | (name, value) :: rest, h, p, hp => by
      unfold checkAll at h
      cases hc : check name value with
      | error r => simp [hc, bind, Except.bind] at h
      | ok u =>
        simp only [hc, bind, Except.bind] at h
        rcases List.mem_cons.mp hp with rfl | hp
        · exact (check_ok_iff name value).mp (by cases u; exact hc)
        · exact checkAll_ok rest h p hp

/-- A refusal names a checked pair past its limit. -/
theorem checkAll_refuses : ∀ (checks : List (Name × Nat)) (r : Refusal),
    checkAll checks = .error r →
      ∃ p ∈ checks, p.1.limit < p.2 ∧ r = .overBound p.1 p.2 p.1.limit
  | [], r, h => by simp [checkAll] at h
  | (name, value) :: rest, r, h => by
      unfold checkAll at h
      by_cases hv : value ≤ name.limit
      · rw [check_accepts hv] at h
        obtain ⟨p, hp, lt, eq⟩ := checkAll_refuses rest r h
        exact ⟨p, by simp [hp], lt, eq⟩
      · have lt := Nat.lt_of_not_le hv
        rw [check_refuses lt] at h
        simp only [bind, Except.bind, Except.error.injEq] at h
        exact ⟨(name, value), by simp, lt, h.symm⟩

/-! ## The Rust constants (generated) -/

/-- The generated Rust module: one `pub(crate) const` per name. A function, not a
nullary constant, so linking this module costs a Host start nothing. -/
def rustSource (_ : Unit) : String :=
  let header :=
    "// @generated by Kernel/Bounds.lean (`#eval Bounds.emitRust`). Do not edit.\n" ++
    "// The static limits of Mini (HP-DESIGN §6); scripts/check-prover-glue.sh fails\n" ++
    "// when this file differs from what the Lean module emits.\n" ++
    "#![allow(dead_code)]\n\n"
  header ++ String.join (Name.all.map fun name =>
    s!"/// Kernel.Bounds.{name.ident}\npub(crate) const {name.rustIdent}: usize = {name.limit};\n")

/-- Write the generated module at `path` (relative to the working directory). -/
def emitRust (path : System.FilePath) : IO Unit := do
  if let some parent := path.parent then IO.FS.createDirAll parent
  IO.FS.writeFile path (rustSource ())

#assert_axioms Name.mem_all Name.ident_injective Name.rustIdent_injective
#assert_axioms check_accepts check_refuses check_ok_iff
#assert_axioms withinBounds_accepts checkAll_ok checkAll_refuses

#eval emitRust "native/resource-client/src/bounds.rs"

end Minidregg.Kernel.Bounds

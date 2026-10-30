/- HP-6 SIM: the deterministic simulation gate (HP-DESIGN §4, §5.2 HP-6).

One process, two sides.  The **Host** side is today's admission path: the
receiver (`DurableDataIntent.execute` over the Host's `DataSnapshot`), then
`Turn.ofIntent` against the Host's World, then `World.admit`; an admitted intent
persists its `IntentRecord` (`recordFrame` bytes) and its Turn
(`encodeTurnAt`, the TURN-LOG entry).  SWITCH: when HP-3's resident loop lands,
`hostIntent` calls the loop's pure admit instead.  The **follower** side reads
only the Turn entries and folds them (`TurnLog.followFrom`, which IS
`World.fold`).

Asserted, every step (a red names the step and the fact):
* certificate: an intent the receiver accepts and `Turn.ofIntent` derives is
  admitted by `World.admit` (`ofIntent_step`);
* the follower re-admits every admitted entry, to the same Turn bytes, and the
  Host's root (the receiver's cell bytes under the World's head) equals the
  follower's root (`turnLogRoot` of its own World);
* `Represents` on the touched cells: the World's bytes are the receiver's bytes,
  the meter is the receiver's `available`, the step's nullifiers are spent in
  both homes, the height is the record count;
* every refused intent whose turn derives is refused (or admitted) by the
  follower exactly as by the Host's World, and the receiver's reason maps to the
  World's (`receiverAgrees`); the two stale classes the World cannot see are
  counted (`receiver-only`), not asserted;
* every probe (a presented Turn) gets one verdict on both sides;
* every K steps a crash at a seeded point (before or after the atomic install,
  or between steps): the Host reopens from its persisted bytes only (records
  replayed by `Image.restore`, entries folded from genesis) and must equal the
  uninterrupted Host (whole system cell bytes and every cell); the in-flight
  intent is retried and must be admitted (lost) or replayed (kept).

`world-sim SEED STEPS [K] [--plant follower-skips-guard|reopen-drops-last] [--names]` prints one line:
`SIM seed=… PASS …counts…` or `SIM seed=… FAIL step=… <fact>`.
`world-sim seeds FROM COUNT STEPS K` runs a range.
`world-sim corpus STORES.json K` drives each retained Store's own records (with
retries probed every K) through both sides. -/
import Host.ClientConsentCore
import Kernel.TurnGen
import Kernel.WorldSystemCodec

namespace Minidregg.Host.WorldSim

open Minidregg.Theory.Store
open Minidregg.Theory.TypedAuthorization (Digest)
open Minidregg.Theory.ResourceCost (Lane Charge)
open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel
open Minidregg.Kernel.World
open Minidregg.Kernel.TurnLog
open Minidregg.Kernel.TurnGen
open Minidregg.Kernel.DeployedBridge
open Minidregg.Kernel.DeployedHistory
open Minidregg.Kernel.DeployedTurnCompact
open Minidregg.Kernel.TurnOfIntent
open Minidregg.Kernel.DurableReceiver (IntentRecord Seed Image)
open Minidregg.Kernel.DurableDataIntent
  (DataIntent DataWrite ReadGuard StableNullifier StableEvent DataSnapshot RejectReason execute)
open Minidregg.Kernel.DurableCommitProtocol (Schedule CrashPoint)

set_option autoImplicit false

/-! ## The two sides -/

/-- The Host: the receiver's snapshot and the World, and what it persisted. -/
structure Host where
  seed : Seed
  snap : DataSnapshot RB
  world : DWorld
  /-- Persisted `IntentRecord`s, as `recordFrame` bytes. -/
  records : Array (List UInt8)
  /-- Persisted Turn entries (`encodeTurnAt`). -/
  log : Array (List UInt8)
  /-- Seed ids, then each create's (`idsOf`). -/
  ids : List CellId

/-- The follower: a World it folded from genesis and the ids its turns created. -/
structure Follower where
  world : DWorld
  height : Nat
  ids : List CellId

/-- A planted divergence. -/
inductive Plant
  | none
  /-- The follower skips the guard that failed: the pins on the failing cell
  and the leading reads of that cell's leg. -/
  | followerSkipsGuard
  /-- The Host's reopen loses the last persisted Turn entry (a torn append). -/
  | reopenDropsLast
  deriving DecidableEq

def headOf (w : DWorld) : Nat × Digest := w.head.getD (0, history.logRoot0)

/-- The Host's root: the World's head over the RECEIVER's cell bytes. -/
def hostRoot (h : Host) : Digest :=
  let (height, logRoot) := headOf h.world
  WorldRoot.deployedRoot
    ((WorldRoot.Key.system, DurableCheckpointCodec.systemLeaf height logRoot) ::
      h.ids.map fun c => (WorldRoot.Key.cell c, ResourceBirthCodec.rootBytes (h.snap.canonicalBytes ⟨c⟩)))

def Follower.root (f : Follower) : Digest := turnLogRoot f.world f.ids

def addIds (ids : List CellId) (t : DTurn deployedR Digest) : List CellId :=
  (ids ++ t.creates.map Prod.fst).eraseDups

/-- The follower's admission (planted or not). -/
def followerAdmit (plant : Plant) (w : DWorld) (t : DTurn deployedR Digest) :
    Except Reject DWorld :=
  match plant, World.admit history w t with
  | .followerSkipsGuard, .error (.guardFailed c _) =>
      World.admit history w { t with
        pins := t.pins.filter fun p => p.1 != c
        legs := t.legs.map fun leg =>
          if leg.cell = c then { leg with patch := leg.patch.filter fun op => !World.Op.isRead op }
          else leg }
  | _, r => r

/-- Follow one entry: `followFrom` on it, or the planted follower. -/
def followOne (plant : Plant) (f : Follower) (entry : List UInt8) :
    Except FollowStop (Follower × DTurn deployedR Digest) :=
  let done := fun (w : DWorld) (t : DTurn deployedR Digest) =>
    ({ world := w, height := f.height + 1, ids := addIds f.ids t } : Follower)
  match plant with
  | .none =>
      match followFrom f.world f.height [entry] with
      | .ok (w, [t]) => .ok (done w t, t)
      | .ok _ => .error (.undecodable f.height)
      | .error e => .error e
  | p =>
      match decodeTurnAt f.world entry with
      | none => .error (.undecodable f.height)
      | some t =>
          match followerAdmit p f.world t with
          | .ok w => .ok (done w t, t)
          | .error r => .error (.refused f.height r)

/-! ## Facts -/

/-- The World and the receiver agree on the listed cells, the meter, the height. -/
def represents (h : Host) (cells : List CellId) (nulls : List StableNullifier) (lanes : List Lane) :
    Option String :=
  match cells.find? fun c => bytesOf h.world c != h.snap.canonicalBytes ⟨c⟩ with
  | some c => some s!"represents: cell {c} World bytes != receiver bytes"
  | none =>
  match lanes.find? fun l => h.world.meter l != h.snap.model.available l with
  | some l => some s!"represents: meter {reprStr l} World {h.world.meter l} receiver {h.snap.model.available l}"
  | none =>
  match nulls.find? fun n => (h.world.spent (digestKey n)).isNone || !h.snap.model.consumed n with
  | some _ => some "represents: a nullifier is not spent in both homes"
  | none =>
  if (headOf h.world).1 != h.records.size then
    some s!"represents: height {(headOf h.world).1} records {h.records.size}"
  else none

/-- Two Worlds are the same: the whole system cell's bytes, every listed cell. -/
def sameWorld (a b : DWorld) (ids : List CellId) : Option String :=
  if WorldSystemCodec.systemStream.encode a.system != WorldSystemCodec.systemStream.encode b.system then
    some "system cell bytes differ"
  else match ids.find? fun c => bytesOf a c != bytesOf b c with
    | some c => some s!"cell {c} differs"
    | none => none

/-- Two Hosts are the same: their Worlds, their receivers' bytes, meters, journals. -/
def sameHost (a b : Host) : Option String :=
  if a.ids != b.ids then some "ids differ" else
  match sameWorld a.world b.world a.ids with
  | some e => some s!"world: {e}"
  | none =>
  match a.ids.find? fun c => a.snap.canonicalBytes ⟨c⟩ != b.snap.canonicalBytes ⟨c⟩ with
  | some c => some s!"receiver cell {c} differs"
  | none =>
  if meterLanes.any fun l => a.snap.model.available l != b.snap.model.available l then
    some "receiver meter differs"
  else if a.snap.model.journal.length != b.snap.model.journal.length then some "receiver journal differs"
  else none

/-- The receiver's reason, against the World's verdict on the same derived turn. -/
inductive Agreement
  | agrees
  /-- A staleness the derived turn erases (it is re-derived from the held cells). -/
  | receiverOnly
  | disagrees

def receiverAgrees : RejectReason → Except Reject DWorld → Agreement
  | .durable .transactionConflict, .error .replayedTransaction => .agrees
  | .durable .alreadyConsumed, .error .nullifierSpent => .agrees
  | .durable .duplicateNullifier, .error .duplicateNullifier => .agrees
  | .durable .insufficientBudget, .error .overAllowance => .agrees
  | .durable .stalePreRoot, .ok _ => .receiverOnly
  | .staleReadGuard, .ok _ => .receiverOnly
  | .durable .stalePreRoot, .error _ => .agrees
  | .staleReadGuard, .error _ => .agrees
  | _, _ => .disagrees

def verdictName : Except Reject DWorld → String
  | .ok _ => "admit"
  | .error r => (reprStr r).replace "\n" " " |>.replace "Minidregg.Kernel.World.Reject." ""

/-! ## The simulation -/

structure Counts where
  steps : Nat := 0
  admitted : Nat := 0
  replayed : Nat := 0
  refusedReceiver : Nat := 0
  refusedDerive : Nat := 0
  receiverOnly : Nat := 0
  probes : Nat := 0
  probeAdmits : Nat := 0
  crashes : Nat := 0
  /-- Commits after which the receiver's storage lane and the World's differ
  (corpus only: the deployed receivers' own storage terms, G-CHARGE). -/
  storageDrift : Nat := 0
  /-- Refusal names seen, with counts. -/
  names : List (String × Nat) := []

def Counts.see (c : Counts) (n : String) : Counts :=
  { c with names := match c.names.lookup n with
    | some k => (n, k + 1) :: c.names.filter (·.1 != n)
    | none => (n, 1) :: c.names }

structure Sim where
  host : Host
  follower : Follower
  gen : GenState
  plant : Plant
  /-- Whether the meter check covers the storage lane (the generator charges
  exactly `storageOf`; the corpus's receivers do not yet, G-CHARGE). -/
  meterStorage : Bool := true
  counts : Counts := {}
  step : Nat := 0

abbrev SimM := StateT Sim (ExceptT String IO)

def fail {α : Type} (msg : String) : SimM α := do
  throw s!"step={(← get).step} {msg}"

def count (f : Counts → Counts) : SimM Unit := modify fun s => { s with counts := f s.counts }

def genHere {α : Type} (m : GenM α) : SimM α := do
  let s ← get
  let (a, g) := m.run s.gen
  set { s with gen := g }
  return a

/-- Reopen a Host from its persisted bytes only. -/
def reopen (plant : Plant) (h : Host) : Except String Host := do
  let records ← h.records.toList.mapM fun b =>
    (DurableCheckpointCodec.recordFrame.decode b).elim (.error "a persisted record does not decode") .ok
  let snap ← (Image.restore RB (Image.ofAccepted h.seed records)).elim (.error "Image.restore refused the records") .ok
  let g ← (genesisOfSeed h.seed).mapError fun e => s!"genesis {reprStr e}"
  let log := if plant = .reopenDropsLast then h.log.pop else h.log
  let (w, turns) ← (followFrom g 0 log.toList).mapError fun e => s!"reopen fold {reprStr e}"
  return { h with snap, world := w, ids := idsOf h.seed turns }

/-- Crash and reopen; the reopened Host must equal `expect`. -/
def crashRestart (expect : Host) : SimM Unit := do
  count fun c => { c with crashes := c.crashes + 1 }
  match reopen (← get).plant expect with
  | .error e => fail s!"crash-restart: {e}"
  | .ok h' =>
    if let some e := sameHost h' expect then fail s!"crash-restart: resumed != uninterrupted: {e}"
    modify fun s => { s with host := h' }

/-- Commit an admitted intent on the Host, follow it, assert. -/
def commit (i : DataIntent RB) (t : DTurn deployedR Digest) (next : DataSnapshot RB)
    (w' : DWorld) : SimM Unit := do
  let s ← get
  let h := s.host
  let entry := encodeTurnAt h.world t
  let h' : Host :=
    { h with
      snap := next
      world := w'
      records := h.records.push (DurableCheckpointCodec.recordFrame.encode (IntentRecord.ofIntent i))
      log := h.log.push entry
      ids := addIds h.ids t }
  match followOne s.plant s.follower entry with
  | .error e => fail s!"follower refused an admitted entry: {reprStr e}"
  | .ok (f', t') =>
    if encodeTurn t' != encodeTurn t then fail "follower decoded a different turn"
    if hostRoot h' != f'.root then fail s!"root: Host {(hostRoot h').value} follower {f'.root.value}"
    let touched := (t.creates.map Prod.fst ++ t.legs.map Leg.cell ++ t.retires).eraseDups
    let lanes := if s.meterStorage then meterLanes else meterLanes.filter (· != .storageBytes)
    if let some e := represents h' touched i.nullifiers lanes then fail e
    if !s.meterStorage && h'.world.meter .storageBytes != h'.snap.model.available .storageBytes then
      count fun c => { c with storageDrift := c.storageDrift + 1 }
    genHere (note i h.world)
    modify fun s => { s with host := h', follower := f' }
    count fun c => { c with admitted := c.admitted + 1 }

/-- The follower's verdict on a Host-refused turn, persisted as the Host would
persist it: the same refusal, by name. -/
def refusedProbe (t : DTurn deployedR Digest) (hv : Except Reject DWorld) : SimM Unit := do
  let s ← get
  let fv := followOne s.plant s.follower (encodeTurnAt s.host.world t)
  match hv, fv with
  | .error r, .error (.refused _ r') =>
      if r != r' then fail s!"refusal: Host {reprStr r} follower {reprStr r'}"
  | .ok _, .ok _ => pure ()
  | _, .error e => fail s!"verdict: Host {verdictName hv} follower {reprStr e}"
  | _, .ok _ => fail s!"verdict: Host {verdictName hv} follower admitted"

/-- An intent the receiver accepted: derive, admit, commit; then the crash. -/
def accepted (i : DataIntent RB) (derived : Except TurnOfIntent.Refusal (DTurn deployedR Digest))
    (next : DataSnapshot RB) (thenCrash : Bool) : SimM Unit := do
  let h := (← get).host
  match derived with
  | .error r =>
      count fun c => ({ c with refusedDerive := c.refusedDerive + 1 }.see s!"derive:{reprStr r}")
  | .ok t =>
    match World.admit history h.world t with
    | .error r => fail s!"certificate: receiver accepted, Turn.ofIntent derived, World.admit refused {reprStr r}"
    | .ok w' =>
      commit i t next w'
      if thenCrash then
        crashRestart (← get).host
        match execute .complete (← get).host.snap i with
        | .replayed _ => count fun c => { c with replayed := c.replayed + 1 }
        | _ => fail "retry after a kept commit was not a replay"

/-- One intent through the Host path, no crash. -/
def hostIntentAt (i : DataIntent RB) (schedule : Schedule) : SimM Bool := do
  let h := (← get).host
  let derived := Turn.ofIntent bridge history h.world i
  match execute schedule h.snap i with
  | .accepted next => accepted i derived next false; return true
  | .crashed .afterAtomicInstall next => accepted i derived next true; return true
  | .crashed .beforeAtomicInstall _ => crashRestart h; return false
  | .replayed _ =>
      count fun c => { c with replayed := c.replayed + 1 }
      if let .ok t := derived then
        match World.admit history h.world t with
        | .error .replayedTransaction => pure ()
        | v => fail s!"receiver replayed, World said {verdictName v}"
      return true
  | .rejected ρ =>
      count fun c => ({ c with refusedReceiver := c.refusedReceiver + 1 }.see s!"receiver:{reprStr ρ}")
      if let .ok t := derived then
        let hv := World.admit history h.world t
        refusedProbe t hv
        match receiverAgrees ρ hv with
        | .agrees => pure ()
        | .receiverOnly => count fun c => { c with receiverOnly := c.receiverOnly + 1 }
        | .disagrees => fail s!"receiver refused {reprStr ρ}, World said {verdictName hv}"
      return true

/-- One intent through the Host path, with an optional crash point; a crash
before the install loses the intent, and the client retries it. -/
def hostIntent (i : DataIntent RB) (crash : Option CrashPoint) : SimM Unit := do
  let schedule := match crash with
    | some p => Schedule.crash p
    | none => .complete
  unless ← hostIntentAt i schedule do
    let _ ← hostIntentAt i .complete

/-- A presented turn, decided on both sides, never committed. -/
def probe (cls : String) (t : DTurn deployedR Digest) : SimM Unit := do
  let s ← get
  let hv := World.admit history s.host.world t
  count fun c => ({ c with probes := c.probes + 1 }.see s!"probe:{cls}:{verdictName hv}")
  match hv, followOne s.plant s.follower (encodeTurnAt s.host.world t) with
  | .error r, .error (.refused _ r') =>
      if r != r' then fail s!"probe {cls}: Host {reprStr r} follower {reprStr r'}"
  | .ok w, .ok (f', t') =>
      count fun c => { c with probeAdmits := c.probeAdmits + 1 }
      if encodeTurn t' != encodeTurn t then fail s!"probe {cls}: follower decoded a different turn"
      let ids := addIds s.host.ids t
      if turnLogRoot w ids != turnLogRoot f'.world ids then fail s!"probe {cls}: roots differ"
  | .error r, .ok _ => fail s!"probe {cls}: Host {reprStr r}, follower admitted"
  | .ok _, .error e => fail s!"probe {cls}: Host admitted, follower {reprStr e}"
  | .error r, .error e => fail s!"probe {cls}: Host {reprStr r}, follower {reprStr e}"

/-- Start a simulation from a seed. -/
def start (seed : Seed) (gen : GenState) (plant : Plant) : Except String Sim := do
  let g ← (genesisOfSeed seed).mapError fun e => s!"genesis {reprStr e}"
  let snap := seed.snapshot RB
  let ids := seed.cells.map fun c => c.1.value
  return { host := { seed, snap, world := g, records := #[], log := #[], ids }
           follower := { world := g, height := 0, ids }, gen, plant }

/-- The crash point of step `n` (every `k` steps; seeded). -/
def crashAt (k n : Nat) : SimM (Option (Option CrashPoint)) := do
  if k = 0 ∨ n % k ≠ k - 1 then return none
  match ← genHere (below 3) with
  | 0 => return some (some .beforeAtomicInstall)
  | 1 => return some (some .afterAtomicInstall)
  | _ => return some none

/-- One generated step. -/
def simStep (sz : Sizes) (k : Nat) : SimM Unit := do
  let s ← get
  let n := s.step
  let v : View := { world := s.host.world, snap := s.host.snap, height := (headOf s.host.world).1 }
  let st ← genHere (TurnGen.next sz v)
  let crash ← crashAt k n
  match st with
  | .intent _ i =>
      hostIntent i (crash.bind id)
      if crash == some none then crashRestart (← get).host
  | .probe cls t =>
      probe cls t
      if crash.isSome then crashRestart (← get).host
  modify fun s => { s with step := s.step + 1, counts := { s.counts with steps := s.counts.steps + 1 } }

/-- The end: a fresh follower over the whole log reaches the Host's World. -/
def finish : SimM Unit := do
  let s ← get
  match genesisOfSeed s.host.seed with
  | .error _ => fail "end: genesis"
  | .ok g =>
    match followFrom g 0 s.host.log.toList with
    | .error e => fail s!"end: whole-log follower stopped {reprStr e}"
    | .ok (w, turns) =>
      let f : Follower := { world := w, height := turns.length, ids := idsOf s.host.seed turns }
      if f.root != hostRoot s.host then fail "end: whole-log root != Host root"
      if let some e := sameWorld w s.host.world s.host.ids then fail s!"end: whole-log World: {e}"
      if let some e := sameWorld s.follower.world s.host.world s.host.ids then
        fail s!"end: incremental follower World: {e}"

def short (d : Digest) : String := String.ofList ((toString d.value).toList.take 12)

def summary (c : Counts) : String :=
  s!"steps={c.steps} admitted={c.admitted} replayed={c.replayed} refused-receiver={c.refusedReceiver} refused-derive={c.refusedDerive} receiver-only={c.receiverOnly} probes={c.probes} probe-admits={c.probeAdmits} crashes={c.crashes} storage-drift={c.storageDrift} names={c.names.length}"

/-- Run one seed; one verdict line. -/
def runSeed (seed steps k : Nat) (plant : Plant) (names : Bool := false) (sz : Sizes := .small) :
    IO Bool := do
  match start (genesisSeed sz) (GenState.init seed) plant with
  | .error e => IO.println s!"SIM seed={seed} FAIL start {e}"; return false
  | .ok sim =>
    let run : SimM Unit := do
      for _ in [0:steps] do simStep sz k
      finish
    match ← (run.run sim).run with
    | .error e => IO.println s!"SIM seed={seed} FAIL {e}"; return false
    | .ok ((), s) =>
      IO.println s!"SIM seed={seed} PASS {summary s.counts} root={short (hostRoot s.host)}"
      if names then
        for (n, c) in s.counts.names.reverse do IO.println s!"  NAME {n} {c}"
      return true

/-! ## The corpus: a retained Store's own records -/

def runStore (row config : String) (k : Nat) : IO Bool := do
  let settings ← Minidregg.Host.ClientConsentCore.loadSettings config
  let loaded ← IO.ofExcept (← DurableReceiverIO.load settings.config.transport RB)
  let seed := loaded.image.seed
  match start seed (GenState.init 0) .none with
  | .error e => IO.println s!"CORPUS {row} FAIL start {e}"; return false
  | .ok sim0 =>
    let sim := { sim0 with meterStorage := false }
    let records := loaded.image.accepted
    let run : SimM Unit := do
      for r in records do
        let some i := r.bind? RB | fail "a record does not bind"
        let n := (← get).step
        let crash ← crashAt k n
        hostIntent i (crash.bind id)
        if crash == some none then crashRestart (← get).host
        -- every k steps a retry of an earlier accepted record must replay
        if k ≠ 0 ∧ n % k = k / 2 then
          if let some old ← genHere (pick (← get).gen.accepted) then hostIntent old none
        modify fun s => { s with step := s.step + 1, counts := { s.counts with steps := s.counts.steps + 1 } }
      finish
      let s ← get
      if s.counts.admitted != records.length then
        fail s!"admitted {s.counts.admitted} of {records.length} records"
      if let some c := s.host.ids.find? fun c => s.host.snap.canonicalBytes ⟨c⟩ != loaded.snapshot.canonicalBytes ⟨c⟩ then
        fail s!"cell {c}: the sim's receiver != the Store's"
    match ← (run.run sim).run with
    | .error e => IO.println s!"CORPUS {row} FAIL {e}"; return false
    | .ok ((), s) =>
      IO.println s!"CORPUS {row} PASS {summary s.counts} root={short (hostRoot s.host)}"
      return true

def runCorpus (stores : String) (k : Nat) : IO UInt32 := do
  let json ← IO.ofExcept (Lean.Json.parse (← IO.FS.readFile stores))
  let rows ← IO.ofExcept (json.getArr?)
  let mut bad := 0
  for row in rows do
    let name ← IO.ofExcept (row.getObjValAs? String "row")
    let config ← IO.ofExcept (row.getObjValAs? String "config")
    unless ← runStore name config k do bad := bad + 1
  IO.println s!"CORPUS-TOTAL stores {rows.size} fail {bad}"
  return if bad = 0 then (0 : UInt32) else 1

end Minidregg.Host.WorldSim

open Minidregg.Host.WorldSim in
def main (arguments : List String) : IO UInt32 := do
  let plantOf (rest : List String) : Plant :=
    if rest.contains "--plant" ∧ rest.contains "follower-skips-guard" then .followerSkipsGuard
    else if rest.contains "--plant" ∧ rest.contains "reopen-drops-last" then .reopenDropsLast
    else .none
  try
    match arguments with
    | ["seeds", a, n, steps, k] =>
      let (some a, some n, some steps, some k) := (a.toNat?, n.toNat?, steps.toNat?, k.toNat?)
        | IO.eprintln "world-sim: numbers"; return 2
      let mut bad := 0
      for s in [a:a + n] do
        unless ← runSeed s steps k .none do bad := bad + 1
      IO.println s!"SIM-TOTAL seeds {n} steps {steps} crash-every {k} fail {bad}"
      return if bad = 0 then (0 : UInt32) else 1
    | ["corpus", stores, k] =>
      let some k := k.toNat? | IO.eprintln "world-sim: K"; return 2
      runCorpus stores k
    | seed :: steps :: rest =>
      let (some seed, some steps) := (seed.toNat?, steps.toNat?) | IO.eprintln "world-sim: numbers"; return 2
      let k := (rest.head?.bind String.toNat?).getD 50
      return if ← runSeed seed steps k (plantOf rest) (rest.contains "--names") then 0 else 1
    | _ =>
      IO.eprintln "usage: world-sim SEED STEPS [K] [--plant follower-skips-guard|reopen-drops-last] [--names] | seeds FROM COUNT STEPS K | corpus STORES.json K"
      return 2
  catch e =>
    IO.eprintln s!"world-sim: {e}"
    return 1

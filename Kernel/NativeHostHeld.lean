/-
# Kernel.NativeHostHeld — the package replays a resident Host process holds

A frame load replays its pinned package's front end (`ObjectiveActivity.replayPackage`: parse,
lower, accept, compare with the stored core; and each called method's lowering). All of that is
a function of the pin's stored pair and two policy numbers, so a process that decides many turns
holds it: `ObjectiveActivity.LoadMemo`, a map from pin to a lazy replay whose only constructor
computes it. Each package cell is looked at once per process; its replay runs at the first load
that forces it, and every later load in this process reuses it. Holding changes no decision
(`ObjectiveActivity.LoadMemo.replay_eq`): a pin whose cell holds other bytes than the held ones
is not answered from the memo but replayed.
-/
module

public import Kernel.NativeHost
public import Std.Data.HashSet

@[expose] public section

namespace Minidregg.Kernel.NativeHostHeld

open Minidregg.Kernel.NativeHost (Config Opened)
open Minidregg.Compiler

set_option autoImplicit false

/-- What this process holds: the memo, the deployment domain it was gathered under, and the
cells already looked at for a package. -/
structure Held where
  memo : ObjectiveActivity.LoadMemo := {}
  domain : Nat := 0
  seen : Std.HashSet Nat := {}

instance : Inhabited Held := ⟨{}⟩

/-- The most pins one process holds; past it, a new package is replayed per load as before. -/
def capacity : Nat := 512

initialize heldRef : IO.Ref Held ← IO.mkRef {}

/-- **The memo for a decision on `opened`**: every package cell of the image this process has
not looked at yet is held under its pin, for the deployment policy's byte cap and checker fuel.
Nothing is replayed here; a held replay runs when a load first forces it. -/
def heldFor (config : Config) (opened : Opened config) : IO ObjectiveActivity.LoadMemo := do
  -- measurement control only (MINIDREGG_HOST_HELD=0: every load replays, as before the memo)
  if (← IO.getEnv "MINIDREGG_HOST_HELD") == some "0" then return {}
  match ObjectiveKernelConfig.configOf config.deployment config.profile
      (NativeHost.activityAmbient config opened {}) with
  | .error _ => return {}
  | .ok kernel =>
    let prior ← heldRef.get
    let domain := config.deployment.domain.value
    let prior := if prior.domain = domain then prior else { domain }
    let snapshot := opened.durable.snapshot
    let mut memo := prior.memo
    let mut seen := prior.seen
    for cell in opened.durable.cellIds do
      unless seen.contains cell.value do
        seen := seen.insert cell.value
        if memo.held.size < capacity then
          if let some body := ObjectiveActivity.bodyOf .package (snapshot.canonicalBytes cell) then
            if let some stored := ObjectiveActivity.decodeStored body then
              if let some artifact := ObjectiveBendSourceArtifact.decode stored.artifact then
                let pin := ObjectiveBendSourceArtifact.identity artifact
                unless memo.holds kernel.maxArtifactBytes kernel.typeFuel stored pin do
                  memo := memo.hold kernel.maxArtifactBytes kernel.typeFuel stored pin
    heldRef.set { memo, domain, seen }
    return memo

end Minidregg.Kernel.NativeHostHeld

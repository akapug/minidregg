/- Focused settings regression for a full-peer consent executable.
No Store, signing key, admission, or external process is used here. -/
import Host.ClientConsentCore

open Lean Minidregg.Host.ClientConsentCore
namespace Minidregg.Host.ClientConsentSettingsScenario

private def base : Settings := {
  domain := 8501, federation := 9, factoryId := 10, resourceBookId := 11
  authorityCellId := 12, issuer := 5, ownerBudget := 100000, lifetime := 10000
  tariffBase := 3, tariffPerBirth := 2, tariffPerGrant := 1
  tariffPerInitialPayloadByte := 1, collector := 99, asset := 0
  genesisHeight := 10, expectedSeed := 0
  storageBinary := "/private/store-helper", storageRoot := "/private/store"
  signatureBinary := "/private/signature-verifier"
  checkpointKey := some "/private/checkpoint-key"
  grainBirthTariff := some ⟨2, 1⟩
  lifecycleManagement := some ⟨8, 8008⟩ }

private def targets : List Json := [Json.mkObj [
  ("legacy", Json.mkObj [
    ("ticketResource", toJson (29520 : Nat)),
    ("packageManifest", toJson (9102 : Nat)),
    ("snapshotManifest", toJson (9103 : Nat)),
    ("sessionObserve", toJson (20241 : Nat)),
    ("manifestObserve", toJson (20279 : Nat)),
    ("enrollmentObserve", toJson (20243 : Nat)),
    ("parentTask", toJson (27920 : Nat)),
    ("parentCapability", toJson (20201 : Nat)),
    ("parentObserve", toJson (20201 : Nat)),
    ("purseTask", toJson (27940 : Nat)),
    ("purseCapability", toJson (20221 : Nat)),
    ("purseObserve", toJson (20221 : Nat)),
    ("payerSubject", toJson (20012 : Nat)),
    ("reserveAmount", toJson (1 : Int)),
    ("maximumCharge", toJson (1 : Int))]),
  ("grantResource", toJson (29530 : Nat)),
  ("grantObserveCapability", toJson (20283 : Nat))]]

private def setField (json : Json) (name : String) (value : Json) : Json :=
  match json with
  | .obj fields => Json.mkObj <| (name, value) :: fields.foldl (init := [])
      (fun rest key old => if key == name then rest else (key, old) :: rest)
  | other => other

private def configured : Settings := { base with agentLifetimeDispatchTargets := some targets }
private def withoutMetadata : Json := match toJson base with
  | .obj fields => Json.mkObj <| fields.foldl (init := [])
      (fun rest key value => if key == "agentLifetimeDispatchTargets" then rest else (key, value) :: rest)
  | other => other

-- The failing real-world configuration shape now parses and retains the table.
#guard ((parseSettings (toJson configured)).toOption.bind
  Settings.agentLifetimeDispatchTargets) == some targets
#guard (parseSettings (toJson base)).toOption.isSome
#guard ((parseSettings (toJson base)).toOption.bind Settings.agentLifetimeDispatchTargets).isNone
#guard (parseSettings withoutMetadata).toOption.isSome
#guard ((parseSettings withoutMetadata).toOption.bind Settings.agentLifetimeDispatchTargets).isNone
#guard (parseSettings (setField (toJson base) "futureUnsupportedLaw" (toJson (1 : Nat)))).toOption.isNone
#guard (parseSettings (setField (toJson base) "futureUnsupportedLaw" Json.null)).toOption.isSome
#guard (parseSettings (setField (toJson base) "agentLifetimeDispatchTargets" (toJson true))).toOption.isNone
#guard (parseSettings (setField (toJson base) "agentLifetimeDispatchTargets" (toJson ([] : List Json)))).toOption.isNone
#guard (parseSettings (setField (toJson base) "agentLifetimeDispatchTargets" (toJson [Json.null]))).toOption.isNone
#guard (parseSettings (setField (toJson base) "agentLifetimeDispatchTargets" (toJson (List.replicate 9 targets.head!)))).toOption.isNone

-- The proof covers every retained metadata value, not just this fixture.
example : configured.config = base.config :=
  Settings.config_lifetimeDispatchTargets base (some targets)
example : configured.providerRoutes = base.providerRoutes :=
  Settings.providerRoutes_lifetimeDispatchTargets base (some targets)

-- Parsing still honors fields that do change the verified deployment law.
#guard ((parseSettings (setField (toJson configured) "tariffBase" (toJson (17 : Nat)))).toOption.map
  fun settings => settings.config.tariff.base) == some 17
#guard ((parseSettings (toJson configured)).toOption.map
  fun settings => settings.config.storage.key) == some "/private/checkpoint-key"

-- Exercise the actual startup loader, including its unchanged semantic
-- checks, and verify that it never projects or rewrites the settings file.
#eval IO.FS.withTempDir fun directory => do
  let path := directory / "consent-settings.json"
  let bytes := (toJson configured).pretty.toUTF8
  IO.FS.writeBinFile path bytes
  let loaded ← loadSettings path
  unless loaded.agentLifetimeDispatchTargets == some targets do
    throw (IO.userError "startup lost authoring metadata")
  unless (← IO.FS.readBinFile path) == bytes do
    throw (IO.userError "startup rewrote the original settings")
  IO.FS.writeFile path (setField (toJson configured) "futureUnsupportedLaw" (toJson true)).pretty
  let refused ← try
      discard <| loadSettings path
      pure false
    catch _ => pure true
  unless refused do throw (IO.userError "startup accepted an unsupported non-null field")

end Minidregg.Host.ClientConsentSettingsScenario

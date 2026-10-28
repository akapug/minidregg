/-
Source-owned application and session birth authoring against one verified native
image. The JSON parser supplies typed identities and funding; the loaded image
supplies current height, authority epochs and the platform record (creation tariff,
grain-birth tariff, grant window). A genesis description is checked against the pinned
seed but never used as today's authority state or prices.
-/
import Host.Json
import Kernel.NativeHost

namespace Minidregg.Host.ApplicationCurrentBirthAuthoring

open Minidregg.Compiler
open Minidregg.Compiler.NativeHostCodec
open Minidregg.Compiler.NativeObservationCodec
open Minidregg.Theory
open Minidregg.Theory.CellRegistry
open Minidregg.Kernel

set_option autoImplicit false

private def checkSource (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (context : Json.ApplicationBirthContext) : Except String Unit := do
  unless context.profile.template == config.profile.template &&
      context.source.deployment == config.deployment &&
      context.source.federation == config.federation &&
      context.source.tariff == config.tariff &&
      context.source.genesisHeight == config.genesisHeight do
    throw "application birth source differs from the pinned runtime"
  let built ← (NativeHostGenesis.build config.profile context.source).mapError
    (fun reason => s!"application birth genesis refused: {repr reason}")
  unless NativeHost.seedIdentity built.seed == config.expectedSeed do
    throw "application birth genesis differs from the pinned seed"
  unless context.height == NativeHost.logicalHeight config opened.durable do
    throw "application birth height is stale"

/-- The platform record the loaded image holds: the birth's creation tariff, grain-birth
tariff and grant window are its (the receiver prices from the same record and refuses any
other, `platformStale`). -/
private def platformRecord (config : NativeHost.Config) (opened : NativeHost.Opened config) :
    Except String PlatformCellLayout.Platform :=
  match PlatformCellDomain.recordOn config.deployment opened.durable.snapshot with
  | some record => pure record
  | none => throw "application birth: platform cell unavailable"

private def checkCompositeTariff (record : PlatformCellLayout.Platform)
    (selected : Option NativeHost.GrainBirthTariffPin) : Except String Unit := do
  unless selected == record.grainBirth do
    throw "application grain birth tariff differs from the platform record"

private def appDraft (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (path : String) (source : Lean.Json)
    (tariff : Option NativeHost.GrainBirthTariffPin) : Except String Draft := do
  let record ← platformRecord config opened
  checkCompositeTariff record tariff
  let (context, specJson) ← Json.applicationBirthContext path "application" source tariff
    (some (NativeHost.logicalHeight config opened.durable)) (some config)
  checkSource config opened context
  let spec ← Json.applicationSpec (path ++ ".application") specJson
  let ready ← ApplicationGrainBirth.prepare spec
  let descriptor := ready.descriptorCurrent config.profile context.source record
    opened.authority.snapshot.authState context.height context.creator context.nonce
    context.feePayer context.funding
  pure (.birth ((ResourceBirthCodec.descriptorCodec CanonicalCellRegistry.registry).encode
    descriptor) context.sourceCapabilities)

private def sessionDraft (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (path : String) (source : Lean.Json)
    (tariff : Option NativeHost.GrainBirthTariffPin) : Except String Draft := do
  let record ← platformRecord config opened
  checkCompositeTariff record tariff
  let (context, specJson) ← Json.applicationBirthContext path "session" source tariff
    (some (NativeHost.logicalHeight config opened.durable)) (some config)
  checkSource config opened context
  let spec ← Json.applicationSessionSpec (path ++ ".session") specJson
  let ready ← ApplicationGrainSessionBirth.prepare spec
  let descriptor := ready.descriptorCurrent config.profile context.source record
    opened.authority.snapshot.authState context.height context.creator context.nonce
    context.feePayer context.funding
  pure (.birth ((ResourceBirthCodec.descriptorCodec CanonicalCellRegistry.registry).encode
    descriptor) context.sourceCapabilities)

/-- A current app birth remains the same metered tool/parent composite as the
existing pure author, with its grant epochs rederived from `opened`. -/
def applicationIntentLoaded (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (json : Lean.Json) : Except String (List UInt8) := do
  let intent ← Json.grainBirthIntentFrom "$" "applicationGrainBirth"
    "applicationBirth" json (appDraft config opened)
  pure <| intentCodec.encode intent

def sessionIntentLoaded (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (json : Lean.Json) : Except String (List UInt8) := do
  let intent ← Json.grainBirthIntentFrom "$" "applicationSessionGrainBirth"
    "applicationSessionBirth" json (sessionDraft config opened)
  pure <| intentCodec.encode intent

end Minidregg.Host.ApplicationCurrentBirthAuthoring

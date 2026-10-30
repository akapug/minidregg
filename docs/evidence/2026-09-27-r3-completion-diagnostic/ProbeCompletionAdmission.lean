/-
Read-only diagnostic for one exact retained event25 ingress. Run against a
byte-verified private copy of the Store with the source-qualified Host OLeans.
It opens/semantically replays the Store and asks the same verifier-minted
current-image admission used by the receiver; it never submits or assembles.
-/
import Host.Main

open Minidregg.Host
open Minidregg.Kernel

namespace ProbeCompletionAdmission

def run (configPath ingressPath : String) : IO Unit := do
  let settings ← loadSettings configPath
  let config := settings.config
  match ← NativeHostSession.start config with
  | .error detail => IO.println s!"REPLAY_ERROR: {detail}"
  | .ok session =>
      let ingressBytes ← IO.FS.readBinFile ingressPath
      match ApplicationLifecycleCompletionV2Ingress.codec.decode ingressBytes.toList with
      | none => IO.println "INGRESS_ERROR: noncanonical event25 bytes"
      | some ingress =>
          match ← NativeHostReplay.admitCompletionV2Verified session.verified ingress with
          | .error detail => IO.println s!"ADMISSION_ERROR: {detail}"
          | .ok _ => IO.println "ADMITTED"

end ProbeCompletionAdmission

#eval ProbeCompletionAdmission.run
  "/home/ember/build/mini-r3-op38-diagnostic/probe-config.json"
  "/home/ember/build/mini-r3-op38-diagnostic/completion-v2.bin"

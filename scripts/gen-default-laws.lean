/-
scripts/gen-default-laws.lean -- emit (or check) the default-law templates from Kernel.DefaultLaw.

  lake env lean --run scripts/gen-default-laws.lean           write deploy/shell/templates/defaults/
  lake env lean --run scripts/gen-default-laws.lean --check   exit 1 if the templates are not this module's rendering

The templates are `Host.Json.predicateJson` of `accountLaw`/`roomLaw` at a sentinel
subject, with the sentinel replaced by the placeholder the client substitutes
(`@OWNER`, `@FOUNDER`; the `@FOUNDER` convention is `law.keys.json`'s). The writer
re-parses each template at three concrete subjects and refuses unless the parse is
the Lean law (`Pred` equality), so the artifact is the definition, not a copy of it.
-/
import Kernel.DefaultLaw
import Host.Json

open Minidregg.Kernel.DefaultLaw
open Minidregg.Pred

/-- A subject id no deployment issues. -/
def sentinel : Nat := 2 ^ 62

def templateDir : String := "deploy/shell/templates/defaults"

structure Template where
  file : String
  placeholder : String
  law : Nat → Pred

def templates : List Template :=
  [⟨"law.account.json", "@OWNER", accountLaw⟩, ⟨"law.room.json", "@FOUNDER", roomLaw⟩]

def render (t : Template) : String :=
  (Minidregg.Host.Json.predicateJson (t.law sentinel)).pretty.replace
    (toString sentinel) t.placeholder ++ "\n"

def readme : String :=
  "# Default laws, emitted from `Kernel/DefaultLaw.lean`\n\n" ++
  "Written by `scripts/gen-default-laws.sh`; `--check` refuses a drift. Do not edit by hand.\n\n" ++
  "| template | placeholder | installs on | Lean |\n|---|---|---|---|\n" ++
  "| `law.account.json` | `@OWNER` = the owner's subject id (decimal) | member accounts (`fleet.rs`, shell provisioning, `genesis.sh` sponsor/clock `accountPredicate`), tills (`credit-permit-all.json`), Hermes budget accounts | `DefaultLaw.accountLaw` |\n" ++
  "| `law.room.json` | `@FOUNDER` = the founder's subject id | the private room cell (`roomkey.rs` `ROOM_LAW`) | `DefaultLaw.roomLaw` |\n\n" ++
  "Substitute the placeholder for the decimal subject before parsing, as `roomkey.rs` does for `law.keys.json`'s `@FOUNDER`.\n" ++
  "Theorems: `account_step_needs_owner`, `room_governance_needs_founder`; teeth against permit-all:\n" ++
  "`permitAll_admits_stranger_transfer` / `accountLaw_refuses_stranger_transfer`.\n"

/-- The template, with the placeholder replaced by `owner`, parses to the Lean law. -/
def roundTrip (t : Template) (owner : Nat) : Except String Unit := do
  let json ← Minidregg.Host.Json.parse ((render t).replace t.placeholder (toString owner))
  let parsed ← Minidregg.Host.Json.predicate "$" json
  unless parsed == t.law owner do
    throw s!"{t.file} at subject {owner} does not parse back to the Lean law"

def main (args : List String) : IO UInt32 := do
  let check := args.contains "--check"
  for t in templates do
    for owner in [0, 5, 123456789] do
      match roundTrip t owner with
      | .ok () => pure ()
      | .error reason => IO.eprintln s!"gen-default-laws: {reason}"; return 1
  let files := templates.map (fun t => (s!"{templateDir}/{t.file}", render t)) ++
    [(s!"{templateDir}/README.md", readme)]
  if check then
    let mut drift := 0
    for (path, expected) in files do
      let actual ← try IO.FS.readFile path catch _ => pure ""
      unless actual == expected do
        IO.eprintln s!"gen-default-laws: {path} drifts from Kernel/DefaultLaw.lean"
        drift := drift + 1
    if drift > 0 then return 1
    IO.println s!"gen-default-laws: {files.length} files match Kernel/DefaultLaw.lean"
  else
    IO.FS.createDirAll templateDir
    for (path, content) in files do
      IO.FS.writeFile path content
    IO.println s!"gen-default-laws: wrote {files.length} files under {templateDir}"
  return 0

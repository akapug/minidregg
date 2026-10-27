/-
`lake env lean --run scripts/AppsRequestTemplate.lean > native/resource-client/templates/apps/request/law.apps`

The app-install request template is the Host's own rendering (`LawLeaf.renderClause`, the text a
refusal and `law show` print) of `Kernel.AppsRequest.law` at sentinel parameters, each sentinel
replaced by its placeholder. Lean is the law's one source; the client binds the placeholders and
parses the text (`native/resource-client/src/apps.rs`). Check: `diff <(lake env lean --run …) law.apps`.
-/
import Kernel.AppsRequest
import Compiler.RefusalReason

open Minidregg.Kernel.AppsRequest

def sentinels : List (Int × String) :=
  [(900000000000000001, "{REQUESTER}"), (900000000000000002, "{MANAGER}")]

def sentinel : Params := ⟨900000000000000001, 900000000000000002⟩

def subst (text : String) : String :=
  sentinels.foldl (fun acc (value, name) => acc.replace (toString value) name) text

def main : IO Unit := do
  IO.println "-- apps/request: one member's request to run one signed Sandstorm package as a grain (docs/APP-MARKET-2026-10-27.md §3)."
  IO.println "-- Written by scripts/AppsRequestTemplate.lean: the Host's rendering of Kernel/AppsRequest.lean `law`."
  IO.println "-- Placeholders: {REQUESTER} the member's subject; {MANAGER} the hosting manager's subject."
  IO.println "-- Fields in fields.json: 1 state (0 requested, 1 running, 2 refused); 2, 3 the packageId as two 64-bit words;"
  IO.println "-- 4-7 the appId as four 64-bit words; 8 class (1 S, 2 M, 3 L); 9 grain; 10 generation."
  for (clause, note) in (clauses sentinel).zip notes do
    IO.println s!"-- {note}"
    IO.println (subst (Minidregg.Compiler.LawLeaf.renderClause clause) ++ ";")

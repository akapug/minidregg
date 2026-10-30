# Shell templates

These are the files that `mini shell` verbs load without changing them. Each
directory's README gives the order in which its verb reads its files. The verbs
are `native/resource-client/src/shell_grammar.rs` (`story`, `summon`, `ask`,
`dismiss`, `room`, `chat`, `market`). `mud/` is not loaded by any verb (its README).

| verb | reads | contract |
|---|---|---|
| `story new NAME --from tale\|@FILE` | `story/tale/table` (compiled into `mini`) or `HOME/requests/FILE`; runs `room/story/template.shell` | `story/README.md` |
| `story seal NAME` / `story invite NAME S` / `look` / `go` / `take` / `act` / `narrate` | the table document; the law each player's cell carries is generated from it (`story/tale/law.player*`, `scripts/gen-storylaw.py`) | `story/README.md` |
| `summon ROOM as librarian\|runner [--budget N]` | `hermes/ROLE/budget.json`, `grants.json`, `program.md` (compiled into `mini`) | `hermes/README.md` |
| `ask ROOM TEXT` | the room cell's `hermes` field (a signed read) | `hermes/README.md` |
| `dismiss ROOM` | the summon record `HOME/hermes/ROOM.json` (the grants it made) | `hermes/README.md` |
| `room new NAME --template workroom\|social\|story` | `room/T/template.shell` (compiled into `mini`; `room template show T` prints it) | `room/README.md` |
| `room welcome NAME SUBJECT --template social` | `room/social/member.shell` | `room/README.md` |
| `chat new ROOM` / `chat invite ROOM S` | `room/chat/law.author.json` (compiled into `mini`; `@SUBJECT` = the founder, or S) | `room/chat/README.md` |
| `room new NAME --private` | `room/private/law.room.json` (the room), `room/private/law.keys.json` (its keys cell, `@FOUNDER` replaced) — compiled into the client with `include_str!` | `room/private/README.md` |
| `market open NAME CLOSE REVEAL-END SUPPLY` | `market/sealed/law.market` (bound in the client, `market.rs`), `market/sealed/fields.json` | `Kernel/SealedMarket.lean` (the law's source; `law.market` is its rendering, `scripts/SealedMarketTemplate.lean`) |

`law.X` is the §2.6 one-line grammar. `law.X.json` is the same predicate as
`Pred` JSON, which `law ID REF @FILE` installs today: shell.rs wraps it as
`{"type":"minidregg-workspace-proposal-v1","action":"install-policy","name":REF,"predicate":<file>}`
(`native/resource-client/src/shell.rs:424`, `:1590`; `json_argument` at `:819`).
The Host parses it with exact keys and canonical signed decimal strings
(`Host/Json.lean`, `leSlotsOff` at `:307-312`). `@FILE` is read from
`HOME/requests/FILE`, a plain name, so a verb has to copy the substituted
template there before it installs it.

## What the laws rely on

The sources are in the code; this is where to look, not a copy.

- **Slots.** A declared cell's field `n` is addressable as `resource/field/n/before`,
  `/after` and `/delta`, and as pair deltas (`Kernel/DeclaredResourceProjection.lean:33-44`).
  `monotone` and `writeOnce` compare old and new `/after`. Field keys are numbers,
  never names (`DeclaredResourceProjection.lean:17-22`); each template's `fields.json`
  or `table` maps its names to numbers.
- **Atoms.** The `Pred` constructors are `Pred/Core.lean:170-203`: `eq`, `le`, `memberOf`,
  `writeOnce`, `monotone`, the slot-to-slot atoms `eqSlots`, `leSlots`, `leSlotsOff`,
  `sumEq`, `witnessed`, `hashEq`, `ran`, and the boolean closure. `room/private/law.keys.json`
  and `job/law.job.json` use `eqSlots`. `writeOnce` admits a rewrite of the same value
  (`Pred/Core.lean:177`).
- **Verb tags.** `Compiler/CredentialAuthorityEntryCodec.lean:86-110` is the table the
  canonical runtime profile uses (`Compiler/CanonicalRuntimeProfile.lean:232-237`):
  observe 1, mutate 2, delegate 3, installPolicy 4, revokeCapability 5, observePayment 6,
  appendObject 7. `Theory/AuthorizationDeclaration.lean:69-90` has a second `verbTag`
  with other numbers (installPolicy 10, revokeCapability 11); the laws here use the first table.
- **Names.** A reference name is a word, or words joined by `/` under a room
  (`workspace.rs:136` `validate_ref_name`). The story templates spell cells
  `{STORY}-state`, `{STORY}-scene-{N}`, `{STORY}-player-{S}`; the room templates use `$ROOM/index`.

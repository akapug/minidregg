# Source map for the site

Every factual sentence on the hand-written pages, and the file and lines it comes from, on
`lane/W14-WEBSITE-REGEN` over main `df0cd116` (2026-10-05). `status.html` is not listed:
`gen-status.py` generates it from the README's What is live table (`README.md:87-113`), each
row carrying the landing commit or journey row it rests on, and the `website` gate fails when
it is stale. When a source changes, fix the page and this map in the same commit. Paths are
relative to the repository root. FRIENDS = `deploy/shell/FRIENDS.md`; OB =
`docs/OBJECTIVE-BEND.md`; EV = `docs/OBJECTIVE-BEND-EVENTS.md`. A commit id is a landing
commit on main; a journey row is a row of `scripts/pipeline/journey-rows:15`, run by the
continuous runner (its tables live outside this repository: `objective` PASS with 17 rows and
2 readbacks, `activity` and `seats` ABSENT, at main `4795b657`).

## index.html

| Claim | Source |
| --- | --- |
| one shared world; one Lean-owned admission path; durable world root; refusal explained by clause; lost reply stays undecided with its exact retry | docs/DEMO-EXPERIENCE-2026-10-27.md §0 |
| computation proposes, authority admits | README.md (the design paragraph); DEMO-EXPERIENCE §0 |
| "machine-checked" names the admission path's theorems, not every deployed behaviour | DEMO-EXPERIENCE §0 |
| shuts down 11 November 2026 and everything is erased; opening target 29 October 2026 | README.md "The demo" |
| devnet; may be re-genesised | deploy/shell/FRIENDS.md "beta, read this first"; DEMO-PREFIX §3 |
| world-readable; hosted key held on the box, readable by operator and own account | DEMO-PREFIX §5 (D8); deploy/door/README.md (Custody contract) |
| privacy not audited | FRIENDS:386-388 |
| free route: fixed seats (door default 50), closes below the sponsor floor | deploy/door/README.md (Funding and caps: freeCap, sponsorFloor) |
| paid route 50 DREGG a week on Solana; wallet, ssh key, account publicly linked; not yet live | README.md "What is live" (Pay-to-enrol); deploy/pay/enrol-terms.json |
| application readable without an account | deploy/web/README.md |
| door/application may answer 503 until the door opens | README.md "What is live" (rehearsal row: `/join` held closed) |
| nano's testground at nano.demo.dregg.online | README.md "The demo"; DEMO-PREFIX §2 |
| the repository and host binary keep the name minidregg | README.md |

## language.html

| Claim | Source |
| --- | --- |
| lazy open recursion over first-class, partial, composable specifications, after Faré | OB:4-6 |
| Mini supplies identity, authority, effect admission, funding, disclosure | OB:6-9 |
| specification `C → V → W`; final self; inherited super | OB:22-25 |
| `mix` formula; `fix` computes the fixpoint | OB:32, 35, 54 |
| call-by-name reference semantics, call-by-need machine | OB:53 |
| `{good = 7, bad = self.bad}.good` is 7 | OB:38 |
| `perform` yields a typed Plan, resumed with a typed response | OB:66 |
| the kernel side of activities (checkpoint, answer slots, resume with view, paid exhaustion, abandonment) is compiled and proved; no Host operation reaches it | EV:15-19, 161-340; commits 8194e09d, 67362781, d1ce7b0c |
| the checker returns a typing derivation; affine and linear are at most once | OB:69-77 |
| example (an excerpt) | docs/tutorial/ch4-specs.obend:10-20 (checked by the `website` gate) |
| `Billing` sees a later layer; `bill(2)` is 7, then 9 with `Surcharge` | docs/OBJECTIVE-BEND-TUTORIAL.md:683-705 |
| a gate re-runs every tutorial command and fails on a changed output | scripts/check-objective-frontend.sh:27-28; scripts/check-objective-tutorial.ts:1-8, 40-48 |
| proofs in `Theory/ObjectiveBend*.lean`; axioms `propext`, `Classical.choice`, `Quot.sound`; no `sorry` | OB:179-187 |
| soundness (weak head) | OB:194 |
| preservation | OB:197 |
| no refusal; divergence and exhausted limits remain possible | OB:198 |
| completeness at large enough limits; no bound on them | OB:202, 212-218 |
| every compiled call runs the fast machine, equal by theorem | docs/OBJECTIVE-BEND-BACKENDS.md:17; OB:182-188 |
| when the checker accepts the front end's output it is typed, never refused, a finished run is a deep evaluation; the checker's reading of the packet is the elaborator's term | Compiler/ObjectiveBendFrontEndAdequacy.lean:34, 43, 51; Compiler/ObjectiveBendTermWire.lean:69, 280; OB:437-446 |
| the default build does not re-check the proofs; the `ObjectiveProofs` gate does, with a statement and axiom snapshot | OB:243-262; scripts/check-objective-proofs.sh:1-14; ObjectiveProofs.lean:1-4 |
| no surface semantics; the front end is one Lean program, trusted; the receiver re-runs it and admits only an equal core | OB:226, 437-466; Kernel/ObjectiveBendNativeAdmission.lean:378-400 |
| a native Host admits Objective programs on scratch worlds, not on the public node | OB:299-346; journey row `objective` |
| the kernel's activities, object records and seats have no native route | EV:15-19; OB:348-385; docs/SEATS.md:9-17 |

## laws.html

| Claim | Source |
| --- | --- |
| a law is a predicate checked on every change to a resource, whoever proposed it | OB:414-421 |
| three things called law: the cell law, the `.obend` spec `law` (never reaches admission), `requires` (recorded, not checked) | OB:414-435 |
| admission clauses `invariant`, `guard`, `permit`, `forbid` are a design, not built | OB:428-435; Compiler/ObjectiveBendParse.lean:640 |
| every law state begins with the slot `objective/artifact`; `-1` for a command without an Objective claim | Pred/Core.lean:156; Kernel/DeclaredResourceController.lean:214, 514; OB:387-401 |
| the `objectivePin` clause accepts only steps naming a pinned artifact; an ordinary command is refused | Pred/Core.lean:372-395; Kernel/DeclaredResourceController.lean:523, 534 |
| no turn installs the pin at object birth | OB:404-412; Kernel/ObjectiveActivity.lean:1993; Kernel/ObjectRecord.lean:185 |
| a cell is an object only with a record (pin, law, upgrade policy, payer); a birth without one, or of another package, is refused | Kernel/ObjectRecord.lean:62-70; Kernel/ObjectiveActivity.lean:2933, 2943 |
| every declared-state write is judged by the object's law over the old and new state; a refusal names the clause and commits nothing | Kernel/ObjectRecord.lean:202-209; Kernel/ObjectiveActivity.lean:2904, 2915, 2925; EV:357-385 |
| a resumed activity's write is judged as its birth subject, never the deliverer | Kernel/ObjectiveActivity.lean:2915-2921; EV:357-385 |
| an activity is a persisted checkpoint plus one await; one decider, one deadline, decided once | Kernel/ObjectiveActivity.lean:141-166; Kernel/AnswerSlot.lean:33-50, 125-136; EV:161-215 |
| a resume delivers the outcome and the state and version read in the same turn; no write is computed from a stale read | Kernel/ObjectiveActivity.lean:533, 2338, 2370, 2400; EV:218-250 |
| exhaustion is a paid turn; ended activities leave tombstones; abandonment after deadline plus grace returns the purse minus the timeout fee | Kernel/ObjectiveActivity.lean:1587-1612, 2647, 2769, 2842; EV:325-356 |
| one public tariff prices every declared envelope, for native admission and activities | Kernel/ObjectiveTariff.lean:17-52; Kernel/ObjectiveBendNativeAdmission.lean:468; EV:306-324 |
| a seat holds one side of a contract in its own Book account; law is offer safety; judged on every reallocation; the offerer's exit consults no contract clause | Kernel/Seat.lean:70-72, 395-402, 471, 550-556, 945; docs/SEATS.md:33-62 |
| status table: landing commits | 2a7c372b, eac4b18c, de9c84f7, 8194e09d, 67362781, d1ce7b0c, bf28dd19, 6347dcb4, 6df4602f, 73223088, a2454432 (`git show --stat` on main) |
| status table: journey rows | scripts/pipeline/journey-rows:15, 40, 65-91 |
| in flight (lane names): activity route, seats native, retention charge, record upgrades, turn gate, laws receiver | OB:381-385; EV:15-19 |

## architecture.html

| Claim | Source |
| --- | --- |
| a signed request; admitted with a receipt or refused with a reason | FRIENDS:81-84 |
| checked against capabilities, laws, exact read roots, funding | README.md:17-20 |
| a computation re-run at admission and on every replay; no admission uses a proof | README.md:180-182; docs/SDK.md:135-136 |
| an Objective invocation: the receiver re-runs the front end on the package, requires a core equal to its own, prices the declared envelope by the tariff, requires the Plan's effects to equal the command's; ran on scratch worlds | OB:299-346; Kernel/ObjectiveBendNativeAdmission.lean:378-400, 468, 578, 650 |
| Selvage outside the deployed umbrella except 12 modules through the digest backend | Deployed.lean:4-9, 14-16 |
| grants with verbs; revocation | FRIENDS:168-173, 231 |
| a law is checked on every change; a law that denies everything is permanent | FRIENDS:186-196 |
| the lock transcript (comments moved to their own lines; the unlock refusal's detail elided) | FRIENDS:190-193 |
| receipt: transaction id, world root, confirmation `installed` / `replayed` / … | docs/SDK.md:18-20 |
| fourteen refusal reasons | Compiler/RefusalReason.lean:56-88; FRIENDS:570-584 |
| a lost reply is a lookup of the same call bytes | docs/SDK.md:79-80 |
| a retry returns the same receipt | FRIENDS:182-184 |
| SDK in Rust and TypeScript, byte-identical | docs/SDK.md:3-5, 90-91 |
| on the device; operator untrusted; member-selected Lean consent process re-derives and returns the header bytes; nothing else is signed | docs/SDK.md:40-47 |
| a browser has no consent process and must not sign until a bridge exists | docs/SDK.md:91-95 |
| private rooms: main only, devnet quality, privacy not audited | FRIENDS:386-388 |
| sealed on the member's machine; key held only wrapped to each member | FRIENDS:389-392 |
| X25519 + ML-KEM-768 wrap | FRIENDS:420-422 |
| the node sees membership, timing, sizes in 64-byte steps | FRIENDS:417-419 |
| founder key trust on first use | FRIENDS:412-415 |
| Generic Simplex BFT engine in Lean, compiled native | README.md:53-55 |
| n = 3f + 1, at most f Byzantine | docs/GENERIC-SIMPLEX-NATIVE.md:11-12 |
| safety over the engine model; liveness not established; four replicas on one host | README.md:80 |

## join.html

A redirect to https://demo.dregg.online/join (meta refresh and a link); no factual claim beyond the shutdown date (README.md "The demo").

## edition.html

Added on `lane/website-edition` over main `9123503ff` (2026-10-27). DE = `docs/DEMO-EXPERIENCE-2026-10-27.md`; WF = `docs/WEB-FRONTEND-2026-10-27.md`; AM = `docs/APP-MARKET-2026-10-27.md`; HP = `docs/HOT-PATH-2026-10-27.md`. Every row is also a row of the README's What is live table (`README.md:87-113`), which `status.html` renders.

| Claim | Source |
| --- | --- |
| the box still serves an earlier rehearsal, every login closed, `/join` closed until the owner opens it | README.md:87 (The box today); docs/DEMO-PREFIX-2026-10-26.md §2 |
| the door opens on the owner's word; shuts down 11 November 2026 and everything is erased | README.md "The demo"; index.html rows above |
| one admission path for documents, grants, money, programs, applications; refusal names its clause; the web shows the request that would pass | DE:53 (step 4), DE §0; README.md:22 |
| the client keeps the exact call before sending; undecided attempt retried byte for byte | native/mini-sdk/src/custody.rs:1-27, 145; DE:55 (step 6) |
| join: a name, a hosted key, one session link | DE:51 (step 2); WF (door rows) |
| free route has a fixed number of seats | deploy/door/README.md:95 (`freeCap`) |
| paid route 50 DREGG a week on Solana mainnet | deploy/pay/enrol-terms.json |
| every shell command has a web form, 203 leaves; outcomes announced as live regions | README.md:95 (web pages row); native/resource-client/src/web/verbs.rs:610; native/resource-client/src/web/body.rs:1240 |
| export archive of documents, receipts and key, streamed then deleted; one per member per 10 minutes | WF:182, WF:197-199 |
| research consent: unchecked box at the door, a fact in the member's world, shown and changeable on the export page | WF:185-193; deploy/policy/RETENTION.txt |
| a built-in tale under a sealed law; a member can install a law and see the next write judged | DE:65-66 (doors 11, 12); Kernel/StoryLaw.lean |
| the `bend` command is in this edition | docs/DEMO-PREFIX-2026-10-26.md:344; native/resource-client/src/bend.rs |
| Discord: same subject over the gateway | DE:63 (door 9); native/discord-entrance |
| agent residents on a shared key; per-member share, $1 a day and $4 in all on the demo's numbers | deploy/hermes/README.md:128-135 |
| subscriber tier: pay a week, invitation in the inbox, house agent on glm-5.3-flash | WF:183, WF:230; native/resource-client/src/web/subscribe.rs:144 |
| any Sandstorm package from the real store; 13 featured apps listed first with an agent hook | AM:50-52 |
| WebDAV, CalDAV and git work; request bodies up to 8 MiB | commit dfdecbbac; AM:91, AM:379 |
| limits on connections and in-flight requests per member at the gateway; size classes for applications | WF:197-199; deploy/spk-host/README.md:114 |
| platform cell: kind and install receiver built; genesis seed, replay, Host operations, births priced from the cell not complete | Kernel/PlatformCell.lean; Kernel/PlatformInstallReceiver.lean; docs/DEMO-PREFIX-2026-10-26.md:159-161 |
| compaction built; a 483-record Store took 160 to 175 s to open before it; the checkpoint-carrying-the-world open is stated and being proved | HP:118-122; commit 2421dc511; commit 107f040d9 |
| invite reserve of free seats is on main, not yet on the box | deploy/door/README.md:97-100; commit 9e3d6c731 |
| qualifying apps with one write each toward two to three dozen; two browsers co-editing not working yet | AM:44-52, AM:86-88 |
| effect Plans: the first keystone proved; transfers and commits being finished | Kernel/ObjectiveActivityEffect.lean; commit b1ff71950; docs/DEMO-PREFIX-2026-10-26.md:39 |
| per-member request rate in the Host stated and proved, not wired in | Kernel/SubjectRate.lean; docs/PD-HOST-RATE-DESIGN.md:1-5 |
| not in this edition: fn transport and a second node | docs/DEMO-PREFIX-2026-10-26.md:344 |
| not in this edition: the oracle as an application | DE:62 (door 8); docs/ORACLE-GRAIN-2026-10-27.md |
| not in this edition: a networked private-computation service | docs/UNTOUCHED-DEPUTY-STATE.md:25 |
| Lean owns admission; every keystone enters as a stated theorem before proof work | README.md:22; CLAUDE.md:18 |

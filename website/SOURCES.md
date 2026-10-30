# Source map for the site

Every factual sentence on the hand-written pages, and the file and lines it comes from. The
index, language, laws and architecture rows were re-checked against the tree on `lane/docs`
over main `6025da094` (2026-10-28). `status.html` is not listed:
`gen-status.py` generates it from the table in `docs/STATUS.md:5-33`, each
row carrying the landing commit or journey row it rests on, and the `website` gate fails when
it is stale. When a source changes, fix the page and this map in the same commit. Paths are
relative to the repository root. FRIENDS = `deploy/shell/FRIENDS.md`; OB =
`docs/OBJECTIVE-BEND.md`; EV = `docs/OBJECTIVE-BEND-EVENTS.md`; DE =
`docs/DEMO-EXPERIENCE-2026-10-27.md`; PREFIX = `docs/DEMO-PREFIX-2026-10-26.md`. A commit id is a
landing commit on main; a journey row is a row of `scripts/pipeline/journey-rows:15`, run by the
continuous runner on scratch worlds. The runner's result tables live outside this repository, so
the site names rows and never their verdicts.

## index.html

| Claim | Source |
| --- | --- |
| one shared world; one Lean-owned admission path; durable world root; refusal explained by clause; lost reply stays undecided with its exact retry | DE:13-18 (§0) |
| computation proposes, authority admits | DE:17-18; README.md:13-14 |
| "machine-checked" names the admission path's theorems, not every deployed behaviour | DE:34-36 |
| shuts down 11 November 2026 and everything is erased; opening target 29 October 2026 | PREFIX:338 (shutdown), :60 (opening target); FRIENDS:20-23 |
| may be re-genesised | FRIENDS:20-22 |
| world-readable; hosted key held on the box, readable by operator and own account | FRIENDS:52-58, 62-64; deploy/door/README.md (Custody contract) |
| privacy not audited | FRIENDS:170-171; native/resource-client/templates/room/private/README.md:3 |
| free route: fixed seats (door default 50), the last can be held for invite codes, closes below the sponsor floor | deploy/door/README.md:95 (`freeCap`), :97-100 (`inviteReserve`), :117-118 (`sponsorFloor`) |
| paid route 50 DREGG a week on Solana; wallet, ssh key, account publicly linked | deploy/pay/enrol-terms.json:6-7 (`decimals` 6, `weekPriceAtomic` 50000000); docs/STATUS.md:13; FRIENDS:195-196 |
| application readable without an account | deploy/web-frontend/INSTALL.md:6-8 (the public reader) |
| until the door opens, logins and the join page are closed and pay-to-enrol is off | docs/STATUS.md:7; FRIENDS:12-14, 197-199 |
| nano's testground at nano.demo.dregg.online | PREFIX:84 (§2) |
| the repository and host binary keep the name minidregg | README.md:17 |

## language.html

| Claim | Source |
| --- | --- |
| lazy open recursion over first-class, partial, composable specifications, after Faré | OB:3-5 |
| Mini supplies durable identity (objects), current authority, admission, funding and the laws | OB:8-9 |
| specification `C → V → W`; final self; inherited super | OB:35-37 |
| `mix` formula; `fix` computes the fixpoint | OB:43-46, 48 |
| call-by-name reference semantics, call-by-need machine | OB:50-52 |
| `{good = 7, bad = self.bad}.good` is 7 | OB:49 |
| `perform` yields a typed Plan, resumed with a typed response | OB:335-337 |
| the kernel runs activities on objects (checkpoint, answer slots, resume with view, paid exhaustion, abandonment); each turn a signed Host operation, run on scratch worlds | OB:393-396, 458-525, 530-537; EV:144-148; protocol/host-operations.json:2241-2300 (codes 210-214) |
| the checker returns a typing derivation; affine and linear are at most once | OB:81-82, 90-92 |
| example (an excerpt) | docs/tutorial/ch4-specs.obend:10-20 (checked by the `website` gate) |
| `Billing` sees a later layer; `bill(2)` is 7, then 9 with `Surcharge` | docs/OBJECTIVE-BEND-TUTORIAL.md:671-675, 685-703 |
| a gate re-runs every tutorial command and fails on a changed output | scripts/check-objective-frontend.sh:34-35, 120; scripts/check-objective-tutorial.ts:1-10 |
| proofs in `Theory/ObjectiveBend*.lean`; every pinned axiom set within `propext`, `Classical.choice`, `Quot.sound` | OB:760, 766 |
| soundness (weak head) | OB:776 |
| preservation | OB:779 |
| no refusal at any limits; divergence, blackholes and suspension remain possible | OB:780 |
| completeness at large enough limits; no bound on them | OB:778, 824 |
| every compiled call runs the fast machine, equal by theorem; the substitution is trusted | OB:766-769; docs/OBJECTIVE-BEND-BACKENDS.md:17 |
| when the checker accepts the front end's output it is typed, never refused, a finished run is a deep evaluation; the checker's reading of the packet is the elaborator's term | OB:792-799; Compiler/ObjectiveBendFrontEndAdequacy.lean:35, 44, 52; Compiler/ObjectiveBendTermWire.lean:92, 303 |
| the default build does not re-check the proofs; a separate gate builds `ObjectiveProofs`, axiom sets pinned | OB:760-762; scripts/check-objective-proofs.sh:3-6; ObjectiveProofs.lean:1-4 |
| no surface semantics; the front end is one Lean program, trusted; the receiver re-runs it and admits only an equal core | OB:810-812, 688-690; Kernel/ObjectiveBendNativeAdmission.lean:455-470, 630, 790 |
| the `bend` verb: the Host's front end lowers and publishes, the program runs as a kernel activity on an object; carried by the next build | native/resource-client/src/bend.rs:1-23; docs/STATUS.md:3, 19 |
| Objective invocations, activities, object records and seats have run on scratch worlds only | OB:29, 535-537, 702; docs/SEATS.md:13-16 |

## laws.html

| Claim | Source |
| --- | --- |
| a law is a predicate checked on every change to a resource, whoever proposed it | OB:723-724 |
| compiled and proved; run through signed Host operations on scratch worlds; none deployed | OB:27-29, 530-537; docs/SEATS.md:13-16 |
| a cell law: decidable predicate over old and new state and the request; the judge of admission | OB:723-725 |
| a package `law` is enforced on every object of the package; only a fragment compiles, the rest refused at parse | OB:726-733, 738-740 |
| a domain law: a cell law over several objects' joint state, judged at the end of every turn writing a member | OB:436-441, 743-744 |
| a spec `claim` is unchecked and never reaches admission | OB:745-750 |
| `requires` is checked and is not a precondition | OB:211-213, 751-752 |
| every law state begins with the slot `objective/artifact`; `-1` for a command without an Objective claim | OB:713-715; Pred/Core.lean:175 |
| the `objectivePin` clause accepts only steps naming a pinned artifact; an ordinary command is refused | OB:715-716; Pred/Core.lean:429-436 |
| every object's judged law leads with the pin clause, derived from the record, never stored | OB:405-408, 716-719; Kernel/ObjectRecord.lean:306 |
| a record holds pin, declared state type, package laws, creator's law, upgrade policy, payer | OB:398-401; Kernel/ObjectRecord.lean:142 |
| a birth without a record, or of another package, is refused | OB:416-417; Kernel/ObjectiveActivity.lean:5269, 5311 |
| no direct write of declared state; every write from a birth, delivery, call frame or delivered message | OB:413-417 |
| each write types at the state type and is judged by pin, package laws, creator's law, and at turn end the domains | OB:402-412; Kernel/ObjectRecord.lean:513 |
| a delivery's write is judged with the activity's principal as subject, never the deliverer; a refusal names the clause and refuses the whole turn | EV:88-94 |
| an activity is a persisted checkpoint plus one await; one decider, one deadline, decided once | EV:98-104; OB:466-467; Kernel/AnswerSlot.lean:294; Kernel/ObjectiveActivity.lean:4100 |
| a resume delivers the outcome and the state and version read in the same turn; no write from a stale read | OB:458-464; Kernel/ObjectiveActivity.lean:4455 |
| exhaustion is a paid turn | OB:517-520; Kernel/ObjectiveActivity.lean:4890 |
| ended record and settled slots retired, the id never returns | OB:522-524; EV:243-246 |
| abandonment after deadline plus grace pays the timeout fee and returns the rest | EV:250-254; Kernel/ObjectiveActivity.lean:5157 |
| one public tariff prices every declared envelope, for native admission and activities | OB:500-502, 685-686; Kernel/ObjectiveTariff.lean:43 |
| activity turns are signed native commands, Host operations 210-214, `mini activity` | OB:530-533; protocol/host-operations.json:2241-2300; Kernel/ObjectiveActivityReceiverCore.lean:152-228 |
| a seat holds one side of a contract in its own Book account; offer safety; judged on every reallocation; the exit path never reads the clause | docs/SEATS.md:3-5, 32-33, 55-57; Kernel/Seat.lean:1673, 1704 |
| seat turns are signed native commands, Host operations 215-219, `mini seat` | docs/SEATS.md:13-16, 37; protocol/host-operations.json:2306-2365 |
| status table: landing commits | 6df4602f, 73223088, a2454432, 2a7c372b, eac4b18c, de9c84f7, 7b97da60, 8194e09d, 67362781, d1ce7b0c, 34d803f8, bf28dd19, 6347dcb4, 2c1b5733, 6336af2b, 063ba6cd, 65277f41 (`git show --stat` on main) |
| status table: journey rows (names only; verdicts live outside the repository) | scripts/pipeline/journey-rows:15, 85, 123, 141, 347, 992 |
| the `bend` verb is carried by the next build | docs/STATUS.md:3, 19; native/resource-client/src/bend.rs:1-23 |
| not built: storage charge for packages, records and state cells; activities that call, send or await a message; objects holding capabilities; multi-turn migration | OB:626-628, 826-829 |

## architecture.html

| Claim | Source |
| --- | --- |
| a signed request; admitted with a receipt or refused with a reason | README.md:4-8; FRIENDS:89, 203-212; docs/SDK.md:13 |
| checked against capabilities, laws, exact read roots, funding | README.md:13-14; Compiler/RefusalReason.lean:85-90, 97-98; OB:686-688 (funding before execution, reads with exact guards) |
| a computation re-run at admission and on every replay; no admission uses a proof | OB:670-673, 694-695; docs/SDK.md:149-150 |
| Selvage is outside the deployed build; no module of the deployed closure imports it | Deployed.lean:4-10, 15-19 |
| an Objective invocation: the receiver re-runs the front end on the package, requires a core equal to its own, prices the declared envelope by the tariff, requires the Plan's effects to equal the command's; ran on scratch worlds, not deployed | OB:683-693, 697-702; Kernel/ObjectiveBendNativeAdmission.lean:275, 455-470, 575, 630; docs/OBJECTIVE-BEND-BACKENDS.md:18 |
| grants with verbs; revocation | FRIENDS:99-102 |
| a law is checked on every change | OB:723-724 |
| a law that admits nothing is permanent; the locked cell refuses every verb with `law-denied` | FRIENDS:132-144 |
| the lock transcript (comment dropped) | FRIENDS:138-139 |
| receipt: transaction id, world root, confirmation `installed` / `replayed` / … | docs/SDK.md:18-20 |
| seventeen refusal reasons | Compiler/RefusalReason.lean:80-134 (17 constructors); FRIENDS:214-219 |
| a lost reply is a lookup of the same call bytes | docs/SDK.md:79-80 |
| a retry sends the exact retained call and is never a second write | FRIENDS:108-111 |
| SDK in Rust and TypeScript, byte-identical | docs/SDK.md:3-5, 93-94 |
| on the device; operator untrusted; member-selected Lean consent process re-derives and returns the header bytes; nothing else is signed | docs/SDK.md:40-47 |
| a browser has no consent process and must not sign until a bridge exists | docs/SDK.md:94-98 |
| private rooms: devnet quality, privacy not audited, founder key trust on first use unless verified out of band | native/resource-client/templates/room/private/README.md:3; FRIENDS:170-171 |
| sealed on the member's machine under the room key; key held only wrapped to each member, X25519 + ML-KEM-768 | native/resource-client/templates/room/private/README.md:5-7, 26-30; docs/PRIVATE-ROOMS-DESIGN.txt:50 |
| the node sees who wrote what at which height, members' public encryption keys, sizes in 64-byte blocks | native/resource-client/templates/room/private/README.md:7-8 |
| in the hosted shell the room key is a file on the box | native/resource-client/templates/room/private/README.md:11-12; FRIENDS:171-172 |
| Generic Simplex BFT engine in Lean, compiled native, in progress | docs/GENERIC-SIMPLEX-NATIVE.md:1-9 |
| fixed committee n = 3f + 1, at most f Byzantine | docs/GENERIC-SIMPLEX-NATIVE.md:11-12 |
| safety over the engine model; liveness not a theorem | docs/GENERIC-SIMPLEX-NATIVE.md:65-70, 292-293 |
| four replicas on one host; one mesh committed two records and stalled on the third | docs/GENERIC-SIMPLEX-NATIVE.md:4-6, 285-287 |

## join.html

A redirect to https://demo.dregg.online/join (meta refresh and a link); no factual claim beyond the shutdown date (docs/DEMO-PREFIX-2026-10-26.md:336).

## edition.html

Added on `lane/website-edition` over main `9123503ff` (2026-10-27). DE = `docs/DEMO-EXPERIENCE-2026-10-27.md`; WF = `docs/WEB-FRONTEND-2026-10-27.md`; AM = `docs/APP-MARKET-2026-10-27.md`; HP = `docs/HOT-PATH-2026-10-27.md`. Every row is also a row of `docs/STATUS.md:5-33`, which `status.html` renders.

| Claim | Source |
| --- | --- |
| the box still serves an earlier rehearsal, every login closed, `/join` closed until the owner opens it | docs/STATUS.md:7 (The box today); docs/DEMO-PREFIX-2026-10-26.md §2 |
| the door opens on the owner's word; shuts down 11 November 2026 and everything is erased | docs/DEMO-PREFIX-2026-10-26.md:336; index.html rows above |
| one admission path for documents, grants, money, programs, applications; refusal names its clause; the web shows the request that would pass | DE:53 (step 4), DE:13-18 (§0) |
| the client keeps the exact call before sending; undecided attempt retried byte for byte | native/mini-sdk/src/custody.rs:1-27, 145; DE:55 (step 6) |
| join: a name, a hosted key, one session link | DE:51 (step 2); WF (door rows) |
| free route has a fixed number of seats | deploy/door/README.md:95 (`freeCap`) |
| paid route 50 DREGG a week on Solana mainnet | deploy/pay/enrol-terms.json |
| every shell command has a web form; outcomes announced as live regions | docs/STATUS.md:15 (Web pages and accessibility); native/resource-client/src/web/verbs.rs:610; native/resource-client/src/web/body.rs:1240 |
| export archive of documents, receipts and key, streamed then deleted; one per member per 10 minutes | WF:182, WF:197-199 |
| research consent: unchecked box at the door, a fact in the member's world, shown and changeable on the export page | WF:185-193; deploy/policy/RETENTION.txt |
| a built-in tale under a sealed law; a member can install a law and see the next write judged | DE:65-66 (doors 11, 12); Kernel/StoryLaw.lean |
| the `bend` command is in this edition | docs/DEMO-PREFIX-2026-10-26.md:344; native/resource-client/src/bend.rs |
| Discord: same subject over the gateway | DE:63 (door 9); native/discord-entrance |
| agent residents on a shared key; per-member share, $1 a day and $4 in all on the demo's numbers | deploy/hermes/README.md:128-135 |
| subscriber tier: pay a week, invitation in the inbox, house agent on glm-5.3-flash | WF:183, WF:230; native/resource-client/src/web/subscribe.rs:144 |
| any Sandstorm package from the real store; a featured set listed first with an agent hook | AM:50-52; native/resource-client/src/apps.rs:278 (`FEATURED`) |
| WebDAV, CalDAV and git work; request bodies up to 8 MiB | commit dfdecbbac; AM:91, AM:379 |
| limits on connections and in-flight requests per member at the gateway; size classes for applications | WF:197-199; deploy/spk-host/README.md:114 |
| platform cell: kind and install receiver built; genesis seed, replay, Host operations, births priced from the cell not complete | Kernel/PlatformCell.lean; Kernel/PlatformInstallReceiver.lean; docs/DEMO-PREFIX-2026-10-26.md:159-161 |
| compaction built; a 483-record Store took 160 to 175 s to open before it; the checkpoint-carrying-the-world open is stated and being proved | HP:118-122; commit 2421dc511; commit 107f040d9 |
| the last free seats can be held in reserve for invite codes | deploy/door/README.md:97-100; commit 9e3d6c731 |
| qualifying apps with one write each toward two to three dozen; two browsers co-editing not working yet | AM:44-52, AM:86-88 |
| effect Plans: the first keystone proved; transfers and commits being finished | Kernel/ObjectiveActivityEffect.lean; commit b1ff71950; docs/DEMO-PREFIX-2026-10-26.md:39 |
| per-member request rate in the Host stated and proved, not wired in | Kernel/SubjectRate.lean; docs/PD-HOST-RATE-DESIGN.md:1-5 |
| not in this edition: fn transport and a second node | docs/DEMO-PREFIX-2026-10-26.md:344 |
| not in this edition: the oracle as an application | DE:62 (door 8); docs/ORACLE-GRAIN-2026-10-27.md |
| not in this edition: a networked private-computation service | docs/UNTOUCHED-DEPUTY-STATE.md:25 |

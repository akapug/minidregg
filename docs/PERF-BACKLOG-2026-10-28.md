# Performance backlog (2026-10-28)

Present state of the perf rake: what the Host turn and the Rust request path waste,
ranked by expected wall-time win on the request path. Maintained by the perf-rake lane
(`lane/perf-rake`); rewritten whole, never appended.

## Baseline and how this was found

- Measured on candidate 349e59ef1 (hbox, SandMD app route): a GET costs 6 to 17 s
  wall, and each signed submit turn costs about 5.3 s of single-thread Lean CPU
  (strace: syscalls 0.27 s of 5.75 s). That covers one app route on one world; other
  routes have not been profiled.
- Host perf profile over a whole SandMD qualify (57,248 samples; stacks were depth 1, so
  self time only): `List.reverseAux` 19.2%, `lean_dec_ref_cold` 9.0%, `lean_apply_1/2`
  11.2%, `List.lengthTR` 4.2%, GMP `mpz_set_str` 3.8% + 2.0% (decimal Nat literal
  parses), allocator about 8%, `List.Lex` decidable 3.0%, keccak 3.7%, `pushList`
  (List to ByteArray before hashing) 2.3%, `List.find?` 2.0%. The real work (keccak) is
  under 4%; most of the rest is `List UInt8` codec traffic, closures and re-derivation.
- The rake: 174 shards over the Host's Lean import closure (790 modules, 346K lines) plus
  native/spk-host, mini-web, grain-runtime and resource-client, each read by a GLM
  flash reader (prompt and raw reports in the perf-rake scratch:
  `findings/batch-NNN.md`). Readers misread: every item below is marked VERIFIED
  (the manager read the code, and where it says C, checked the emitted C) or
  UNVERIFIED (a reader's claim, not yet confirmed). Rule learned while verifying: two
  identical pure calls in one function body are shared by the compiler (CSE). Waste is
  real when the repeated work sits inside a lambda (per element or per lane), in
  separate functions, or behind a structure the compiler cannot see through.
- **Document-submit benchmark** (`scripts/perf/doc-submit-bench.py`, a fresh scratch Store, N
  appends to one document): on 349e59ef1 (dregg-build) the Host CPU per submit grows linearly
  with the Store's history, about 60 ms per prior record: 420 ms at the 1st append, 1,380 ms at
  the 20th, 2,890 ms at the 40th (propose 110 to 250 ms). The per-submit work is O(history) with a
  large constant; that, more than any single hot function, is the 5.3 s. gdb samples of the
  36th-40th submits on hbox are being taken to name the per-record loop.
- Performance is published, never a gate. No item below has a before/after submit
  number yet; the first candidate carrying the landed fixes is the build after
  9bd52317c, and the A/B runs there with `scripts/spk-platform/route-cpu-probe.sh`
  (lane/un-route-latency 3de917395).

## Landed on main

| sha (main) | change | evidence |
|---|---|---|
| d7cbd3712 | `NatDigits255Fast.digitsBytes` (every `encodeNat`) and Tower256 `fixedValueAt` no longer parse a decimal literal per call (`lean_cstr_to_nat`, the GMP 5.8% in the profile) | C: literal only in the n >= 2^63 branch |
| 65a355243 | StoreCodec `rootBytes` roots the decoded entry list (no DFinsupp rebuild, dedup tree, sort, per-address lookup); blinding key once per cell | C: materializer closure is `rootBytesFast` |
| 41d87f720 | spk-host resident dispatch loop wakes on a handed-over request (was a 20 ms poll tick, ~10 ms average per request) | 20 filtered tests |
| (lane/un-route-latency 94b8de93c, merged) | `ApplicationDispatchPending.charge` and twins: intent no longer re-derived per lane query (~40x per submit) | owner: ac1e69b |

## On lane branches, being checked

| branch / sha | change | status |
|---|---|---|
| lane/perf-rake 9d64ce7d6 | store comparisons one pass (`FastKeyOrder`, `lexLt`, no typed-`Sigma` equality); directory slot reads by a row table, hashed Nodup and dedup (session advance was O(cells^2)); list equality identity-first (`instDecidableEqList` csimp) so unchanged-cell byte compares on advance are O(1); `DecidableEq Image` identity-first (rememberReadback encoded the whole history twice per submit) | Compiler half green on dregg-ref; Kernel tail in lane-check |
| lane/perf-rake 84d8710b2 | `refusalAtTip?` (per dispatch submit) rebuilt the command + hashed the marker per accepted record -> cached first-index table; `validateCore` cell-law check ran twice per validation -> once; `ObjectiveActivityWire.readOnly` re-hashed every post per guard -> post cells; ObjectiveActivity `charge` storage lane re-derived per lane query -> materialized once | in lane-check |
| lane/perf-codec-writer 00580de11 | `StreamCodec.encodeInto` writer on every combinator, `@[csimp]` encode via writer (no nested `List` append, the 19% `reverseAux`); StoreCodec leaves/root hashed from written buffers (no `pushList`) | 16 modules green on dregg-build; closure check pending |
| lane/perf-roots 523bba473 (local) | cell roots computed once per image: Engine root table (lazy per cell), `Materialized` caches bytes and root (`@[csimp]`), CredentialAuthorityDomain snapshot root read once | closure building on dregg-ref /srv |
| lane/perf-rust 54c0cdb49, 89711f979, 6582aed46, 3de71b986 | mini-web assets hashed once, registry/laws render cached by file identity; pinned inputs (host image in grain-runtime at nine call sites, spk-host config in `check_pin`) verified once per file identity (dev, ino, size, mode, uid, mtime, ctime) instead of read and SHA-256'd per call (the host binary is 169 MB); scratch helper inputs unsynced (recovery-read files keep both fsyncs); child waits by pidfd; one `systemctl show` per `verify_running_instance`; `exact_acl` reads the ACL xattr instead of forking `getfacl`; `CallerWatch` in `poll(2)`; one journal scan in `admit_new_call`; hex compares without encoding; readiness polls instead of 2 ms sleeps | Mac cross-check clean; Linux filtered tests running on dregg-ref |

## Ranked backlog: verified, not yet taken

Ordered by expected wall-time win on the request path. "Owner" is the lane that holds it
now, or "open".

1. **Genesis seed re-encoded and re-hashed per validation** (VERIFIED, S).
   `Kernel/NativeHostContext.lean` `validateChecks`: `seedIdentity seed` and
   `config.logStart seed` each encode the whole genesis seed (`seedStream`, every
   genesis cell's bytes) and hash it, on every session advance (`validateLoadedFrom`)
   and every open. The seed never changes within a Store. Fix: `Opened` carries the
   evidence that its seed passed, and `validateLoadedFrom` skips the two hashes when
   the next image's seed is the prior's (an identity-first `DecidableEq Seed`, as for
   `Image`). Same refusals in the same order (`validateLoadedFrom_eq` keeps holding).
   Owner: open (perf-rake next).
2. **Profile semantics re-derived per use** (VERIFIED, S). `Config.profile` rebuilds the
   profile and `.semantics` hashes the runtime manifest (`receiverSemanticsFrom`) at
   every reference: 1-4 times per request (NativeHostKeyCommitmentAdoption computes it
   four times in one handler; `heldFor` per decision; `worldRoot`, `logStart`,
   `anchorIdentity`). The gdb sample under the old charge showed it. Fix: `Config`
   holds a `Thunk` of its profile with an exactness field, and `Profile` holds its
   semantics digest the same way, with `@[csimp]` on both accessors. Two `{ config with
   .. }` sites that change profile inputs (NativeHostContext:154, BirthRuntimeProfile:57)
   restate with the cache field. Owner: perf-rake.
3. **Five Lean host helper processes per request** (VERIFIED, S; startup alone 70 ms on
   dregg-build). `native/spk-host/src/dispatch_native.rs` `author_signed_ingress` /
   `author_and_submit` exec the pinned host for author, plan inspection, signatures,
   route-bound author and committed inspection, while the same host already serves the
   operator socket. Fix: serve them as operator-socket operations (a new entry in
   `protocol/host-operations.json`, generated Rust and Lean arms), keeping the per-attempt
   files for audit. Owner: open (needs one Lean + one Rust edit).
4. **Pred state reads are linear string scans** (VERIFIED, S; profile: `List.find?`
   2.0% + `Pred.State.get` lambda 1.2%). `Pred/Core.lean` `State.get` is `find?` over
   `List (String × Int)`, once per atom read. Fix: an indexed state (statement change
   across Pred: the keystones are stated over `State.get`, which keeps its meaning).
   Owner: open.
5. **Directory and history lists walked per turn** (VERIFIED, S): `clockOf` is
   `history.length` per `loadDeploymentFrom`; `Loaded` extends `image.accepted` with
   `++ [record]` and reads `accepted.length` about ten times per `extend` while
   `rootLog.size` already holds the height. O(history) each, small per call, growing
   with Store age. Owner: open.
6. **Durable index row keys re-packed per row read** (VERIFIED, S).
   `Compiler/DurableIndex.lean` `packBits` does `(bits.drop (8*i)).take 8` per byte
   (O(len^2)), and `rowKey` runs on every row read of every trie walk (per append and per
   keyed query). Fix: structural chunking, or key the fetched-row map by the bit path.
   Owner: open.
7. **Whole world-root rebuild on past-height reads and checkpoint open** (VERIFIED, S).
   `Kernel/WorldRoot.lean` `deployedRoot` rebuilds the trie (`AuthTrieCache.canon` is
   O(n^2): `dropKey e.1 L ++ [e]` per entry) where `Loaded.roots` (a `RootCache`) exists.
   Owner: open.
8. **Leaf tag codecs not cursor-native** (UNVERIFIED, reader confidence high): one
   non-native leaf makes a whole record stream fall back to `bytes.data.toList` and a list
   decode (quadratic inside a repetition). Owner: perf-codec-writer (next task).
9. **Lean host helper spawns** (see 3) and **the rest of the Rust list the perf-rust lane
   judged real but left**: birth-evidence verdict cache in grain-runtime (needs keys over the
   family config, journal ordinals and sibling records; call.bin/outcome.bin digests are
   cached now); host reply parsed twice and serialized 2-3 times in the v3 path (parked under
   R7); `Sessions::who` connect per request (mini-web to the spawn helper);
   spk-browser-proxy one request per TLS connection with a thread per connection;
   `rpc_adapter` 10 ms cancellation polls. Owner: open.
10. **Build time, from the claudesplosion scavenge** (lane/scavenge 6fbe66252,
    docs/SCAVENGE-CLAUDESPLOSION-2026-10-28.md; not verified here): the durable twin
    (Kernel/DurableCommitProtocol, DurableReceiver, DurableWalHandler, FramedWalRefinement,
    GuardedDurableCommit, about 2,800 lines) duplicates the World.step path; the frame bound
    `frameBytesMax` is hand-copied in 39 files; cold audit time reported superlinear in
    Store size (372 s at N records, 1272 s at 2N; read docs/audit-phase-timing.md first).
    Owner: open.

## Reader claims checked and found false

- batch-020 #2, `ApplicationDispatchAdmissionIngress.event` "encodes the ingress twice":
  the emitted C calls `Ingress.canonicalBytes` once (CSE).
- batch-011 #3, `spentOf` "linear scan of the spent list": `consumed` is the Engine's
  `Std.HashSet`.
- batch-038/048, "four `verify_running_instance` per request": two call sites on the
  dispatch path; the two `systemctl` spawns per call were the real waste (fixed).
- batch-040, "`tool_until` verifies the host image twice": the second call is a stat and
  fstat returning the descriptor the helper executes; kept.

## Reader findings not yet verified (generated from 126 of 174 shards)

Each line: shard, the reader's title, where, and the reader's confidence. Duplicates of the
items above are left in; a reader item is a lead, not a fact, until it moves up.


### Per turn / per submit (240)

| shard | finding | where | conf |
|---|---|---|---|
| 000 | rootBytes decodes to a Store, then re-derives and re-sorts the same entries to root it | Compiler/StoreCodec.lean:812 (`rootBytes`), via `saltedRoot` (:799) → `leaves` (:788) → `… | high |
| 000 | `opening` encodes every entry twice and re-derives the blinding key per leaf | Compiler/StoreCodec.lean:784 (`opening`), called per entry from `leaves` (:788) | high |
| 000 | The whole wire is `List UInt8`; every frame/preimage is rebuilt by `++` and `flatten` | Compiler/StoreCodec.lean:598 (`encode`: `frame W ++ payload`), :793 (`rootOfLeaves`: `fra… | high (m… |
| 000 | `frame W` re-hashes the layout descriptor (a Keccak/cSHAKE permutation) on every evaluation | Compiler/StoreCodec.lean:281 (`frame` = `magic ++ storeVersion :: layoutDigest W`), :264 … | high (m… |
| 000 | `nibble` rebuilds the hex alphabet per nibble in every inspection file | Host/ApplicationDispatchInspection.lean:24, Host/ApplicationDispatchAgentInspection.lean:… | high |
| 005 | `shareIssuePlanJson` renders signing slots two and three times | Host/Json.lean:4065–4104 (`shareIssuePlanJson`), 4055 (`planJson`), 3594 (`signedHeaderJs… | high |
| 006 | 5. law-sat certificate recomputes the leaf walk and DNF per constraint | Host/LawSatWire.lean:108–112 (`sources`), :146–148 (`conJson`, calls `sources` per constr… | high |
| 006 | 9. `fnAgentAtext` scans a 19-element list per byte | Host/Main.lean:3387–3392 (`fnAgentAtext`), called per byte via `fnAgentDotAtom` :3394–339… | high (c… |
| 011 | 3. Replay check `spentOf` builds nullifier bytes then linearly scans the entire spent list | Compiler/CredentialAuthorityDomainReceiver.lean:109–111 (`spentOf`), 147 (`spentExact`), … | high |
| 011 | 5. `foldSemantics`/`persistedSchemaRefs`/`StoreEpoch.current`: the whole codec corpus is rebuilt and SHAKE-ha… | Compiler/DurableCheckpointCodec.lean:182–189 (`persistedCellDescriptors`: `(List.range 25… | high on… |
| 011 | 8. Nullary frame/tag/customization defs re-run `.toUTF8.toList` (and `MacKey.id` re-hashes) on every reference | Compiler/ApplicationReceivingDomain.lean:14–78 (all 14 frame/contract defs, `receivingCon… | high |
| 012 | Trie row reads re-derive `rowKey` (with quadratic `packBits`) on every row access | Compiler/DurableIndex.lean:369–376 (`packBits`, `rowKey`); hit from `walk` (380), `siblin… | high |
| 012 | `IndexRows.insert`/`setAll`: two full walks per key plus closure-layered `overlay` with linear scans | Compiler/DurableIndex.lean:675–691 (`insert`), 480–519 (`set`, `setAll`, `overlay`) | high |
| 012 | `extendFrom` hashes the new suffix three times | caller site Compiler/DurableReceiverIO.lean:430–439 (uses shard defs `chainAfter`/`chainP… | high |
| 015 | `worldRoot`/`logRoot`/`worldEntries` rebuild the whole world from the image on every call | Compiler/NativeHostCodec.lean:56–93 (`logRoot0`, `logRoot`, `height`, `worldEntries`, `wo… | high |
| 015 | `NockProgramCodec.programId` re-encodes the entire program record (up to 4 MiB jam) on every load | Compiler/NockProgramCodec.lean:365–366 (`programId`), with `physicalId` at 369–371 | high |
| 017 | `DirectoryImage.ofRows`: runtime directory is an association list — every slot query is an O(n) `List.lookup` | Compiler/ResourceBirthCodec.lean:631–634 (`DirectoryImage.ofRows`, `slots id := Lifecycle… | high |
| 017 | `Directory.insert`/`retire` stack `Function.update` closure layers — slot lookups walk the whole history | Theory/CellSlot.lean:344–369 (`Directory.insert`, `Directory.retire`) — confirmed while t… | high (m… |
| 018 | `Descriptor.identity` runs inside `wire`: a full cSHAKE plus a 256-bit Nat→decimal String on every StoreCodec… | Compiler/WorldKindDescriptor.lean:160 (`Descriptor.identity`), :197–198 (`wire`, `name :=… | high |
| 018 | Enum/tag `StreamCodec`s leave `cursorNative := false`, so every record decode falls back to converting the wh… | Compiler/Tower256ConcreteBackend.lean:1505 (`drawRoleStream`), :1515 (`columnRoleStream`)… | high |
| 020 | 1. `refusalAtTip?` re-derives the full dispatch command (and re-hashes the whole HTTP body) once per history … | Kernel/ApplicationDispatchReceiver.lean:205–208 (`refusalAtTip?`; mirrored in the `Refusa… | high |
| 020 | 3. `requestDigest` of the same immutable request is recomputed at every command site in one submit | Kernel/ApplicationDispatchCommand.lean:89–93 (`command`, `nonce := (requestDigest ingress… | high |
| 020 | 4. `prepareObservationSlot` rebuilds the dispatch command twice per slot — 8 full-body re-hashes per authoring | Kernel/ApplicationDispatchAuthoring.lean:131–147 (`prepareObservationSlot`), called 4× at… | high (p… |
| 020 | 5. `charge` re-encodes the whole ingress just to take `.length`, on every tariff-dimension query | Kernel/ApplicationDispatchPending.lean:98–108 (`charge`, the known-bug def — new angle on… | high |
| 020 | 6. The same ingress bytes are decoded twice and the signed command decoded twice per submit | Kernel/ApplicationDispatchReceiver.lean:346 (`codec.decode bytes`) and :350 (`Application… | high |
| 020 | 8. `prepareForIssue` encodes the full command twice for the self-check | Kernel/ApplicationDispatchAuthoring.lean:259–263 (`prepareForIssue`) | high |
| 020 | 11. `Manifest.valid` runs an O(n²) Nodup on every `matchesDispatch`, re-validating a manifest already validat… | Kernel/ApplicationDispatchManifest.lean:109–111 (`Manifest.valid`: `(manifest.interfaces.… | high |
| 020 | 12. `decodeInstalled` re-hashes the atom id and walks the DFinsupp Store on every ticket/manifest read | Kernel/ApplicationDispatchAuthority.lean:160–171 (`ticketAtom`, `decodeInstalled`), Kerne… | high on… |
| 021 | Per-turn identity/replay checks linearly scan the entire accepted history | `lookupVerified` (ApplicationGrainSessionEnrollmentReceiver.lean:34), and the `old.opened… | high |
| 021 | Canonical bytes re-encoded from scratch on every use; `event` encodes twice per call; charge closures re-enco… | `Ingress.canonicalBytes` is a *def*, not a field, in all the shard's Source modules — App… | high |
| 022 | Carried dispatch/enrollment receivers re-derive the whole intent at every `.intent` access | Kernel/CarriedApplicationDispatchReceiver.lean:248 (`receiveAdmitted`, `admitted.intent.t… | high |
| 022 | Same ingress bytes fully decoded and canonically re-encoded ~5× per dispatch submit | Kernel/CarriedApplicationDispatchReceiver.lean:30–32 (`lookupVerified`: `codec.decode` + … | high |
| 022 | `lookupVerified` and `receiveAdmitted` each linear-scan the entire accepted history per request | Kernel/CarriedApplicationDispatchReceiver.lean:42–45 (`lookupVerified`: `image.accepted.f… | high |
| 022 | `DeployedCharge.storageAt` computes `deltas` twice | Kernel/DeployedCharge.lean:63–66 — `(deltas bridge.codec cells writes)` appears in both `… | high |
| 023 | `Image.append` copies the whole log per accepted turn | Kernel/DurableReceiver.lean:200-202 (`Image.append`: `accepted := image.accepted ++ [reco… | high |
| 024 | Durable snapshot state is layered closures + a linear journal; every turn walks it dozens of times | Kernel/DurableCommitProtocol.lean:163 (`Snapshot.lookupRecorded`), :184 (`Snapshot.instal… | high (r… |
| 024 | Law/step context recomputed ~5× inside `authorize` (`(step prepared)` written out four times) | Kernel/FleetTurn.lean:565–569 (`authorize`) and Kernel/JobMoneyReceiver.lean:702–706 (`au… | high |
| 024 | `Pred.State` is a `List (String × Int)` with linear name lookup, and `project` widens it to one slot per comm… | Pred/Core.lean:92–99 (`State.get` = `slots.find?`); fed by Kernel/FleetTurn.lean:509 (`by… | high on… |
| 024 | Policy-graph resolution re-run 3–4× per turn (`effectLaw`/`lawReadGuards`/`policyConfig` not shared) | Kernel/JobMoneyReceiver.lean:642 (`effectLaw` → `PhysicalLawResolution.loadTarget`, a ful… | high |
| 024 | Fleet/JobMoney request web: `marker`, `commandCodec.encode`, `request` re-derived at every call site (~12–15 … | Kernel/FleetTurn.lean:209 (`marker`), :254 (`effectDigest`), :266 (`context` calls `marke… | high |
| 024 | `Charge := Lane → Nat`: every lane projection re-encodes the ingress / re-derives writes / re-hashes the event | Theory/ResourceCost.lean:92 (`abbrev Charge := Lane -> Nat`); Kernel/JobMoneyReceiver.lea… | high |
| 024 | `event` / `transactionId` / `nullifier` recomputed 3–4× per Fleet/JobMoney turn | Kernel/FleetTurnReceiver.lean:43–58 (`transactionId`, `eventId`, `event`, `nullifier` all… | high |
| 024 | `readGuards` filter recomputes `writes`/`sourceGuards` per guard element | Kernel/FleetTurnReceiver.lean:81–84 (`(writes prepared)` inside the `filter` lambda), Ker… | high |
| 027 | validateChecks re-hashes the entire genesis seed twice per validation | Kernel/NativeHostContext.lean:517 (`seedIdentity seed == config.expectedSeed`) and :525 (… | high |
| 027 | validateCore runs the cell-law check twice per validation | Kernel/NativeHostContext.lean:544–555 (`validateCore`): `directory?.map lawfulCheck` is p… | high |
| 027 | GrainBirth prepareLoaded re-derives grainCommand (descriptor encode + SHAKE) ~6× per birth | Kernel/NativeHostGrainBirth.lean:55 and :75 (`useMarker` twice), :80 (`.targets.length`),… | high |
| 028 | groundAt re-validates the same opened ground per historical arm — each validation replays the post-checkpoint… | Kernel/NativeHostReplay.lean:558 (`groundAt`); call sites 2207 (`admitClaimAt`), 2249 (`a… | high |
| 028 | Record identity proven by double full canonical encode at ~20 sites | Kernel/NativeHostReplay.lean:570 (`recordPresent`), 598 (`selectCreatedAt`), 624 (`select… | high |
| 028 | dispatchPurseUntouched scans the whole post-reserve suffix, allocating a mapped list per record | Kernel/NativeHostReplay.lean:201–209 (`dispatchPurseUntouched` + its `Decidable` instance… | high |
| 028 | priorIssueFor matches dispatch to its ticket by full byte-list equality in a linear scan | Kernel/NativeHostReplay.lean:1888–1894 (`priorIssueFor`), called at 2036 (`admitDispatchA… | high |
| 028 | accepted[index]? random access and drop on a List all along the historical path | Kernel/NativeHostReplay.lean:1965, 2000, 2038, 2068, 2080, 2126, 2138, 2150, 2197, 2239, … | high |
| 029 | `Session.rememberReadback` guard encodes the whole history twice per submit | Kernel/NativeHostSession.lean:83 (`Session.rememberReadback`, `if session.durable.image =… | high |
| 029 | `recordMatches` re-derives and re-encodes the expected record for every replayed entry | Kernel/NativeHostReplay.lean:2939–2941 (`recordMatches`), called per record at `walk` 369… | high |
| 029 | `derive`'s ~35-decoder linear chain runs per admission and per replayed record | Kernel/NativeHostReplay.lean:2552–2935 (the `derive` ingress dispatch) | high th… |
| 029 | `accepted.length` (and `Loaded.height`) is an O(history) list traversal evaluated per step | Compiler/DurableReceiverCore.lean:1093 (`Loaded.height := image.accepted.length`); in thi… | high (m… |
| 030 | `intentOf` re-derives `posts.map (Post.write rootBytes)` ~4× and `readOnly` re-maps per guard — each element … | Kernel/ObjectiveActivityWire.lean:238 (`readOnly`), :258–264 (`intentOf`); Kernel/Objecti… | high |
| 030 | The intent (and its seal) is computed twice per turn: once for the `PhysicalShape` decision, once for the dur… | Kernel/ObjectiveActivityReceiverCore.lean:2369–2367 (`physicalShapeDecidable`/`PhysicalSh… | high |
| 030 | `marker`, `effectDigest` and the full command encoding are recomputed ~10× per turn instead of once | Kernel/ObjectiveActivityReceiverCore.lean:455 (`marker`), :708–727 (`contextAt`: `cost :=… | high |
| 030 | `DecodedIngress.bytes` re-encodes the whole ingress ~5× per accepted turn; `event` alone encodes it twice wit… | Kernel/ObjectiveActivityReceiverCore.lean:452 (`DecodedIngress.bytes` = `ingressCodec.enc… | high |
| 030 | Payloads are decoded and canonically re-encoded repeatedly per turn (`decodeDataBytes` ×~4, artifact re-decod… | Kernel/ObjectiveActivityWire.lean:199–202 (`decodeDataBytes` decodes tokens then re-encod… | high |
| 030 | `prepare`'s stale-outcome path computes `outcomeDigest final.1` twice | Kernel/ObjectiveActivityReceiverCore.lean:925–928 (`prepare`) | high |
| 032 | Accessor defs rebuild `request`, `declaration` and `step` from scratch at every use site | PayEnrolV2Receiver.lean:318 (`Planned.declaration`), :336 (`project`), :355 (`step`), :36… | high |
| 032 | `writes` recomputed at every use — each recomputation re-encodes entire cells | PayClaimReceiver.lean:324 (`writes`), :327 (`readGuards`), :396 (`charge`), :407 (`intent… | high |
| 033 | PayObservationReceiver rebuilds `request` (and `marker`, `effectDigest`, `declaration`, `context`) at every u… | Kernel/PayObservationReceiver.lean:222 `request`, :201 `context`, :188 `effectDigest`, :1… | high |
| 033 | `step`/`project` re-encodes command bytes and grant slots on every call, and `step` is evaluated 3–5× per adm… | Kernel/PayObservationReceiver.lean:455 `project` (:466 `DeclaredResourceController.bytesS… | high |
| 033 | `writes`/`platformPost`/`authorityPost` re-apply validated patches; `PhysicalShape` decidability re-runs them… | Kernel/PlatformInstallReceiver.lean:500 `Prepared.platformPost` (`prepared.candidate.vali… | high |
| 033 | `loadDeployment` decodes the whole authority cell 2–3× per report; the reuse path `loadDeploymentFrom` exists… | Kernel/PayObservationReceiver.lean:493 (`claims`), :326 (`planReport`), :883 (`signingHea… | high |
| 033 | `context.cost` / `request.cost` encode the whole payload just to take its length | Kernel/PayObservationReceiver.lean:217 and Kernel/PlatformInstallReceiver.lean:398 (`cost… | high |
| 034 | 1. Every written cell's law is fully resolved (graph load + compile) 2–5× per turn, with zero sharing | Kernel/ReceivingLaw.lean:179–187 (`judgeBearing`), 234–246 (`writeGuards`/`lawGuards`), 7… | high (d… |
| 034 | 2. `lawFault` recomputes `authorizerSteps` inside the per-write lambda — O(n²) with two full cell-image decod… | Kernel/ReceivingLaw.lean:226–229 (`lawFault`), 211–223 (`authorizes`, `authorizerSteps`),… | high |
| 034 | 3. The bespoke receivers' `PhysicalShape` decidability instance re-derives the whole physical picture per con… | Kernel/PurseRefillReceiver.lean:686–717 (`PhysicalShape`, `physicalShapeDecidable`, evalu… | high |
| 034 | 4. `Laws.physical.resolve`/`resolveBirth` re-decode the directory and authority cell on every call | Kernel/ReceivingLaw.lean:725–749 (`Laws.physical`), 612–621 (`physicalKind` fallback); ca… | high |
| 034 | 5. `authorize` calls `(step prepared)` four times; `request` recomputed 3–4× per turn | Kernel/PurseRefillReceiver.lean:554–576 (`authorize`; `(step prepared)` at 566–571 ×4), 5… | high |
| 034 | 6. `Pred.State` is a `List (String × Int)`; every law-atom read is a linear scan with string equality | Pred/Core.lean:88–99 (`State`, `State.get` = `slots.find? (p.1 == k)`); hit from this sha… | high (r… |
| 034 | 7. `canonicalBytes` is a closure chain one layer per committed turn; this shard's code re-walks it many times… | consumed in-shard at Kernel/ReceivingLaw.lean:626 (`physicalBirth`), 731/741 (`resolveBir… | high (m… |
| 034 | 8. Turn identity recomputed: `marker`/`event`/`nullifier`/`ingress.bytes` evaluated 2–4× per turn | Kernel/PurseRefillReceiver.lean:795–805 (`replay`: `transactionId` at 798 and again in th… | high |
| 034 | 9. `Kernel.Receiving.Family.charge` re-runs the guard walk and re-derives claims per admission | Kernel/Receiving.lean:276–290 (`Family.charge`: `.memoryTouches` re-derives `readGuards l… | high (d… |
| 035 | Seat kernel decision runs twice per seat turn (plan op + submit op), and `invoke` re-runs the contract method… | Kernel/NativeHost.lean:2715 (`seatPlanLoaded` → `SeatReceiver.signingHeader`), Kernel/Nat… | high |
| 035 | `DataSnapshot.install` layers `canonicalBytes` as a closure per accepted turn — every cell read degrades with… | Kernel/DurableDataIntent.lean:270–271 (`install`: `canonicalBytes := fun cellId => (looku… | high (m… |
| 035 | `DecodedIngress.bytes` re-encodes the whole signed ingress on every access (both seat and birth receivers) | Kernel/SeatReceiverCore.lean:189–190 (`DecodedIngress.bytes := ingressCodec.encode ingres… | high |
| 035 | `finish` computes `statePosts` (and `bookPost`) twice per decided turn | Kernel/SeatStore.lean:846–849 (`finish`): the same expression `extra ++ statePosts config… | high |
| 035 | Money `positionSlots` re-applies the operation prefix per position (O(n²) book application) | Kernel/ResourceMoneyReceiver.lean:153–169 (`Prepared.positionSlots`: `let before := apply… | high |
| 036 | `turnOf` re-derives the full delta list five times; `ofCells` makes it six — every written cell is decoded 12… | Kernel/TurnOfIntent.lean:765–777 (`turnOf`), with `createsOf` :740, `retiresOf` :745, `le… | high |
| 036 | `legPatch` (two `sortedSupport` enumerations + two cover passes + a `decide`d `ValidFrom` walk) is derived 3×… | Kernel/TurnOfIntent.lean:443 (`Codec.legPatch`), `cover` :421, `Delta.patchOk` :670–675, … | high |
| 036 | `chargeOf` returns a closure that recomputes `storageOf` on every lane query; the storage sum is computed ≥5×… | Kernel/TurnOfIntent.lean:734–737 (`chargeOf`), `storageOf` :728–731, closure queried from… | high |
| 036 | `cellsOf`/`retired` closures re-decode the pre-state on every query — `ofCells` multiplies any per-query cost… | Kernel/SnapRepresents.lean:53–54 (`cellsOf`), Kernel/HostRefinesWorldCore.lean:416–418 (`… | high |
| 036 | `diff` traverses the cover twice with duplicated Store lookups | Kernel/TurnOfIntent.lean:198–199 (`diff`), `guardOp` :181, `changeOp` :188 | high |
| 036 | `guardIds` recomputes `writeIds ws` once per guard | Kernel/TurnOfIntent.lean:723–724 (`guardIds`) | high |
| 038 | Per-hash-call recomputation of customization strings and `emptyDigest` | Kernel/WorldRoot.lean:463 (`worldCustomization := …toUTF8.toList`), 466 (`deployedHash` r… | high (m… |
| 040 | Committed-frame equality done by hex-encoding the whole frame | `match_committed_inspection` (agent_api_lifetime_v3.rs:499–500: `field(inspected, "frameH… | high |
| 040 | Full hex decode just to test emptiness | `match_committed_inspection` (agent_api_lifetime_v3.rs:485–487: `decode_hex(canonical_htt… | high |
| 041 | `verify_running_instance` runs 3× per dispatch; each call spawns `systemctl --user show` twice | agent_api_server.rs:573 (`handle_once` → `binding()`), agent_api_server.rs:691 (`dispatch… | high |
| 041 | `source_request` deep-clones the entire Dispatch request though it is field-for-field identical | agent_api_server.rs:650–669 (`dispatch_once`). | high |
| 041 | Reply JSON-serialized twice per request | agent_api_server.rs:1137 (`http_reply` does `serde_json::to_vec(&response)?` only to boun… | high |
| 041 | Minor: hex body decode goes through `u8::from_str_radix` per byte-pair | agent_api_server.rs:605–614 (`dispatch_once` body decode; same pattern in `unhex32` at 13… | high |
| 042 | `app_units_active` spawns one `systemctl` process per installed generation, per call — and is called in per-v… | native/spk-host/src/broker.rs:836 (`app_units_active`), spawn at broker.rs:847 via `activ… | high |
| 055 | Per-request identity comparison allocates decimal strings | rpc_adapter.rs:866 (`dispatch_cancellable`) and rpc_adapter.rs:929 (`open_web_socket_fenc… | high |
| 058 | Host reply JSON is fully parsed twice (and re-parsed a third time by callers) | `application_api_tools.rs:1749–1759` (`exchange_once_guarded`) | high |
| 061 | `prepare_resident` chains ~10–16 sequential `mini` subprocess spawns per resident prompt | hermes_room.rs:510–565 (`prepare_resident`); resident_context.rs:17–47 (`collect`); calle… | high |
| 062 | History compaction re-parses all room-operations + HOME/requests JSON every prompt, forever | native/grain-runtime/src/history_compaction.rs:64-80 (`referenced_attempts`), called from… | high |
| 062 | Journal save path: full-journal pretty re-serialize + double fsync + /dev/urandom open per save | native/grain-runtime/src/journal_io.rs:20-51 (`write_before_publish`); reached via `Runti… | high fo… |
| 063 | `hermes_state_fingerprint` re-hashes the whole Hermes SQLite store + WAL several times per turn | native/grain-runtime/src/main.rs:2853 (`hermes_state_fingerprint`) — reads and SHA-256s `… | high (c… |
| 064 | Redundant host-turn subprocess re-probes: same custody evidence re-verified via fresh `mini` spawns in every … | `verified_dispatch_reserve_hold` (main.rs:3920–3927 lifetime, 4027–4034 v2) spawning `min… | high |
| 064 | Custody evidence files re-read and re-hashed from disk repeatedly, including twice back-to-back in one call | `verified_dispatch_settlement` (main.rs:3786–3813) calling `dispatch_settlement_record` (… | high |
| 067 | Worker stop: fixed 50 ms poll ladder + systemd subprocess per iteration, every turn end | `stop_and_reap_owned` 13653–13661 (SIGKILL → poll `group_has_live_member` every 50 ms, up… | high. |
| 067 | `acp_response` allocates a `json!` value per ACP message just to compare ids | main.rs:15441 `if msg.get("id") == Some(&json!(id))` — inside the per-message loop. | high (c… |
| 071 | Continuity descriptor re-reads and re-hashes the whole reserve + fence evidence on every provider settle | native/grain-runtime/src/provider_history.rs:406 (`provider_continuity_value`), with `pro… | high |
| 072 | `inspect_quiescence_locked` re-collects all fresh evidence per call — and runs up to 2× per resident turn | native/grain-runtime/src/quiescence.rs:620–683 (`inspect_quiescence_locked`), 534–539 (`q… | high (d… |
| 072 | Small: `ResidentGuard` re-reads resident custody several times per flow | native/grain-runtime/src/quiescence.rs:442–445 (`acquire`: resident.json + custody snapsh… | high (w… |
| 073 | checked_operator hashes the entire host binary on every prompt admission | native/grain-runtime/src/resident_preflight.rs:24 (`checked_operator`, via `require_priva… | high |
| 075 | `resolve_with` reads and hashes the pinned call and ingress files twice each | native/grain-runtime/src/shared_app_refs.rs:315 and 419 (`hash_bounded_file` on the birth… | high on… |
| 075 | `validate_selected` deep-clones all four signed read views purely to validate them | native/grain-runtime/src/shared_app_refs.rs:515 (`read_result(view.clone(), target)?` in … | high |
| 076 | `flattenAlg` rebuilds the whole gate list at every internal node (quadratic flatten) | Compiler/AirFlatten.lean:149–160 (`flattenAlg`, consumed by `flatten`/`flattenSystem`) | high (m… |
| 076 | `TranscriptState` copies its provenance lists on every absorb/draw, and nothing consumes them | Compiler/AuthenticatedColumnPlan.lean:386–400 (`TranscriptState.absorb` `state.frames ++ … | high (d… |
| 077 | Policy overlay `fetch` re-digests every record on every fetch | Compiler/CandidateLawResolution.lean:23 (`overlay`) and :45 (`overlayRecords`) | high |
| 077 | `fetchPolicySource` decodes, digests, then re-encodes the same record per call — and is the `fetch` of a doze… | Compiler/CanonicalCellRegistry.lean:1122–1136 (`loadPolicySource`, `fetchPolicySource`), … | high |
| 078 | `closureDigest` recomputed 2–3× per admission even on the prepared path; insertion-sort inside | Compiler/ComposedPolicyAdmission.lean:44–52 (`closureDigest`), computed at :207 (`Prepare… | high |
| 078 | `Snapshot.spent` is a `Nat → Bool` closure over an all-history list — O(history) per nullifier check, layered… | field declared in Compiler/CredentialAuthorityDomain.lean:87 (`Snapshot.spent : Nat → Boo… | high (r… |
| 078 | `loadPolicy` re-encodes and re-hashes canonical bytes it already has | Compiler/CredentialAuthorityPolicyRegistry.lean:84–85 (`policyRecordDigest` = `policyHash… | high |
| 079 | Every signed request verifies the same Ed25519 signature twice in two separate native calls | Compiler/CredentialSignatureAdmission.lean:330–346 (`verifyNative`, `config.check` at :33… | high |
| 079 | `Machine.admit` cues the whole program jam twice, then jams it once more | Compiler/Evaluator.lean:592–603 (`Machine.admit`); Theory/Noun.lean:1338 (`canonical bs :… | high |
| 079 | `resolve` re-hashes the registry entry's id on every call | Compiler/Evaluator.lean:519–522 (`resolve`, `E.id` inside `registry.find?`); `Evaluator.i… | high (c… |
| 080 | `migrate` builds the new store by N closure-layered `set`s with O(n²) id-list assembly | Compiler/LegacyContentCarry.lean:495–498 (`allocate`), :517–529 (`preserveUnchanged`), :5… | high on… |
| 080 | `digitsBytes`'s `chunk` is string-parsed three times per recursion level (known item — new angle) | Compiler/NatDigits255Fast.lean:43 (`chunk := 70110209207109375`), :134–137 (`digitsBytes`… | high |
| 083 | The policy-law stack re-loads every policy record ~3× and the whole graph 2–3× per law-bearing write | Compiler/PolicyComponentResolution.lean:113 (`loadNode`), :130–144 (`collect`), :95 (`loa… | high |
| 083 | `loadGuards` re-fetches every history address the graph load already fetched | Compiler/PhysicalLawResolution.lean:48 (`loadGuards`), :43 (`addresses`), :62 (`loadRoots… | high |
| 083 | Zero-argument `codecId`/`schema`/`identity`/`physicalId` defs re-run CShake256 on every evaluation | Compiler/ObjectiveBendPlanAdapter.lean:22 (`codecId`), Compiler/ObjectiveBendResultAdapte… | high |
| 084 | `stepAsg` re-reads the state linearly and re-hashes per wire reference during the per-turn `systemAccepts` | Compiler/PredCompile.lean:165–193 (`valOf`, `presOf`, `digestOf`, `openedOf`, `stepAsg`);… | high |
| 084 | `castInjOn`'s runtime decision is O(d²) pairwise field-equality, and it runs twice per turn | Compiler/PredCompile.lean:276–293 (`castInjOnDecidableSpec`, `castInjOnDecidableFast`, th… | high |
| 084 | `lower` runs the whole lowering fold twice | Compiler/PredCompile.lean:650–651 (`lower`) | high |
| 084 | The same `inputsInRange` verdict is recomputed up to three times per turn per law | def at Compiler/PredCompile.lean:107–140 (`inputsInRange`); call sites Kernel/FleetTurn.l… | high |
| 084 | `intsOf` re-derives cSHAKE digests every time it is built | Compiler/PredCompile.lean:707–727 (`digests`, `digestsL`, `intsOf`) | high |
| 084 | Witness generator `wit`/`witL` recomputes per aux query | Compiler/PredCompile.lean:737–780 (`wit`, `witL`) and `orderAux` at 498–503 | high |
| 085 | Per-byte String slot projection in `bytesSlots`/`grantSlots` feeds a linear string-scan State | Compiler/ResourceAuthorityProjection.lean:43 (`bytesSlots`), :54 (`grantSlots`) | high |
| 085 | `ResolvedLawCompilation.predicate` re-derives the whole effective law at every use site | Compiler/ResolvedLawCompilation.lean:41 (`predicate`) — `effective (canonicalOrder resolv… | high |
| 086 | `checkpointMac`: two literals re-encoded and a full KMAC seam conversion per checkpoint write | Compiler/DurableCheckpointCodec.lean:766–770 (`checkpointMac`); shard seam Compiler/Sp800… | high |
| 088 | Lifecycle `exactCharge` closures re-encode the whole ingress on every lane query | Kernel/ApplicationLifecycleBeginV2Admission.lean:102–118 (`Accepted.intent`), Kernel/Appl… | high |
| 088 | One intent → turn derivation runs the write-list delta pass ~5× and `storageOf` ~3× | Kernel/TurnOfIntent.lean:765–777 (`turnOf`), 787–804 (`ofCells`), 728–737 (`storageOf`/`c… | high |
| 090 | Charge re-encodes the whole ingress on every lane query | Kernel/ApplicationLifecycleRetryCompletionV4Core.lean:93-107 (`charge`); root cause Kerne… | high |
| 090 | `linkedCurrentPolicies` loads each policy twice; every load hashes the policy record | Kernel/ApplicationLifecycleRetryCompletionV4Admission.lean:147-173 (`linkedCurrentPolicie… | high |
| 090 | `checkPackage` encodes two whole cells to compare them | Kernel/ApplicationLifecycleRetryCompletionV4Admission.lean:265-268 (`checkPackage`: `cell… | high (r… |
| 091 | SPK launch descriptor: whole-descriptor `List UInt8` encode computed 2–3× per admission, once just for a leng… | Kernel/ApplicationSpkLaunchDescriptor.lean:124–126 (`Descriptor.canonicalBytes`), :138–14… | high |
| 095 | `writes prepared` and `lawSourceGuards prepared` recomputed per element inside filters | Kernel/DeclaredResourceController.lean:1603 (`readGuards`), :1714 (`admissionGuards`), :2… | high |
| 095 | `DeclaredResourceProjection.values` enumerates the whole cell store twice per scalar projection | Kernel/DeclaredResourceProjection.lean:26 (`values`), :47 (`project`), :37 (`scalarSlots`… | high |
| 095 | `readPreparation` re-encodes the command per read target, and `readPortal` re-runs the whole prepare | Kernel/DeclaredResourceController.lean:966 (`readPreparation`), :198 (`readRequest`), :10… | high on… |
| 095 | `operationMarker`/`transactionId` hashed ~5–6× per submit | Kernel/DeclaredResourceController.lean:172 (`operationMarker` in DeclaredResourceScalar),… | high |
| 096 | Door.peek / Door.stateNow decode the entire program jam per read request | Kernel/Door.lean:160 (`peek`), :171 (`stateNow`); reached from Host/Main.lean:8014–8015 (… | high (m… |
| 097 | The nonce/atom/marker family re-derives the same SHAKE hash 3–8× per call, re-encoding the preimage each time | Kernel/FnConsumerOperation.lean: `bindingCommand` (:462-488: `operationAtom` :471, `reply… | high |
| 097 | evaluate re-runs checkReport + checkGateway that evaluateVerified runs again | Kernel/FnConsumerOperation.lean:796-811 (`evaluate` :799-804) vs `evaluateVerified` :785-… | high |
| 097 | 2^32-range Nat literals and 2^259+ Nat.pow computed at runtime in hot validators and atom-id defs | `4294967295` in Kernel/FnConsumerFrontierCore.lean:189 (`checkAfter`), Kernel/FnConsumerO… | high |
| 097 | Legacy-shape probing decodes every incoming invoke twice on the receiver path | Kernel/NativeHost.lean:3249 calls `FnConsumerProgress.recognizedLegacyIntentAnyGateway?` … | high |
| 098 | FnSelectiveReleaseAdmission: command/event re-derived ~10× per admission, and admission reruns per historical… | Kernel/FnSelectiveReleaseAdmission.lean:118–134 (`policyConfigAt`), 136–147 (`capabilityA… | high |
| 098 | GenericSimplex list churn: O(n) appends to unbounded logs, linear viewAt/putView everywhere, isSafe range all… | Kernel/GenericSimplex.lean:122–125 (`broadcast`: `outbox ++ [m]`, `audit ++ [.send m]` — … | high (p… |
| 098 | Giant Nat nonce/atom arithmetic recomputed per call | Kernel/FnReplyConsumption.lean:178–191 (`resultAtom`/`inboxAtom`/`conflictAtom`/`resultNo… | high |
| 100 | `admits` builds the O(fields²) `view` twice per evaluation; `refusalPath` repeats the whole thing | Kernel/Job.lean:858-863 (`jview`, `admits`), :866-867 (`refusalPath`) | high |
| 100 | `transport.sourceGate` encodes two full intents to bytes to test equality | Kernel/JointControlBootstrap.lean:148-149 and Kernel/JointControlBootstrapBundle.lean:219… | high on… |
| 101 | Policy state is a per-byte String assoc list, doubled by `jointSlots`, scanned linearly per atom | Kernel/JointSlots.lean:49 (`jointSlots`), with Pred/Core.lean:98 (`State.get`) and Kernel… | high |
| 101 | LinkIndex: per-write updates rebuild the whole reverse assoc list; `ofRecords` re-decodes every write's full … | Kernel/LinkIndex.lean:476-484 (`setCell`), :463-470 (`dropPair`/`addUnique` — `TargetKey.… | high |
| 101 | `releaseAborted` re-encodes the whole candidate inside the filter closure | Kernel/JointReservation.lean:101-103 (`releaseAborted`) | high |
| 103 | `typedAt` is O(row × fields) with three list passes and an allocation per row field, per admitted write | Kernel/ObjectStateType.lean:368–378 (`typedAt`, `.field`/`.record` case); called from Ker… | high |
| 103 | Law views are rebuilt as fresh String-keyed assoc lists per judgment, and every law slot read is a linear Str… | Kernel/ObjectRecord.lean:393–427 (`slotsOf`/`fieldSlots`/`stateSlots`), 467–482 (`Facts.s… | high |
| 103 | `decodeEntry`/`effectWrite`: linear `find?` over ABI outputs with a fresh `toUTF8.toList` + `cordValue` per (… | Kernel/NockEntry.lean:92–95 (`decodeEntry`), 98–101 (`decodeWrites`), 265–275 (`effectWri… | high |
| 104 | 1. The new checkpoint is encoded and hashed ~3× per yield; the record fully re-encoded ~3× more | Kernel/ObjectiveActivity.lean:2277–2299 (`nextRecord`), 2303–2306 (`yieldReserve`), 2309–… | high |
| 104 | 2. `programEffects` re-loads the program and runs the checker ~3 extra times per turn, even when no effect is… | Kernel/ObjectiveActivity.lean:1598–1602 (`programEffects`), 1589–1594 (`effectProtocol`),… | high |
| 104 | 3. The same cells re-read and re-decoded 2× per turn (package cell ×2, slot cell ×2, record cell ×2) | Kernel/ObjectiveActivity.lean:3188+3192 (`resumeHead`: `packageBytes` twice — `frontEndPa… | high |
| 104 | 4. `Funds.book` re-applies the whole posting batch to the Book on every query; `settlePurse` applies it twice | Kernel/ObjectiveActivity.lean:2216–2221 (`transferVerdict` queries `funds.book written` t… | high |
| 104 | 6. Annotation closure re-derives `dataAnnotations` per lookup; `runMigration` builds the annotated term twice | Kernel/ObjectiveActivity.lean:1419–1424 (`instantiate`), 2592–2600 (`Migration.applied`),… | high |
| 105 | `programEffects` re-runs the full front-end replay + checker on every delivery/birth turn | `deliveryFunds` (Kernel/ObjectiveActivity.lean:3141-3145) calls `programEffects` (:1598-1… | high. |
| 105 | `Funds.book` is an uncached closure: whole-Book re-applied twice per transfer verdict | `deliveryFunds` at :3144 — `fun written => applyOperations book (purseCharges ...)`; cons… | high on… |
| 105 | `deliver` encodes the next record twice: once for the deposit's length, once for its post image | `deliver` :3391-3392 (`settlePurse ... (storageDeposit config next) ...`) and :3402 (`rec… | high. |
| 105 | `resumeHead` derives `packageBytes` twice per deliver/exhaust turn | `resumeHead` :3188-3192 — `frontEndPaid config (packageBytes config snapshot record.pin) … | high. |
| 105 | Cell coordinates re-hash per derivation, and `spec`'s customization strings re-encode per use | `ProtectedCell.coordinate` (Kernel/ProtectedCell.lean:94-97) runs `Sp800185Cshake256.hash… | high th… |
| 106 | 7. Byte-counting by materializing bytes: `usage`'s witnessBytes and `authorize`'s capacity pre-check | Kernel/ObjectiveBendNativeAdmission.lean:301–303 (`usage` `.witnessBytes`: `(effects.map … | high on… |
| 106 | 8. Guard bookkeeping: O(guards×writes) filter with the write-cell map rebuilt per guard, plus O(n·m) membersh… | Kernel/DeclaredResourceController.lean:2098 and Host/ObjectiveInvocationQuote.lean:231 (`… | high. |
| 106 | 10. `ObjectiveBendPreparedOutput.usage` reads the executed state's heap size per query — fine, but `plan`/`us… | Kernel/ObjectiveBendPreparedOutput.lean:74–91 (`usage`, `plan` — pure projections off `Pr… | high (t… |
| 107 | `holdInbox` reads the cursor cell ~4× and the inbox cell 2× per send; `HeldInbox.cell` recomputes forever | Kernel/ObjectiveCall.lean:1324–1344 (`holdInbox`), :1252–1254 (`HeldInbox.cell`), used at… | high |
| 108 | judgeDomains re-reads and re-decodes every posted cell 3–4× per turn end | Kernel/ObjectiveDomain.lean:159–195 (`touched`, `writtenObjects`, `postedDomains`, `keeps… | high |
| 108 | Domain judgment scans `posts` linearly per lookup and re-decodes posted domains' cells in both judgeEach and … | Kernel/ObjectiveDomain.lean:124 (`firstAt` = `posts.find?`), 128–146 (`finalState`/`final… | high |
| 109 | Participant enrollment/provisioning re-derives `request`, `marker`, `step`/`project` ~5–8× per admit (the `ch… | Kernel/ParticipantKeyEnrollment.lean:447–468 (`authorize`), :398–410 (`project`, `step`),… | high |
| 110 | Raw memo parsed three times per submit (and three times per quote), each parse re-encoding for canonicity | Kernel/PayClaimDecision.lean:215, 218, 240 (`acceptRequest`) via Kernel/PayCell.lean:338 … | high |
| 110 | `existingCustody` recomputes the identity→subject cSHAKE hash that `resolveOwner` just computed | Kernel/PayClaimQuote.lean:295–306 (`existingCustody`) and Kernel/PayClaimDecision.lean:84… | high |
| 110 | `EconomicReady`/`OwnerReady` Decidable instances re-run the whole per-submit validation at runtime | Kernel/PayEnrolV2Legs.lean:132–144 `EconomicReady`, 163–171 `OwnerReady`; invoked at Kern… | high |
| 110 | `accept` re-runs `checkClaim` and `quoteFixed` that `acceptRequest` just ran | Kernel/PayEnrolClaim.lean:761–773 (`accept`: `checkClaim` at 768, `quoteClaim` → `quoteFi… | high |
| 110 | `acceptRequest` evaluates `claimConsumptionAt pay origin.id` twice with no sharing | Kernel/PayClaimDecision.lean:217 (`.isSome` gate) and 237 (passed into `PayEnrolClaim.acc… | high |
| 110 | `purchaseCustody` looks up `enrolmentAt`/`pendingOwnerAt`, then `resolveOwner` repeats both | Kernel/PayClaimQuote.lean:315–331 (`purchaseCustody`, lines 317–318) → 295–306 (`existing… | high |
| 111 | One memo is serialized ~8× per enrol submission | Kernel/PayEnrolV2Decision.lean:355 (`decide`: `o.memo ≠ .present (PayEnrolMemoV2.encode m… | high |
| 112 | ProtectedCell: `reservedBase := 2 ^ 256` recomputed per coordinate; bignum cell ids compared per write gate | Kernel/ProtectedCell.lean:91 (`reservedBase`), :94 (`coordinate`); consumer Kernel/SeatCe… | high (w… |
| 115 | 11. `streamSlots`/`contentContext` small re-scans | Kernel/ResourceTransaction.lean:1250–1260 (`streamSlots` byte-slots the whole topic per a… | high |
| 116 | `closeSeat` recomputes `closeBatch` twice; each `heldAssets` walks the whole Book's DFinsupp support and sort… | Kernel/Seat.lean:872–881 (`closeBatch`, `closeSeat`, `closeAll`); `heldAssets` at Kernel/… | high |
| 116 | `Book.balances`/`floors`/`leaseRecords` are `DFinsupp`: every lookup walks the whole posting history, every p… | Theory/CanonicalResourceKernel.lean:104–108 (`Book`), `Book.balance` 113–114, `Operation.… | high (r… |
| 116 | `safeAt` computes `view` twice, rebuilds `offerSafe`/`proposal.assets` per call, and `Pred` reads are list sc… | Kernel/Seat.lean:153–154 (`safeAt`), 150–151 (`view`), 133–134 (`Proposal.assets`, O(n²) … | high |
| 116 | `.reallocate` recomputes `openSeatsOf` per transfer and rescans seats per check | Kernel/Seat.lean:1002 (`transfers.find? (fun transfer => !addressed (openSeatsOf world in… | high |
| 116 | `LoadedBook.write` encodes the whole Book cell twice per paid write; `model.roots (bookId)` re-fetched at eve… | Kernel/RunComputeBudgetDomain.lean:73–79 (`LoadedBook.write`: `exactPost := bookRoot post… | high |
| 116 | `checkRun` re-decodes the program jam, params and every library jam on every checked run | Kernel/Run.lean:250–252 (`checkRun`: `M.decode program.jam`, `M.decodeParams program.para… | high |
| 116 | Run-path jams are `List UInt8` end to end (`RunClaim`, `Accepted`, `Machine` codec interface) | Kernel/Run.lean:73–75 (`RunClaim.sampleJam/outputJam`), 155–159 (`Accepted.output`), 283 … | high |
| 116 | `checkRun`'s write-set comparison is O(n·m) list membership | Kernel/Run.lean:260–261 (`writes.all (· ∈ decoded)`, `decoded.all (· ∈ writes)`) | high (l… |
| 116 | Invitation registry: linear scans and full-list rewrites per seat action | Kernel/Invitation.lean:87–95 (`Registry.instance?`/`invitation?` find?, `fresh` = find? +… | high |
| 118 | `HashBytes.ofBE` is a 32-step bignum foldl with no fast path (the fast pattern already exists in-repo) | Theory/HashBytes.lean:46 (`ofBE`) | high |
| 119 | Patch is interpreted twice per leg: `firstDisabled?` walks it, then `Patch.run` walks it again | Theory/Store.lean:321–325 (`Patch.firstDisabled?`) with Theory/Store.lean:295–297 (`Patch… | high |
| 119 | `Store.set`/`DFinsupp.update` per-op cost: support-membership scan + support-list copy + new closure layer, p… | Theory/Store.lean:113–115 (`Store.set` = `DFinsupp.update`), applied per op by Theory/Sto… | high (c… |
| 119 | `Footprint.delta` is a function field: every query re-filters the changed set and re-reads pre/post per addre… | Theory/StoreFootprint.lean:62–70 (`footprintOf` — `delta := fun named => ∑ address ∈ chan… | high |
| 119 | `changed pre post` computed twice per world-kind change, and scans the union of both supports | Theory/StoreFootprint.lean:15–21 (`changedWithin` filters `candidates` with `pre address … | high |
| 122 | Full-directory rescan per dispatched job, under the custody mutex | native/resource-client/src/async_dispatch.rs:262–291 (`run_next`) | high |
| 126 | `session_invoke` re-hashes the 159 MB Host image before every Host operation | native/resource-client/src/main.rs:714-731 (`session_invoke`, `let selected_sha = host_im… | high |
| 126 | Per-attempt fsync storm: every retained artifact fsyncs its file *and* every ancestor directory | native/resource-client/src/fleet.rs:78-81 (`retain` → `crate::fsio::retain_exact` + `sync… | high (c… |
| 127 | Same handoff bundle decoded and ed25519-verified 3–4× per flow | hermes_handoff.rs:71-124 (`decode`: `verify_strict` + JSON parse of up to 4 MiB payload);… | high |
| 000 | `addressKey` keys sorts on `List Nat` instead of the raw bytes | Compiler/StoreCodec.lean:297 (`addressKey` = `((addressStream W).encode address).map UInt… | medium |
| 006 | 6. Rate gate decodes the signed observation, then the receiver decodes it again | Host/Main.lean:2205–2224 (`claimOf`/`ratedClaims`), invoked in `serveFrame` :3035 for ops… | medium … |
| 011 | 9. `BatchReady` is a runtime-decided Prop whose subchecks re-walk the authority cell | Compiler/CredentialAuthorityDomainReceiver.lean:565–578 (`BatchReady`, `batchReadyDecidab… | medium … |
| 012 | Zero-argument codec/customization defs are rebuilt on every use — including the string behind every `dig` | Compiler/DurableIndex.lean:115 (`nodeCustomization`), 235 (`keyCustomization`), 150 (`dig… | medium … |
| 012 | `split`'s first-differ search rebuilds range/filter and re-derives both bit paths | Compiler/DurableIndex.lean:457–474 (`split`) | medium |
| 014 | Map/set encode re-derives the canonical entry list from the DFinsupp on every encode | Compiler/FiniteDependentMapCodec.lean:103–105 (`entries`: `(fields.support.sort (· ≤ ·)).… | medium |
| 017 | `checkRead` re-encodes the whole packed cell to recompute the physical root per observed read | Kernel/ApplicationDispatchAdmission.lean:545–546 (`checkRead`): `ResourceBirthCodec.physi… | medium-… |
| 017 | `StoreHiding.items` recomputes every entry's opening per read; the reuse layer only covers part of the path | Compiler/StoreHiding.lean:110–115 (`itemOf`, `items`), consumed at runtime by `NativeObse… | medium-… |
| 018 | `birthMatches` decodes the kind's inner store twice and judges ROM equality over a support union | Compiler/WorldKindCell.lean:189–201 (`birthMatches`) | medium |
| 018 | `cubePath`/`openAt` recomputes whole subtrees; one opening costs ~the whole commit | Compiler/Tower256CshakeMerkleController.lean:124–135 (`cubePath`), :116–121 (`cubeRoot`),… | medium |
| 027 | policiesSourced re-walks the whole authority support and re-decodes every policy cell per validation | Kernel/NativeHostContext.lean:399–428 (`policySourcedAt`, `policiesSourcedAt`/`policiesSo… | medium |
| 027 | session-side heldFor re-derives the kernel config per decision | Kernel/NativeHostHeld.lean:47 (`ObjectiveKernelConfig.configOf config.deployment config.p… | medium |
| 042 | Every broker client call pays a second connection + a full `Identify` round trip; `package_image_at` pays it … | native/spk-host/src/broker_endpoint.rs:72-92 (`selected_call`), 93-101 (`call_at`), 102-1… | medium … |
| 048 | ~17 fsyncs per request, four of them redundant same-directory syncs | hostd.rs:1048 (`allocate_dispatch_operation`, 4 fsyncs), :1328 (`request_dispatch`, 8), :… | medium … |
| 061 | `verify_retained_grain_call` spawns the pinned Lean host 4× and rebuilds the codec directory per verification | foreground_session_recovery.rs:245–351 (`verify_retained_grain_call`); called per recover… | medium … |
| 066 | Metered-provider evidence fully re-validated twice per provider call | main.rs:10180–10309 (`validated_metered_charge`), called at main.rs:10358 (`provider_deli… | medium |
| 073 | custody_snapshot parses the full requests.json twice per quiescence flow just for three booleans | native/grain-runtime/src/resident_requests.rs:67-86 (`custody_snapshot`, `decode_queue`);… | medium |
| 077 | `ContentLaw` / `EventHistoryLaw` decide is O(support²) and runs inside every cell-law check | Compiler/CanonicalCellRegistry.lean:686–696 (`ContentLaw`, `contentLawDecidable`), :724–7… | medium … |
| 078 | `Snapshot.ofCell` → `authState` enumerates the whole cell twice per snapshot build | Compiler/CredentialAuthorityDomain.lean:75, :93–95 (`authStateOf`, `Snapshot.ofCell`); Th… | medium … |
| 083 | `ObjectiveBendSourceArtifact.checkWithin` re-renders the typed core JSON to verify canonicity | Compiler/ObjectiveBendSourceArtifact.lean:82 (`parsePacket`: after `Json.parse`, `json.co… | medium |
| 085 | `observe` re-decides `CellLaw` (and re-checks root equality) on every target observation | Compiler/ResourceTargetAdmission.lean:71 (`observe`) | medium … |
| 087 | `matchesIssued` re-hashes the whole ticket per call on the agent-dispatch path | Kernel/ApplicationAgentLifetimeGrant.lean:182-206 (`ticketDigest` = full `ticketCodec.enc… | medium |
| 090 | Share-issue admissions build and encode the expected descriptor twice | Kernel/ApplicationShareIssueAdmission.lean:90-102 (`admitNative`: the `expectedDescriptor… | medium |
| 091 | Stream-continuity: head-record frame re-encoded per op154 handoff; `probeRequest` re-derived per verification | Kernel/ApplicationStreamContinuity.lean:244 (`withOpenedFreshTip`), :285 (`receiveVerifie… | medium … |
| 091 | Audience roster check decodes then re-encodes the roster to compare with the catalog payload | Kernel/AudienceRosterBinding.lean:89–106 (`check`), :124–130 (`checkBytes`) | medium |
| 092 | `bookDelta` sums the entire book twice per asset query, over a DFinsupp coordinate walk | Kernel/CanonicalResourceEffect.lean:536-539 (`bookDelta`), 543-546 (`typedResourceLaw`), … | medium … |
| 095 | `imageBytes` encodes every value of a born cell just to measure lengths | Kernel/DeployedHistory.lean:52 (`imageBytes`) | medium |
| 096 | FnArchive render/extract encode the whole bundle 3–5× and hash it twice per article | Kernel/FnArchive.lean:320 (`render`), :304 (`checkBundle`), :316 (`source`), :300 (`overs… | medium … |
| 096 | admitAppend decodes the epoch record by full re-encode, and re-classifies the topic 3× / re-reads the last re… | Kernel/DomainEpochLaw.lean:203 (`admitAppend`), :191 (`prevOf`), :185 (`lastRecord`); Ker… | medium … |
| 103 | Nullary codec defs are rebuilt on every encode/decode: `recordCodec`'s 13-level codec tower, `ObjectState.wir… | Kernel/ObjectRecord.lean:931–995 (`upgradeStream`/`pendingStream`/`phaseStream`/`recordSt… | medium … |
| 104 | 8. `resumeQuote` runs the entire resume tail (type + decode checkpoint + machine resume) for one number | Kernel/ObjectiveActivity.lean:3251–3261 (`resumeQuote`), called per asked (record, await)… | medium … |
| 114 | `SamplesExact` decidability walks the whole Book per sample | Kernel/ResourceMoneyOperationDomain.lean:213-232 (`SamplesExact` + its instance + `Prepar… | medium |
| 116 | `LeaseFree` decidability walks the whole `leaseRecords` support per offer | Kernel/Seat.lean:799–805 (`LeaseFree` + its `Decidable` instance), consumed at `step .off… | medium |
| 129 | One-shot `minidregg-host` process exec per local verb call | join_solana_v2.rs:243 (`local_json`), join_solana_v2.rs:665 (`stable_ids`) | medium … |

### Per request (201)

| shard | finding | where | conf |
|---|---|---|---|
| 004 | `parse` walks every body three times, re-parsing every object key through the full JSON parser | Host/Json.lean:277–281 (`parse`), :221–247 (`duplicateScan`), :239 (`Lean.Json.parse (Str… | high |
| 004 | `nat` re-renders every parsed number to a decimal String for the canonicality check | Host/Json.lean:309–315 (`nat`), same pattern at :317–323 (`int`) | high |
| 004 | `list`, the universal array decoder, is O(n²) by `++ [x]` | Host/Json.lean:331–337 (`list`) | high |
| 004 | `exactObject` double membership loop over a rebuilt key list | Host/Json.lean:290–298 (`exactObject`); same pattern hand-rolled in `grainSource` at :226… | high |
| 004 | `decodeHex`/`encodeHex` traffic in `List UInt8` at the authoring boundary | Host/Json.lean:349–361 (`decodeHex`), :366–372 (`encodeHex`), :376 (`hexJson`) | high on… |
| 005 | Page render enumerates the whole content store 4–6 times per render | Host/Json.lean:4899 (`documentOf?`), 4906 (`pageLines`), 4957 (`runsJson`), 4967 (`pageJs… | high on… |
| 005 | `historyJson` fully re-renders the same page once per history row | Host/Json.lean:5070–5091 (`historyJson`, `pageAt`) | high on… |
| 005 | `contentCellJson` renders full canonical JSON (incl. per-entry hex payloads and canonical re-encode) that con… | Host/Json.lean:4730 (`contentCellJson`), 4653–4728 (`contentEntryJson`), reached via 4785… | high on… |
| 005 | `transclusionProjectionJson` re-resolves a live range that `renderTransclusion` just resolved | Host/Json.lean:4878–4895 (`transclusionProjectionJson`), consuming Kernel/ContentResource… | high |
| 005 | `declaredCellJson` makes five passes over the same entry list | Host/Json.lean:4469–4503 (`declaredCellJson`), reached from `resourceJson` (4785) for dec… | high on… |
| 006 | 1. Frame I/O converts the whole payload ByteArray ↔ List on every request and reply | Host/Main.lean:3103–3104 (`serveSession`, `payload.toList`), Host/Main.lean:3130 (`serveC… | high |
| 006 | 4. `readExactly` grows the frame buffer by quadratic concatenation on multi-chunk reads | Host/Main.lean:2716–2721 (`readExactly`, `acc ++ chunk` per iteration) | high (p… |
| 007 | FnEvidence.verify re-replays the whole accepted prefix in a scratch Store per fn poll/outbox decision | Host/Main.lean:5124 (`runPollConsumerDecisionLoaded`), Host/Main.lean:5214 (`runReplyCons… | high |
| 007 | operatorAcceptedLog (full-history re-verification) called on session request paths | Host/Main.lean:5326 (`verifyCatalogOwnR`) and Host/Main.lean:5479 (`runReplyConsumerCatal… | high |
| 007 | projectFnPoll runs twice per poll request over identical files | Host/Main.lean:5627–5628 (`runFnPollSession`) then again via `runPollConsumerDecisionLoad… | high |
| 007 | verifyFnIdentity re-spawned per fn sub-call; ~7 fn processes per single poll request | Host/Main.lean:3859–3892 (`queryFnConsumerPosition` calls `verifyFnIdentity` at 3833, the… | high |
| 007 | Carry registry re-read and re-parsed up to twice per carried request | Host/Main.lean:4455 (`carriedOrdinaryCall`) and 4492 (`retainedDispatchReceipt`) — both f… | high |
| 007 | retainedDispatchReceipt scans every accepted record with recursive List equality per carried request | Host/Main.lean:4489–4491 (`retainedDispatchReceipt`), called per carried submit (8393) an… | high |
| 007 | fn pin/scope manifests re-read, re-parsed and re-validated mid-request | Host/Main.lean:5596–5605 (`runFnPollSession` reads fnPinPath/scopePath) then `runPollCons… | high |
| 008 | List-UInt8 stdio wire converts every payload through three representations per request | Host/Main.lean:7199–8396 (`runCommandStdio`, the `fnDispatch` closure), with Host/Main.le… | high |
| 008 | `loadCarryRegistry` re-reads and re-parses the registry file on every carried-history request | Host/Main.lean:4332–4339 (`loadCarryRegistry`), called per request at Host/Main.lean:7274… | high |
| 008 | Op 189/190 in carry mode refreshes the carried suffix twice per request | Host/Main.lean:7575–7589 (`runCommandStdio`, ops 189/190 arm) | high |
| 010 | view-document renders one page from ~5 whole-store enumerations plus O(elements × marks) filtering | Host/SourceAgreementJson.lean:2659 (`documentJson`), :2630 and :2637 (`pageJson`), :2573–… | high |
| 010 | context-document derives the document's lines twice and enumerates the store twice | Host/SourceAgreementContextInspection.lean:67–100 (`document`, esp. :85–91), :54–58 (`doc… | high |
| 010 | `SourceAgreementJson.parse` makes three full passes over the request, re-parsing every key | Host/SourceAgreementJson.lean:89–93 (`parse`), :71–85 (`nestingDepth`), :43–69 (`duplicat… | high |
| 010 | `contentCellJson` re-encodes and hexes every store entry per resource view | Host/SourceAgreementJson.lean:2325–2405 (`contentEntryJson`, `contentCellJson`), via `res… | high |
| 010 | `documentOf?` materializes the whole entry list, then re-enumerates through the legacy fallback | Host/SourceAgreementContextInspection.lean:54–58 and Host/SourceAgreementJson.lean:2567–2… | high |
| 010 | `cellJson` re-derives a SHAKE256 coordinate per cell per seat view | Host/SeatJson.lean:245 (`cellJson`, `atCoordinate`); Kernel/ProtectedCell.lean:94–97 (`Se… | high |
| 010 | every numeric JSON field pays a Nat→String round trip for canonicality | Host/SourceAgreementJson.lean:121–127 (`nat`), :129–135 (`int`); Host/SourceAgreementCont… | high |
| 010 | `list` decodes arrays by O(n²) append | Host/SourceAgreementJson.lean:143–149 (`list`) | high |
| 011 | 7. `replacePayload` decodes the same lifecycle image twice | Compiler/ContentControlFrame.lean:73–85 (`replacePayload`), 52–61 (`atom`) | high |
| 012 | `Reader.footprint`: one Store round trip per declared key, plus `++ [singleton]` accumulation | Compiler/DurableHistoryReader.lean:262–277 (`Reader.footprint`); singleton fetch at Compi… | high (s… |
| 018 | `loadTarget`/`ofCell` re-encode and re-hash the entire cell on every receiver law evaluation | Compiler/WorldKindLawDependencies.lean:81 (`loadTarget`, `ResourceBirthCodec.physicalRoot… | high |
| 023 | `Intent.preflight` runs quadratic `decide Nodup` on every request and every replayed record | Kernel/DurableCommitProtocol.lean:347-349 (`Intent.preflight`: `decide (intent.rootWrites… | high |
| 023 | `Engine.view`/`light` re-hash full cell bytes on every root read | Kernel/DurableEngine.lean:125-144 (`Engine.view`, `Engine.light`: `roots := fun cellId =>… | high (m… |
| 023 | `MultiCellCostPolicy.exact` recomputes the nullifier-bytes sum per lane query | Kernel/DurableCommitProtocol.lean:625-640 (`MultiCellCostPolicy.exact`) | high (m… |
| 024 | Grain birth request decodes the ingress twice | Kernel/GrainResourceBirthReceiver.lean:270 (`receive` runs `GrainResourceBirthPolicyContr… | high |
| 026 | `fleetIncomingAuthorizedLoaded` decodes the whole journal and builds with per-element `++` | Kernel/NativeHost.lean:1967 (`fleetIncomingAuthorizedLoaded`), :1861 (`fleetIncomingFrom`… | high |
| 026 | `fleetHeadAuthorizedLoaded` decodes every accepted record to find one head | Kernel/NativeHost.lean:1799 (`fleetHeadAuthorizedLoaded`) | high |
| 026 | `activityViewLoaded` encodes each asked cell's canonical bytes twice (or more) | Kernel/NativeHost.lean:2662 (`activityViewLoaded`) | high |
| 027 | objectAudienceLoaded re-validates from scratch and discards the Verified it is handed | Kernel/NativeHostObjectAudience.lean:58 (`let .ok opened := validateLoaded config target`… | high |
| 027 | Config.profile (manifest encode + digest) recomputed at every use, several times per request | Kernel/NativeHostContext.lean:179 (`Config.profile`); consumers read in this shard: `Conf… | high |
| 030 | `replay` runs on every submission and does a linear scan of the whole journal, computing `transactionId` twice | Kernel/ObjectiveActivityReceiverCore.lean:2729–2744 (`replay`: `transactionId` at 2731 an… | high (d… |
| 031 | 1. `step prepared` re-evaluated ~5× per authorize; each evaluation runs `project` twice | Kernel/PayAssignmentReceiver.lean:503–504 (`step`/`project`), 542–543, used at 553, 556–5… | high |
| 031 | 2. Policy projection state is byte-expanded into per-byte string-keyed slots | Compiler/ResourceAuthorityProjection.lean:43–45 (`bytesSlots`: one `(s!"{stem}/{index}", … | high |
| 031 | 3. `marker` (SHAKE256 over digest-heavy encode) recomputed ~8–12× per submit | `marker` PayAssignmentReceiver.lean:325–330, PayBookReceiver.lean:364–369; called from `d… | high |
| 031 | 4. `commandCodec.encode command` and `DecodedIngress.bytes` re-encode bytes the ingress already holds | `DecodedIngress.bytes` PayAssignmentReceiver.lean:322–323, PayBookReceiver.lean:361–362 (… | high |
| 031 | 5. `charge`'s expensive lanes re-derive per lane application; `storageAt` computes `deltas` twice | `charge` in all four receivers (PayAssignment 695–705, PayBook 749–759, ParticipantFactor… | high |
| 031 | 6. `event` computed 2–3× per submit | `event` PayAssignmentReceiver.lean:612–617, PayBookReceiver.lean:661–665, ParticipantFact… | high |
| 031 | 7. `readGuards` filter recomputes `writes prepared` per guard | PayAssignmentReceiver.lean:628–631, PayBookReceiver.lean:680–683, ParticipantFactoryProvi… | high |
| 031 | 9. Pay-cell decision scans the whole Store support, with a runtime `decide (∃ …)` per request | Kernel/PayCell.lean:316–317 (`countIn` = `(store.support.filter …).card`), :321 (`nextFre… | high |
| 033 | PolicyInstallController builds `request` inside the projection lambda and re-roots the newborn cell per proje… | Kernel/PolicyInstallController.lean:387 `Prepared.step` (`fun logical => project (request… | high |
| 033 | `requestDigest` recomputed 3–4× per policy install; each is 3 policy-source encodes + 2 hashes + a words enco… | Kernel/PolicyInstallController.lean:191 `requestDigest` (calls `request` whose `argsDiges… | high |
| 033 | Read-guard filters re-derive `writes.map DataWrite.cellId` (i.e. re-apply the validated patch) once per guard… | Kernel/PolicyInstallReceiver.lean:334 `Prepared.readGuards` (`… .filter fun guard => guar… | high |
| 033 | Ingress bytes re-encoded from scratch for every event hash, charge length and replay check; platform `replay`… | `DecodedIngress.bytes` Kernel/PayObservationReceiver.lean:139, Kernel/PlatformInstallRece… | high |
| 033 | `addressSlots` allocates an interpolated string per address byte, per project pass | Kernel/PolicyInstallController.lean:289 `addressSlots` (`s!"policy/address/{offset}"` per… | high (w… |
| 035 | Birth receiver decodes the ingress twice per submit | Kernel/ResourceBirthReceiver.lean:704–715 (`receive` decodes via `decodeIngress` to check… | high |
| 038 | `asset_tag` re-hashes vendored assets on every call | native/mini-web/src/page.rs:43-47 (`asset_tag`, `sha2::Sha256::digest(bytes)` per call); … | high |
| 038 | `/registry` re-reads and re-parses its files on every request | native/mini-web/src/page.rs:254-263 (`registry`: `std::fs::read` + `serde_json::from_slic… | high |
| 039 | Micro-cluster: hex-decode-to-check-emptiness, `format!`-per-byte hex, repeated `binding.fingerprint()` | (a) agent_api_custody.rs:213-214 and :265-266 — `unhex(field(inspection, "compactSelector… | high |
| 040 | Fsync storm: every custody artifact costs file-sync + directory-sync | `write_new` (dispatch_native.rs:88–103, `file.sync_all()` + dir `sync_all()` per call); i… | high (m… |
| 040 | `check_pin` re-reads and re-hashes the entire config on every operator call — and `tool_until` verifies the h… | `check_pin` (dispatch_native.rs:440–459: `read_pinned_input(config)` + SHA-256 + hex + di… | high |
| 040 | Reply JSON serialized twice per dispatch | `http_reply_v3` (agent_api_lifetime_server_v3.rs:684: `serde_json::to_vec(&reply)?.len()`… | high |
| 041 | `exact_acl` fork/execs `/usr/bin/getfacl` on every accepted connection | agent_api_server.rs:176–179 (`exact_acl`, the `Command::new("/usr/bin/getfacl")` call), i… | high |
| 041 | `CallerWatch`: per-request thread polling a 1-byte `MSG_PEEK` recv every 10 ms | agent_api_server.rs:255–287 (`CallerWatch::start`), started for every request in `poll_on… | high |
| 043 | Five `minidregg-host` process spawns per request in the dispatch pipeline | dispatch_native.rs:1011–1085 (`author_signed_ingress`), 1239–1379 (`author_and_submit`), … | high (s… |
| 043 | Hex-echo equality checks re-encode request body and committed frame per request | dispatch_author.rs:157–177 (`sign_plan`: `serde_json::from_slice(inspection)`, `source_re… | high |
| 043 | `admit_new_call` scans the attempt parent three times and strips all settled attempts every request | dispatch_fence.rs:601–624 (`admit_new_call` — `undecided(parent)` at 602, `collect(parent… | high |
| 043 | `check_pin` re-reads and re-hashes the 64 KiB config on every host call | dispatch_native.rs:440–459 (`check_pin`/`pinned_config`: `read_pinned_input(&self.config,… | high |
| 043 | Per-signer seed re-read and Ed25519 key re-derivation in `sign_plan` | dispatch_author.rs:209–221 (sign loop calls `private_signing_key(&pin.seed_path)` per sig… | high |
| 043 | Double `journal.read()` per request in `deliver_once` | dispatch_delivery.rs:104–107 and again 221–224 (inside the projection closure); `Journal:… | high (p… |
| 044 | `match_inspection` materializes the whole payload and body as hex Strings to compare them | native/spk-host/src/dispatch_inspection.rs:154–239 (`match_inspection`; especially 167, 1… | high |
| 044 | `admit_new_call` rescans the whole journal three times and re-strips every settled attempt on every new call | native/spk-host/src/dispatch_fence.rs:601–624 (`admit_new_call`), 292–306 (`collect`), 26… | high |
| 044 | Every outcome decode and lookup spawns a fresh Lean host process (and a lookup turn) on the submit path | native/spk-host/src/dispatch_fence.rs:363–373 (`inspect_outcome` → `operator.tool_until`)… | high (m… |
| 045 | 1. Up to five Lean-host process spawns per request (`author_signed_ingress`, post-commit inspect) | dispatch_native.rs:1027 (`tool_until "author" application-dispatch-request`), :1047 (`too… | high (m… |
| 045 | 2. Double-fsync artifact storm per request (`write_new`) | dispatch_native.rs:88-103 (`write_new`: `file.sync_all()` + `File::open(directory).sync_a… | high on… |
| 045 | 3. `preflight_web_input` materializes the full projection (including a body copy) it then discards | dispatch_web_input.rs:250 (`preflight_web_input`) → `project_http` :434/:441 (`bytes: htt… | high |
| 045 | 4. `check_pin` re-reads and re-hashes the pinned config on every socket op | dispatch_native.rs:440-459 (`check_pin` → `read_pinned_input` + `Sha256::digest` + `pinne… | high (b… |
| 047 | Profile lineage re-verification re-parses the admission and re-hashes pinned binaries per ancestor, on every … | native/spk-host/src/grain_profile_upgrade.rs:255–304 (`validate_lineage`), 176–250 (`deri… | high (m… |
| 048 | Per-request systemctl spawn storm: 4× `verify_running_instance`, 2 spawns each, one would do | hostd.rs:155 (`Record::verify_running_instance`), hostd.rs:411 (`UnitInstance::current`),… | high |
| 048 | Permit bytes hashed 3× and written+kept per request (up to ~12 MB each) | hostd.rs:301 (`validate_committed_permit`), :1145 (`capture_dispatch_permit_unlocked`), :… | high on… |
| 048 | `verify_dispatch_idle` re-reads and re-validates every tombstone since genesis, O(requests) | hostd.rs:1012 (`verify_dispatch_idle`, loop at :1027–1040) | high on… |
| 048 | `bounded_systemctl` 10 ms sleep-poll per spawn | hostd.rs:368 (`bounded_systemctl`, sleep at :394) | high |
| 049 | Dispatch loop wakes on a 20 ms tick; a queued request can wait out the whole poll timeout | native/spk-host/src/http_entrance.rs:1157-1309 (`serve_dynamic_with_aux`), with the reade… | high |
| 049 | `read_until` busy-polls with a blind 2 ms sleep instead of a blocking read with a socket timeout | native/spk-host/src/http_entrance.rs:706-735 (`read_until`), called from `read_request_un… | high |
| 049 | Thread-per-connection, thread-per-request, thread-per-refusal | native/spk-host/src/http_entrance.rs:1099-1144 (`spawn_reader`, one thread per admitted c… | high (m… |
| 049 | `serialize_for_origin` copies the whole body into the head buffer | native/spk-host/src/http_response.rs:386-393 (`serialize`/`serialize_for_origin`) | high |
| 050 | Every lifecycle helper call spawns a cold Lean host process (~10–12 spawns per app START/INSTALL) | lifecycle_v3_claim_native.rs:208-296 (`assemble_once`, 3× `operator.tool` + 2× `operator.… | high |
| 053 | 1. Full SPK archive re-verification on every resident start, stop and route bind | materialize.rs:338 (`verify_installed_spk`) — called from resident_service.rs:1447 (every… | high |
| 053 | 6. Published-file serving pays a two-round-trip fd ferry per HTTP request | resident_privilege.rs:330–352 (`Client::open_www_file`), worker tag-6 arm at 559–587; rea… | high on… |
| 054 | Checkpoint pause fence is stat()'d on every event, including every HTTP request | resident_service.rs:1978 and resident_service.rs:2052 (`checkpoint.paused()`), implemente… | high |
| 055 | Cancellation observed by 10 ms polling instead of an event, on both sides of a dispatch | rpc_adapter.rs:49-53 (`wait_cancelled`), used as the biased select arm in every `Command:… | high (p… |
| 057 | `io::copy` through `Take` loses the kernel zero-copy path — every served byte goes through an 8 KiB userspace… | native/spk-host/src/www_publish.rs:398 (`serve`, body send) | high |
| 057 | Thread spawned per connection, and `Connection: close` on every response forbids keep-alive | native/spk-host/src/www_publish.rs:124 (`accept_one`, per-connection `std::thread::Builde… | high (m… |
| 057 | The file length computed in the worker is discarded, then `serve` fstats the same file again | native/spk-host/src/www_publish.rs:264,284 (`open_beneath` fstats and returns `(File, u64… | high |
| 057 | `read_head` rescans the whole accumulated buffer for `\r\n\r\n` after every read | native/spk-host/src/www_publish.rs:346 (`read_head`) | high |
| 057 | Small per-request allocations in parse/open (compacted; individually µs-level) | native/spk-host/src/www_publish.rs:196 (`components` collects `Vec<&str>` then `to_owned`… | high (t… |
| 058 | `present_lifetime_http` deep-clones the whole reply, copying the `bodyHex` string it immediately deletes | `application_api_tools.rs:111` (`present_lifetime_http`): `let mut view = reply.clone();`… | high |
| 058 | WouldBlock handled by `thread::sleep(2ms)` in the request/reply transfer loops | `application_api_tools.rs:1331` (`first_write`) and `application_api_tools.rs:1387–1389` … | high (m… |
| 058 | `parse_input` re-serializes the whole tool input just to measure it | `application_api_tools.rs:1873` (`parse_input`): `serde_json::to_vec(arguments)` used onl… | high |
| 058 | One OS thread spawned per hello and per dispatch exchange | `application_api_tools.rs:1781–1806` (`start_exchange_once`) and `1808–1835` (`start_disp… | high (t… |
| 061 | GitWeb read/edit re-clone the whole repo and pay 2 (read) / 6 (edit) signed host turns per tool call | gitweb_worker.rs:428 (`read`), gitweb_worker.rs:518–670 (`edit`), serve_git forward at :3… | high (f… |
| 063 | Lifetime dispatch re-reads and hex-decodes the whole reserve plan per attempt | native/grain-runtime/src/main.rs:1539 (`checked_lifetime_reserve_plan_hex`); called per l… | high th… |
| 063 | Controller restart re-reads and re-hashes every retained journal artifact | native/grain-runtime/src/main.rs:2034 (`Journal::validate_workspace`), :2144 (`Journal::v… | high (f… |
| 063 | Birth retirement deep-clones the entire journal per retirement | native/grain-runtime/src/main.rs:1095 (`persist_retired_no_birth_operation`) — `let mut t… | high (m… |
| 064 | `next_id()` fsync-publishes the entire journal for every operation-ID allocation | `next_id` (main.rs:7334–7339) → `save()` → `atomic_json` (2721–2724, `serde_json::to_vec_… | high |
| 064 | `dispatch_sign_payer_v3` reads plan.bin twice and hashes it three times in one function | `dispatch_sign_payer_v3` (main.rs:5412–5414, 5489, 5506) | high |
| 065 | Per-HTTP-request signed parent observation in `begin_application_api` | native/grain-runtime/src/main.rs:8395 (`begin_application_api`), main.rs:8495 (`begin_app… | high (c… |
| 065 | Full birth-evidence re-verification (~16 MiB read+hash) twice per HTTP request | native/grain-runtime/src/main.rs:8384+8390 (`begin_application_api`), 8484+8490 (`begin_a… | high |
| 065 | Host-image sha256 per HTTP request | native/grain-runtime/src/main.rs:8356 (`begin_application_api`), main.rs:8470 (`begin_app… | high |
| 065 | `next_id()` commits the whole journal (two fsyncs) — several times per operation | native/grain-runtime/src/main.rs:7334–7339 (`next_id` → `save`), 6672–6674 (`save` → `ato… | high on… |
| 065 | Host reply serialized 2–3× and cloned per application-API response | native/grain-runtime/src/main.rs — `poll_application_api`: `parse_host_reply(result.clone… | high |
| 066 | Host executable SHA-256 re-hashed twice per application-API request (and once per catalog serve) | main.rs:12918 (`preflight_foreground_arguments`, arm `mini_application_api / mini_oracle_… | high |
| 066 | Journal save amplification: whole-journal pretty-JSON + double fsync, ~8–12 times per foreground call | main.rs:6672 (`save` → `atomic_json` 2721 → `journal_io::write` journal_io.rs:21–50: `to_… | high |
| 066 | `reconciliation_log` grows without bound and is copied by every save | main.rs:588 (`reconciliation_log: Vec<Value>`, no bound, no trim — pushed at 13376, 13572… | high |
| 066 | `acknowledge_foreground` re-reads, re-hashes and re-parses the up-to-1 MiB result to learn an operation ID it… | main.rs:13245–13246 (`acknowledge_foreground` calls `foreground_result`), which at main.r… | high |
| 070 | Listener accept loops sleep-poll at 20 ms (gateway side) | native/grain-runtime/src/provider.rs:577-579 (`GatewayEndpoint::start` listener thread) | high |
| 070 | Same 20 ms sleep-poll in the worker bridge, doubling the added latency | native/grain-runtime/src/provider_bridge.rs:243-259 (`run`) | high |
| 070 | fsync amplification in the forward spool path, incl. a redundant directory fsync and a read-back of just-writ… | native/grain-runtime/src/provider.rs:1548-1555 (`forward`), 1667-1694 (`forward_once` spo… | high on… |
| 070 | Full request body parsed as JSON just to check the pinned model | native/grain-runtime/src/provider.rs:1004-1014 (`serve_client`) | high th… |
| 070 | Redundant full-body clones per request | native/grain-runtime/src/provider.rs:1032-1036, 1161-1167 (`serve_client`) | high th… |
| 073 | Preflight config digests re-serialize the whole Config two-to-four times per check | native/grain-runtime/src/resident_preflight.rs:6-11 (`config_digest`, `binding_digest`), … | high |
| 077 | `accountCut` rebuilds a DFinsupp over the whole Book per bend-native call | Compiler/CanonicalAccountView.lean:32–37 (`accountBalanceMap`, `accountCut`), :61 (`slots… | high (m… |
| 078 | `issuerCheck` scans the whole authority-cell support and cSHAKE-hashes every capability, per request | Compiler/CredentialAuthorityPolicyRegistry.lean:276–280 (`issuerCheck`), reached from `so… | high |
| 078 | `Profile.semantics`/`Profile.compilerProfile` re-encode the entire runtime manifest + SHAKE on every reference | Compiler/CanonicalRuntimeProfileCore.lean:152–160 (`Profile.compilerProfile`, `Profile.se… | high |
| 078 | `Config.verifies` re-resolves the policy, the whole law graph, and the closure digest per admission; `admit` … | Compiler/ComposedPolicyAdmission.lean:67–85 (`Config.verifies`: `loadPolicy` + `loadTarge… | high |
| 078 | Same stored capability re-read and re-hashed ~4× per capability admission | Compiler/CredentialAuthorityPolicyRegistry.lean:547–586 (`capabilityEvidenceCheckedFor`),… | high |
| 079 | Each signature verify writes a fresh temp directory with three files | Compiler/CredentialSignatureIO.lean:126–136 (`verify`; same pattern :149–161 in `verifySs… | high |
| 081 | `NativeInvocationProfile.select` re-decodes the whole profile per binding query; bend admission decodes it 3×… | Compiler/NativeInvocationProfile.lean:57-66 (`select`, `binding`, `registered`); callers … | high (c… |
| 081 | `recipientRequest` computes the identical roster-digest expression twice per call (the `charge` bug class aga… | Kernel/ConfidentialAudienceAdmission.lean:56-59 (`recipientRequest`, fields `argsDigest` … | high. |
| 081 | `ObjectiveBendC4.linearize` builds results with `++ [x]` (O(n²)) and allocates its fuel as a list | Compiler/ObjectiveBendC4.lean:144,161-171,153 (`removeSuffixTailAndReverse` caller loop `… | high on… |
| 081 | `objectRosterJson` double-encodes and double-hashes the roster per request, then renders 256-bit Nats as deci… | Host/Main.lean:2288-2294 (`objectRosterJson`); defs in Compiler/ObjectAudienceRoster.lean… | high. |
| 081 | Nullary frame/customization `def`s re-encode their strings on every call | Compiler/NativeInvocationProfile.lean:49 (`frame`), Compiler/NativeInvocationStatement.le… | high on… |
| 082 | Output-codec `codecId` digests recomputed at every codec-tag comparison | Compiler/ObjectiveBendGenericResult.lean:35 (`codecId`, no-arg def: SHAKE-256 over a lite… | high |
| 082 | prepareChecked encodes the whole plan to bytes just to measure its length | Compiler/ObjectiveBendGenericResult.lean:139 (`prepareChecked`): `producedBytes := (plan.… | high |
| 082 | splitTop is O(n²) with per-character list allocation, and it is the elaborator's inner loop | Compiler/ObjectiveBendElaborate.lean:505–517 (`splitTop`); with Compiler/ObjectiveBendEla… | high |
| 086 | cSHAKE seam: every `hash` call pays 3 List↔ByteArray conversions plus a re-encoded string literal | Theory/Sp800185Cshake256Native.lean:56–57 (`cshake256Native`: `bytesOfList customization`… | high |
| 087 | Failed-start recovery lookup endpoint: linear scan of all accepted records + repeated multi-KB encodes, per r… | Kernel/ApplicationFailedStartRecoveryLookup.lean:23-46 (`ApplicationFailedStartRecoveryLo… | high |
| 087 | `appRequest` structure literal re-derives `sourceBytes spec descriptor` 3× per construction; `Prepared.wanted… | Kernel/ApplicationAgentLifetimeGrantSource.lean:158-182 (`appRequest`: `argsDigest`, `eff… | high |
| 093 | `recipientRequest` computes the identical roster hash twice, and once per roster entry | Kernel/ConfidentialAudienceAdmission.lean:56–59 (`recipientRequest`), driven per entry by… | high |
| 093 | `check` re-encodes the whole roster a third time to validate the registry payload | Kernel/ConfidentialAudienceAdmission.lean:168 (`recordsExact` guard in `check`; same expr… | high |
| 093 | `recipientRequest.cost` encodes the entry to a byte list only to take its length | Kernel/ConfidentialAudienceAdmission.lean:66 (`cost := (ObjectAudienceRoster.entryStream.… | high |
| 094 | `CredentialSignedEnvelopeController.registryDigest`: quadratic big-Nat Horner over the whole registry | Kernel/CredentialSignedEnvelopeController.lean:116 (`registryDigest`), used at 306 in `pr… | high |
| 094 | `consumedNullifiers`: unbounded linear scan, per admission | Kernel/CredentialSignedEnvelopeController.lean:318 (`state.consumedNullifiers.contains ..… | high |
| 096 | DocumentHistory.lines filters the entire mark list per document row (O(n·m) per view) | Kernel/DocumentHistory.lean:279 (`lines`), :237 (`lineOf`), :214 (`rowMarks`) | high |
| 098 | FnSelectiveReleaseSourceAuthority: sourceRequest re-encodes the whole spec packet 3× per call, and `wanted` i… | Kernel/FnSelectiveReleaseSourcePublication.lean:112–136 (`sourceRequest` — `sourceBytes s… | high |
| 098 | Encode-for-length checks over megabyte payloads | Kernel/FnOriginOutbox.lean:98 (`Prepared.valid`: `(preparedCodec.encode value).length ≤ m… | high |
| 102 | checkGrant/authorize re-derive select, header, marker hash and intent encode 2–3× per grant | Kernel/NativeObservationController.lean:573 (`checkGrant`), :552 (`challengeAt`), :431 (`… | high |
| 102 | `streamPayload` scans the entire accepted log per tail window entry | Kernel/NativeObservationController.lean:775 (`streamPayload`), called at :1686 (`.tail` b… | high |
| 102 | NockDoor re-cues the program jam per call; Kernel.Door.checkPoke re-jams the state 4× | Kernel/NockDoor.lean:120 (`dryPoke`: `match Noun.cue program.jam, …`); callee Kernel/Door… | high (d… |
| 102 | `.who` view: members/holders/grantsOf re-enumerate and re-read every capability per subject | Kernel/NativeObservationController.lean:913 (`members`), :970 (`holders`), :954 (`grantsO… | high |
| 102 | Batched observations accumulate with `views ++ [view]` | Kernel/NativeObservationOpeningCache.lean:235 (`queryWireLoaded`); twin at Kernel/NativeH… | high |
| 106 | 1. `prepareCore` (front-end replay, signatures, JSON parse, typing) runs 2–3× per invocation, each run re-rep… | Kernel/ObjectiveBendNativeAdmission.lean:630 (`prepareCore`), :484 (`selectSource`), :511… | high on… |
| 106 | 2. Typing `check` runs twice per admission: `checkOutput` re-checks the term `prepareCore` already typed | Kernel/ObjectiveBendNativeAdmission.lean:663 (`prepareCore`, computes `typed := check (in… | high. |
| 106 | 3. The same source/input envelope signatures are verified ~3× within one derive flow | Host/ObjectiveInvocationQuote.lean:192 (`authorize` on the draft) vs Kernel/ObjectiveBend… | high on… |
| 106 | 4. `ObjectiveBendNativeInput.encode input` re-encodes the whole input ~4× per admission | Kernel/ObjectiveBendNativeInput.lean:181 (`sourceTerm`, length check); Kernel/ObjectiveBe… | high. |
| 106 | 5. Per-read observation narrows the cell via `DFinsupp.filter` + re-materialize — then `hex` doubles it | Kernel/ObjectiveBendNativeInput.lean:69–77 (`observe`: `narrowPacked` then full `codec.en… | high on… |
| 106 | 6. `NativeInvocationProfile.select parameters` decodes the whole profile 3–4× per admission, and `policyExact… | Kernel/ObjectiveBendNativeAdmission.lean:634–639 (`registered` then `binding` then `bindi… | high. |
| 106 | 9. Nullary constant defs re-computed at every use (hashes and frame strings) | Kernel/ObjectiveBendNativeAdmission.lean:60 (`semanticsId`), :183 (`clearKeyEpoch`), :243… | high on… |
| 106 | 11. Upgrade verbs duplicate whole-package loads (`abortDrained`, `adopt`, `rebirthTargets`) | Kernel/ObjectiveActivityUpgrade.lean:700–704 (`abortDrained`: `packageBytes config snapsh… | high on… |
| 112 | Platform cell: `recordOn` re-decodes the whole cell per reader; `Loaded.write` encodes it twice; `physicalId`… | Kernel/PlatformCellDomain.lean:162 (`recordAt`), :170 (`recordOn`), :135 (`Loaded.write`)… | high fo… |
| 113 | 2. `checkAll` re-derives the whole entry-independent projection per roster entry | Kernel/ConfidentialAudienceAdmission.lean:78–107 (`checkOne`/`checkAll`) calling Kernel/R… | high |
| 115 | 4. `requestFor` re-encodes the whole command and re-hashes it per target (digests are target-independent) | Kernel/ResourceTransaction.lean:522–543 (`requestFor`), 428–431 (`commandBytes` → `framed… | high |
| 115 | 8. `commandCodec` ingress: strict canonicality check re-encodes the entire command | Kernel/ResourceTransaction.lean:323 (`commandCodec := ResourceBirthCodec.strictCodec rawC… | high |
| 115 | 10. `decideRoom` evaluates the room law twice on the refusal path | Kernel/RoomBirthGate.lean:128–134 (`decideRoom`: `LawLeaf.of law view view`, then on fail… | high |
| 118 | `Receiver.replay` re-hashes the ingress per call: `R.txId` up to 3×, `R.event` 2× | Theory/Receiving.lean:510 (`Receiver.replay`), receipt at :503 | high |
| 118 | `admitVia` resolves `R.claims` twice, then `admit` re-validates every claim it just verified | Theory/Receiving.lean:452 (`Receiver.admitVia`) → :263 (`Receiver.admit`), :79 (`firstRef… | high (c… |
| 118 | Tower256 byte codec churns boxed lists per coordinate; `2 ^ 256` recomputed per decode | Theory/BinaryTowerFanPaarCodec.lean:256 (`encodeFin`), :241 (`bytesOfDigits`), :269 (`dec… | high |
| 118 | `Receiver.guardsOff` re-maps and re-scans the write list per guard | Theory/Receiving.lean:476 (`guardsOff`) | high (c… |
| 121 | Front re-reads and re-parses the origin table from disk on every request | native/resource-client/src/apps_front.rs:350 (`Front::origin`), called from `serve` at ap… | high |
| 121 | Head-end scan restarts from byte 0 after every 4 KiB chunk | native/resource-client/src/apps_front.rs:320–322 (`find_head_end`), called in the read lo… | high |
| 123 | `read_room` re-reads every stream from sequence 1 on every call; the cursor cache is written but never used f… | native/resource-client/src/chat.rs:1105–1119 (`read_room`), 1203–1232 (`Held::stream`), 1… | high |
| 124 | 1 ms stat-polling loops in the cohort worker wait paths | cohort_tcp.rs:968-989 (`await_inputs`), cohort_tcp.rs:1170-1172 (`worker`, cover intent w… | high |
| 125 | V1 enrollment status: whole public view rebuilt per poll, ~3 extra full-size client copies, holds a global Ho… | enrollment_bootstrap.rs:415 (`enrollment`), copies at enrollment_bootstrap.rs:404 (`host_… | high (c… |
| 126 | Money-verb bookkeeping re-loads the workspace, re-hashes the config and stat-scans the operations dir per req… | native/resource-client/src/fleet.rs:340-363 (`operation_record`: `fs::canonicalize` + `wo… | high (t… |
| 006 | 3. `documentOf?` enumerates the whole Store per render and calls `carriedDocument` per entry | Host/LegacyContentView.lean:45–53 (`documentOf?`), used per page render from Host/Json.le… | medium … |
| 006 | 7. `LegacyContentView.lines` re-decodes per line; `hex` builds char lists per byte | Host/LegacyContentView.lean:59–63 (`lines`, `DocumentHistory.lineOf store marks element` … | medium … |
| 006 | 11. Bounded snapshot readers are quadratic at 4 KiB chunks | Host/Main.lean:3155–3161 (`readOperatorSnapshot`), :3229–3234 (`readBoundedLoop`) — `acc … | medium … |
| 011 | 10. Bend-native path: runtime `decide` of deep structural equality plus O(returns²) Nodup per invocation | Compiler/BendWorldPlan.lean:94–97 (`matchesCommand`: `decide (plan.effects = effectsOf co… | medium |
| 027 | One handler opens the Store twice back-to-back | Host/Main.lean:8959–8960 (read incidentally while checking callers): `openExisting config… | medium … |
| 029 | `refreshWalked` re-reads the physical suffix unconditionally | Kernel/NativeHostSession.lean:262–265 (`refreshWalked`: `DurableReceiverIO.extendFrom` on… | medium … |
| 031 | 8. `PhysicalShape` decided at runtime re-derives guards, writes and law-read-guards again | `physicalShapeDecidable` + `if physical : PhysicalShape prepared` in `admitDecodedNative`… | medium … |
| 031 | 10. `digestStream` routes every Digest through variable-length `encodeNat` in receiver codecs | Compiler/Tower256ConcreteBackend.lean:930–931 (`StreamCodec.nat` = `encodeNat`), 1053–105… | medium |
| 031 | 11. Replay check linear-scans the whole journal per request | `replay` in all four receivers (PayAssignmentReceiver.lean:730–740, PayBookReceiver.lean:… | medium |
| 033 | PayPendingRotation scans the entire authority store per rotation; `decidedPatch` re-looks-up custody `decide`… | Kernel/PayPendingRotation.lean:91 `ParticipantKeyEnrollment.allKeys authority (fun key =>… | medium … |
| 039 | Every authenticated request pays a fresh Unix-socket connect to the root helper | mini-web/src/session.rs:40-58 (`Sessions::who`) → mini-web-spawn/src/lib.rs:143-160 (`Cli… | medium … |
| 040 | One full Lean-host process spawn per source/inspect/signatures call, several per request | agent_api_native.rs:518 (`tool_until` — `Command::new(executable.path())`), called from `… | medium-… |
| 058 | Request/response bodies cross the socket as hex strings end-to-end | `hex()` at `application_api_tools.rs:67`; `bodyHex`/`body_hex` in `lifetime_dispatch_requ… | medium … |
| 063 | `foreground_request_id` re-parses each delivered frame's JSON just for the ID | native/grain-runtime/src/main.rs:922 (`foreground_request_id`) — `serde_json::from_slice(… | medium … |
| 080 | `mersenne127P` re-derives `2^127 − 1` at every demand | Compiler/Mersenne127.lean:43 (`def mersenne127P : ℕ := 2 ^ 127 - 1`); downstream uses con… | medium … |
| 082 | prepareChecked re-validates Nodup of command targets and effect refs with O(n²) decidability | Compiler/ObjectiveBendGenericResult.lean:127–128 (`prepareChecked`): `decide (command.tar… | medium |
| 082 | bindEffect resolves each effect's target by a fresh finRange + linear scan | Compiler/ObjectiveBendNativePlanData.lean:141–157 (`bindEffect`, via `indexOf` at Compile… | medium |
| 088 | Every lifecycle step rewrites all four fields, deepening the app cell's DFinsupp chain | Kernel/ApplicationGrain.lean:92–94 (`actions`), 405–431 (`Operation.after`, `Operation.ta… | medium |
| 093 | `CompletionCustodianKey.select` re-decodes the platform cell on every completion admission | Kernel/CompletionCustodianKey.lean:68–78 (`select`) → PlatformCellDomain.lean:90–94 (`loa… | medium-… |
| 102 | Resource-query cache probe re-encodes the whole packed cell; a miss prepares openings for every store entry | Kernel/NativeObservationOpeningCache.lean:156 (`provider`: `PackedCell.bytes … packed` fu… | medium |
| 108 | configOf re-decodes the deployment's Objective policy bytes on every kernel turn | Kernel/ObjectiveKernelConfig.lean:51–67 (`configOf`), decode at Kernel/ObjectiveBendNativ… | medium |
| 117 | `SubjectRate` table is an association list: linear scan per request, full re-allocation per charge | Kernel/SubjectRate.lean:104 (`Table := List (Nat × Slot)`), :113 (`lookup`), :115 (`put`)… | medium |
| 121 | Half-close grace holds a per-grain slot up to 5 s per keep-alive connection, polling at 50 ms | native/resource-client/src/apps_front.rs:477–486 (`serve`), slot taken at apps_front.rs:4… | medium … |
| 123 | Every `tail` pays one extra signed `who` read to split former members | native/resource-client/src/chat.rs:1013–1027 (`current_members`), called at chat.rs:1914 | medium … |
| 030 | Wire/command codecs are 0-ary `def`s rebuilt on every reference (`commandCodec`, `ingressCodec`, `turnStream`… | Kernel/ObjectiveActivityReceiverCore.lean:380–382 (`commandFrame`, `commandCodec`), :417–… | low |
| 064 | Whole-`DispatchAttempt`/forward-attempt clones per RPC | `dispatch_mark_send` (5827–5832), `dispatch_mark_send_v3` (5977–5982), `dispatch_settle_d… |  |

### Other cadence (419)

| shard | finding | where | conf |
|---|---|---|---|
| 000 | `inspectPlan` decodes every signing header twice | Host/ApplicationAgentLifetimeGrantInspection.lean:83 (`inspectPlan`: the `unless … all (d… | high |
| 003 | Op-65 re-validates the whole frontier plan twice in one handler, re-hashing report/source each time | Host/FnConsumerFrontierPlan.lean:145 (`checkCurrent`), :157 (`assembleSignature`), :81 (`… | high |
| 003 | `FnConsumerFrontierPlan.assembleSignature` encodes the ingress twice; plan encoded just to take `.length` | Host/FnConsumerFrontierPlan.lean:177–179 and :183–185 (`ingressCodec.encode ingress` in t… | high |
| 003 | `FnSelectiveReleaseFnReceiving.derive` encodes the packet then hands the bytes to a function that decodes the… | Host/FnSelectiveReleaseFnReceiving.lean:34–36; the decode is `FnSelectiveReleaseAuthoring… | high |
| 003 | `FnSelectiveReleaseFnAck.selectFrom` re-encodes the event and the ingress it just decoded | Host/FnSelectiveReleaseFnAck.lean:59–63 (`ingressCodec.decode event.canonicalBytes`, then… | high |
| 004 | `string`-to-bytes conversions of role lists box per char on the share-issue path | Host/Json.lean:1795–1797 (`shareIssueRole`, `(·.toUTF8.toList)` per added/removed role), … | high |
| 007 | projectFnPoll computes SHAKE diagnostics and newline counts even on success | Host/Main.lean:3740–3742 (`projectFnPoll`): the `diagnostic` string (SHAKE256 of stdout v… | high |
| 008 | Reserve-birth authoring round-trips the same structures through encode→decode→encode→decode | Host/NativeReserveBirthAuthoring.lean:26–48 (`authorAndPrepareLoadedAuthorized`), landing… | high |
| 010 | `birthAt` re-derives the entire genesis per birth request just to compare the seed identity | Host/SourceAgreementJson.lean:2463–2466 (`birthAt`), via `birthCurrent` (op 91, Host/Sour… | high |
| 011 | 1. Session advance is O(n²) twice over: per-row linear `Seed.lookup` and per-row linear `LifecycleImage.view` | Compiler/CredentialAuthorityDomainReceiver.lean:440–445 (`decodeRowFrom`), 460–467 (`deco… | high |
| 011 | 2. `Directory.slots` is a function-as-map whose every query is a linear `List.lookup` over all rows | Compiler/ResourceBirthCodec.lean:631–633 (`DirectoryImage.ofRows`: `slots id := Lifecycle… | high |
| 011 | 4. History read: `lookupNode` rescans the full node list per level of the accumulator climb | Compiler/DurableHistory.lean:190–192 (`lookupNode`), 231–241 (`verifyAt`) | high |
| 011 | 6. Carried-dispatch selection: linear scan of all accepted events with full byte-list equality | Compiler/CarriedDispatchProvenance.lean:84–93 (`select`: `image.accepted.findIdx? (fun re… | high |
| 012 | `fetch`: `eraseDups` over flat-mapped accumulator paths is O(n²) | Compiler/DurableHistoryStoreCore.lean:82 (`fetch`: `(heights.flatMap (pathOf head)).erase… | high (m… |
| 012 | `verifyAll` re-scans the entry list per height | Compiler/DurableHistoryStoreCore.lean:63–73 (`verifyAll`: `entries.find? (·.1 = height)` … | high |
| 012 | `stateAtFrom`'s `chained` check is quadratic hashing — and the `StateAt.chained` statement bakes it in | Compiler/DurableHistoryStoreCore.lean:193–195 (`stateAtFrom` runtime `if chained : ...`);… | high |
| 012 | `readPrefixes` at depth 520 rebuilds each prefix twice per level | Compiler/DurableIndex.lean:523–529 (`readPrefixes`) | high (m… |
| 012 | `ownBaseOf` compares seeds by encoding both | Compiler/DurableHistoryStoreCore.lean:227–230 (`ownBaseOf`: `seedStream.encode base.seed … | high |
| 014 | Frame decode makes three full payload copies before and during the payload decode | Compiler/FnWireGrammar.lean:593–607 (`decodeTR`, `.frame` arm; identical shape in the spe… | high |
| 014 | Hex stdout decode: two full-list reverses plus a per-octet list rebuild | Compiler/FnWireConsumer.lean:74–77 (`frameOfStdout`) and 64–71 (`lowerHexOctets?`) | high |
| 015 | `JointControlFrame.atom` re-decodes the whole cell image per call; `phase` decodes the same bytes twice | Compiler/JointControlFrame.lean:50–59 (`atom`), 61–63 (`readControl`), 74–86 (`replace`);… | high |
| 015 | `PortableContinuationManifestCodec.prefixOf`/`fromImage`/`bindImage`: five whole-log passes per manifest | Compiler/PortableContinuationManifestCodec.lean:62–80 (`prefixOf`, `pointOf`, `fromImage`… | high |
| 015 | `encodedKey`/`sortedFinsetStream`: every sort comparison re-encodes both operands | Compiler/HyperdocumentCodec.lean:177–197 (`encodedKey`, `encodedKey_injective`, `encodedO… | high on… |
| 016 | `foldSemantics`/`StoreEpoch.current` rebuild and re-hash the entire persisted-codec corpus on every reference | Compiler/DurableCheckpointCodec.lean:779-781 (`foldSemantics`), 210-218 (`persistedSchema… | high (m… |
| 016 | `CredentialSignatureAdmission` re-encodes the authority footprint twice+ and re-decodes the envelope twice pe… | Compiler/CredentialSignatureAdmission.lean:196-197 (`footprintBytes`), 216-227 (`controll… | high on… |
| 016 | `PolicyRecordCodec.stringStream` spends a base-255 varint per character | Compiler/PolicyRecordCodec.lean:57-63 (`charStream`, `stringStream`). | high. |
| 016 | Frame bytes re-derived from string literals on every encode/decode call | Compiler/RealmWellCodec.lean:113, 136, 164 (`commandFrame`, `ingressFrame`, `planFrame`),… | high. |
| 017 | `DirectoryImage.decode`'s `(rows.map Prod.fst).Nodup` gate is an O(n²) decision per rebuild | Compiler/ResourceBirthCodec.lean:733 (`DirectoryImage.decode`); same decide re-run by `de… | high |
| 017 | `DirectoryImage.used` recomputed from all rows on every rebuild | Compiler/ResourceBirthCodec.lean:626–633 (`DirectoryImage.used`, called by `ofRows`) | high |
| 017 | No-op session refresh re-reads every cell's full bytes | caller of my shard's decode — `decodeServedRowFrom` (Compiler/CredentialAuthorityServed.l… | high |
| 017 | `allocationRequest` re-encodes the whole descriptor once per birth item | Kernel/ResourceBirthController.lean:167–175 (`allocationRequest`, via `allocationFamily.r… | high |
| 017 | `Manifest.contentAddress` is an `Encodable.encode` Gödel numeral — a latent explosion if it ever runs | Compiler/SemanticManifest.lean:340–341 (`Manifest.contentAddress := ⟨Encodable.encode man… | high th… |
| 018 | Contract/customization `def`s rebuild their UTF8 `List UInt8` on every evaluation | Compiler/WorldExecutionContract.lean:11–16 (`methodTableFrame`, `freshActivationCustomiza… | high (m… |
| 020 | 7. `preparePaidVerified` scans the whole accepted history three ways and encode-compares two full intents | Kernel/ApplicationDispatchAgentPaidAuthoring.lean:284–295 (`preparePaidVerified`) | high on… |
| 020 | 9. `nullifier` and `claimNullifier` recompute their byte payloads inside their own structure literals | Kernel/ApplicationDispatchIngress.lean:156–161 (`nullifier`: `keyDigest ingress` internal… | high |
| 020 | 10. `checkCurrent` decodes the purse state twice per payer check | Kernel/ApplicationDispatchAgentPayer.lean:85 (`let some state := stateAt context.purseTas… | high on… |
| 021 | Tautological canonicality re-check re-encodes the whole enrollment ingress | `receiveVerified`, ApplicationGrainSessionEnrollmentReceiver.lean:102 — `unless ingress.c… | high |
| 021 | Lifecycle BEGIN: `command` re-derives its nonce via full-Source encode + SHAKE on every call (~4-6× per turn) | `command` / `nonce` / `sourceDigest` / `Source.canonicalBytes` (ApplicationLifecycleBegin… | high |
| 021 | Capability delegation/revocation: runtime `PhysicalShape` decision re-derives `readGuards`/`writes`; `resourc… | `readGuards` (CapabilityDelegationReceiver.lean:108-112, twin at CapabilityRevocationRece… | high |
| 021 | Enrollment intent recomputes three whole-cell physical roots that the admission already computed | `appGuard`/`manifestGuard`/`ticketGuard` (ApplicationGrainSessionEnrollmentIntent.lean:42… | high |
| 021 | Enrollment admission encodes the joint command three times for three observation reads | `checkRead` (ApplicationGrainSessionEnrollmentAdmission.lean:70-94) calls `observationMar… | high |
| 021 | `RoleAssignment.valid` is O(n·m) with byte-list comparisons | `RoleAssignment.valid` (ApplicationGrainSessionEnrollment.lean:147-150) — `role.added.all… | high on… |
| 022 | Enrollment signed command decoded twice per request | Kernel/CarriedSessionEnrollmentReceiver.lean:20–26 (`transaction`: `DeclaredResourceContr… | high |
| 023 | Cold/prefix replays thread closure-layered snapshots instead of the engine | Kernel/DurableReceiver.lean:185-198 (`replay`, `Image.restore`), with `DataSnapshot.insta… | high (m… |
| 023 | `IntentRecord.bind?` re-derives every write's root per replayed record | Kernel/DurableReceiver.lean:103-121 (`IntentRecord.bind?`) | high |
| 023 | `DurableView.view` pays an O(suffix-journal) append and linear footprint scans per served request | Kernel/DurableView.lean:64-72 (`view`: `journal := served.model.journal ++ footprint.reco… | high (m… |
| 024 | fn receivers run a second full-history replay per successful request, then linear-scan all accepted records | Kernel/FnConsumerNamespaceReceiver.lean:48–61 (`confirmReadback` → `NativeHostReplay.veri… | high on… |
| 025 | `JointReceiver.order` re-encodes the entire accepted history per joint turn | Kernel/JointReceiver.lean:29–30, 43–47 (`sourcePrefix`, `order`) | high |
| 025 | Funding checks rebuild filter/map closure chains per lane query (3× fundedCheck × 10 lanes per reserve) | Kernel/JointReceiverAdmission.lean:159, 172, 208–209 (`buildReserve`), through Kernel/Joi… | high |
| 025 | `reservedTransport`'s source gate re-encodes constants on every invocation | Kernel/JointReceiver.lean:53–62 (`reservedTransport`) | high |
| 025 | Meter-refill replay checks scan the entire journal linearly per request | Kernel/MeterRefillReceiver.lean:402–412 (`replay`), Kernel/DurableCommitProtocol.lean:163… | high |
| 025 | Meter-refill path re-derives `marker`/`request`/`event`/`nullifier`/ingress bytes ~5× per submission | Kernel/MeterRefillReceiver.lean:157–162 (`marker`), 175–194 + 198–202 (`context`, `reques… | high |
| 025 | `buildReserve` hashes the promise commitment twice | Kernel/JointReceiverAdmission.lean:196 and 203–205 (`buildReserve`) | high |
| 025 | `buildReserve` re-encodes the decision key per table entry and the write-cell list per guard | Kernel/JointReceiverAdmission.lean:158, 161–162, 192 (`buildReserve`) | high |
| 025 | `DeployedCharge.storageAt` decodes the written cell twice per charge computation | Kernel/DeployedCharge.lean:63–71 (`storageAt`, `storageCharge`), invoked from Kernel/Join… | high |
| 026 | `prepareAuthorizedLoaded` prepares the same draft twice per prepare-op | Kernel/NativeHost.lean:927 (`prepareAuthorizedLoaded`); the two preparations are `invokeR… | high on… |
| 026 | `challengeBatchLoaded`/`queryBatchLoaded`: O(b²) `++ [x]` accumulation and double decode | Kernel/NativeHost.lean:1044 (`challengeBatchLoaded`), :1069 (`queryBatchLoaded`) | high |
| 026 | `payLookupLoaded` decodes both pay ingress forms twice | Kernel/NativeHost.lean:2049 (`payLookupLoaded`) | high |
| 028 | Derived.bootstrapAdmission rebuilds the entire ordinary DataIntent to read one field | Kernel/NativeHostReplay.lean:1534–1546 (`Derived.bootstrapAdmission`), consumed by `Deriv… | high |
| 029 | `walkSuffix` re-validates the whole image per record; `walk` already goes incremental | Kernel/NativeHostReplay.lean:4752 (`walkSuffix`: `validateLoaded config next` per record)… | high |
| 032 | `PhysicalShape` runtime decide re-roots every write that `prepare` already validated | PayClaimReceiver.lean:339 (`physicalShapeDecidable`), checked at :375 (`admitDecodedNativ… | high |
| 032 | Claim `replay` scans the entire journal linearly per turn | PayClaimReceiver.lean:429-437 (`replay`, calls `DurableCommitProtocol.Snapshot.lookupReco… | high (s… |
| 032 | `signingHeader` runs the full `plan`, then the receiver's `prepare` runs it again | PayEnrolV2Receiver.lean:863-884 (`signingHeader`, calls `plan` at :877); PayEnrolReceiver… | high th… |
| 032 | v1 `prepareEnrolLegs`: grant batch prepared twice, `authorityEntries` built three times, key identity hashed … | PayEnrolReceiver.lean:688-724 (`prepareEnrolLegs`); helpers :399 (`authorityEntries`), :6… | high (w… |
| 032 | `KeyFresh` scans the whole key registry three times | PayEnrolReceiver.lean:612-617 (`KeyFresh`), evaluated per enrol at :705 | high |
| 032 | v1 memo re-parsed ~5 times per turn | PayEnrolReceiver.lean:584-589 (`parsedMemo`); call sites :596 (`subjectTakenIn`), :604 (`… | high |
| 032 | Claim `event`/`ingressBytes` re-encode the whole signed ingress per use | PayClaimReceiver.lean:384 (`ingressBytes`), :389-394 (`event`), used at :398/:402 (`charg… | high |
| 032 | v1 `priceAt` — full birth-fee descriptor built three times per turn | PayEnrolReceiver.lean:876-880 (`priceAt`), at :971 (decideEnrol), :976-977 (prepareLegs a… | high |
| 032 | Platform record decoded twice per plan | PayEnrolReceiver.lean:955 + :958 (v1 `plan`: `platformRecordAt` directly, then again insi… | high |
| 035 | `event` (full-ingress cSHAKE) recomputed ~3× per confirmed birth submit | Kernel/ResourceBirthReceiver.lean:338–344 (`event` hashes `"DREGG...EVENT/v3" ++ digestSt… | high |
| 035 | `readGuards` recomputes `writes.map DataWrite.cellId` inside its filter, and runs twice per birth | Kernel/ResourceBirthReceiver.lean:200–204 (`readGuards`), filter predicate `guard.cellId … | high |
| 035 | `requestAt`/`contextAt` re-encode and re-hash the command several times per authorization, and `authorized` b… | Kernel/SeatReceiverCore.lean:263–293 (`contextAt`: `cost := (commandCodec.encode command)… | high |
| 035 | `DeployedCharge.storageAt` computes `deltas` twice; the `.storageBytes` lane also re-hashes every post per qu… | Kernel/DeployedCharge.lean:63–66 (`storageAt`: `(deltas bridge.codec cells writes).filter… | high |
| 035 | `loadInstance`/`loadInvitation`/`loadSeat` read and decode each cell twice (present-check, then read) | Kernel/SeatStore.lean:803–826 (`loadInstance`: `present snapshot (instanceCell domain ins… | high |
| 038 | Whole-rebuild `deployedRoot` still runs on request paths beside the kept RootCache | Kernel/WorldRoot.lean:538 (`deployedRoot` = `AuthTrie.root worldDig deployedIx 256 es`); … | high (m… |
| 038 | `AuthTrie.canon` is O(n²) inside every world-root computation | Theory/AuthTrieCache.lean:640 (`canon`: `es.foldl (fun L e => dropKey e.1 L ++ [e]) []`),… | high |
| 038 | `byteBits`/`bytesBits` build trie paths as fresh List Bool churn | Kernel/WorldRoot.lean:110-112 (`byteBits`: `(List.range 8).reverse.map fun i => b.toNat.t… | high (w… |
| 038 | `inject_csrf` lowercases the whole document per render | native/mini-web/src/page.rs:128-147 (`inject_csrf`: `html.to_ascii_lowercase()` allocates… | high (w… |
| 039 | Custody `validate()` re-run 3–5× per dispatch; signing re-reads seed files and re-derives keys per slot | agent_api_lifetime_custody_v3.rs:64-142 (`LifetimeCustodyV3::validate`, called at :145 `s… | high |
| 039 | `write_frame` copies every payload; the pty pump adds a second copy per chunk | mini-web/src/ws.rs:113-124 (`write_frame`: `t.as_bytes().to_vec()` / `b.clone()` before `… | high |
| 040 | `inspect_saved` hex-encodes and re-parses the whole retained reply on every InspectV3 | agent_api_lifetime_server_v3.rs:794 (`serde_json::from_slice::<Reply>` of the retained de… | high |
| 040 | Canonical-HTTP decoded byte-by-byte with `from_str_radix` instead of the shared unhex | `authorize_once` (agent_api_native.rs:755–764: `as_chunks::<2>()` + `u8::from_str_radix` … | high |
| 042 | `Start`/`Stop` handlers fork `systemctl` 3–4 times per op | native/spk-host/src/broker.rs:1153-1177 (`Request::Start` / `Request::Stop` handlers) | high (c… |
| 044 | `lookup` double-writes the same payload to disk with an fsync each | native/spk-host/src/dispatch_fence.rs:404 (`write_new(&directory, "frame.bin", &reply)`),… | high (m… |
| 044 | `refusal_words` decodes Lean's entire hex detail to keep 200 chars | native/spk-host/src/dispatch_fence.rs:345–359 (`refusal_words`) | high |
| 046 | `session_alive` scans every process on the box inside a 20 ms poll loop | native/spk-host/src/fixture_os.rs:102-116 (`session_alive`), hot use at fixture_os.rs:641… | high |
| 046 | START-wait polls spawn a `systemctl` subprocess every 500 ms | native/spk-host/src/grain.rs:1236-1270 (`start_inner` wait loop) calling `unit_probe` (gr… | high (m… |
| 046 | Active agent-route custody is hex-decoded, JSON-parsed and validated three times per START | native/spk-host/src/grain_agent_route.rs:320 (`retained` — parse + `shape` + `custody`-va… | high |
| 049 | `decode_chunked` re-parses the whole chunk stream after every 8 KB read | native/spk-host/src/http_entrance.rs:657-704 (`decode_chunked`), driven by the retry loop… | high (m… |
| 050 | `check_pin()` re-reads and re-hashes the pinned config on every `invoke`/`tool`, and `pinned_management` re-p… | dispatch_native.rs:440-459 (`check_pin` — called at the top of every `tool_until` :494 an… | high |
| 052 | 2. Four `audit_stopped_manager_checked` per Stopped STOP where two suffice | lifecycle_v3_stop_service.rs:1249, :1269 (`run`), :440, :496 (`prepare_report`) | high on… |
| 052 | 3. One Lean-host process spawn per artifact step; three inspect spawns are provably redundant | dispatch_native.rs:518 (`PrivateOperator::tool`: `Command::new` per call, `run_pinned` ad… | high th… |
| 053 | 3. Operation-id ledger re-reads and revalidates its whole history per allocation, then fsyncs twice | operation_ledger.rs:85–102 (`allocate_operation_id`) | high |
| 053 | 5. `/proc/self/{uid,gid}_map` + overflow ids re-read from the filesystem on every provenance check | namespace_identity.rs:64–72 (`IdView::current`) called from `unchanged` (89–91) on every … | high on… |
| 053 | 7. Channel-loss reap loop polls `waitpid` at 10 ms granularity, up to 5 s | resident_privilege.rs:291–313 (`impl Drop for Client`) | high on… |
| 056 | `collect_tree` re-opens every path from the root: O(nodes × depth) syscalls per walk | native/spk-host/src/shared_data.rs:478 (`collect_tree`) calling shared_data.rs:349 (`open… | high |
| 056 | `fresh_nonce` opens `/dev/urandom` per call | native/spk-host/src/web_socket.rs:115-119 (`fresh_nonce`), called from `StreamLease::begi… | high (t… |
| 056 | `ContinuityTip::follows` validates both sides again inside an already-verified reply | native/spk-host/src/stream_continuity.rs:96-99 (`follows` calls `self.validate()?` + `min… | high |
| 060 | Byte-at-a-time socket reads in `read_line_bounded` on the foreground tool path | control.rs:569 (`read_line_bounded`), called from control.rs:699 (`receive_tool_completio… | high |
| 060 | Concierge pass spawns 3+ `mini` children (signed Host turns) every 5 s even when idle | concierge.rs:493–537 (`step`), cadence at concierge.rs:976–991 (`main`, `serve` default 5… | high on… |
| 060 | Concierge replays the entire append-only journal every pass | concierge.rs:282–299 (`Journal::open`), called from `step` (concierge.rs:511) on every ti… | high |
| 060 | Terminal events serialized twice per send (size check + write) | control.rs:255–270 (`try_tool_event_for`), control.rs:293–312 (`try_terminal_event_for`) | high |
| 061 | `serve_git` polls a nonblocking listener with a 20 ms sleep | gitweb_worker.rs:359–408 (`serve_git` accept loop, sleep at :408) | high |
| 061 | hermes-room journal: full re-parse per step tick; reopen + fsync per appended line | hermes_room.rs:104–115 (`Journal::open`), 172–185 (`Journal::append`), 585 (`step` re-ope… | high (m… |
| 061 | Git bodies/replies travel as hex strings through the controller JSON layer | gitweb_worker.rs:385–387 (`bodyHex: hex(&request.body)` per forward), 261–267 (`unhex` of… | high |
| 061 | Hermes failed-turn records serialize the whole journal twice | hermes_outcome.rs:37–52 (`retain_failure`, `close_failure` — `serde_json::to_vec(journal)… | high |
| 062 | Homelab placement polls the scheduler over fresh connections every 100 ms per prompt | native/grain-runtime/src/homelab.rs:58-101 (`Plan::wait`), with `scheduler::request` (inf… | high on… |
| 065 | Provider path re-observes the same grains ~5–8× per LLM round trip | native/grain-runtime/src/main.rs — `provider_reserve` (9207 `self.query()`, 9334 `query_a… | high |
| 065 | Meter/settle path reads the same retained evidence twice back-to-back | native/grain-runtime/src/main.rs — `provider_meter_quote_inner` (reads request+response+h… | high |
| 065 | `provider_replay` runs 2–3× per provider request; `exact_body` re-parsed per call | native/grain-runtime/src/main.rs — calls at 9137 (`provider_prepare`), 9193 (`provider_re… | high |
| 065 | `provider_native_profile` spawns `mini profile` per call for static pinned data | native/grain-runtime/src/main.rs:9453–9467 (`provider_native_profile`), called at 9141 (`… | high |
| 066 | `workspace_root()` re-validates the workspace (6 stats + read + JSON parse) 3–4× per workspace tool call | main.rs:11057–11060 (`workspace_root` → `validate_resource_workspace_record` 3425: 5 `sym… | high |
| 067 | `tool_catalog` re-hashes the whole Host image and re-verifies every born resource on every prompt | main.rs:14274 (`tool_catalog`), esp. 14292 `sha256_file(&self.config.host)`, 14304–14320 … | high (c… |
| 067 | ~8 full-journal fsync commits per prompt | `hermes_session_inner` saves at 14755, 14833, 14886, 14959/14984, 14996, 15010, 15198, 15… | high on… |
| 068 | Worker stop polls the process table by forking `/bin/ps` up to 33 times, and kills via a systemd spawn per 50… | native/grain-runtime/src/main.rs:17634 (`group_has_live_member`), used by `stop_and_reap_… | high |
| 068 | `prove_worker_unit_stopped` re-proves controller liveness on each of its two observations | native/grain-runtime/src/main.rs:17582–17628, `observe` closure calls `prove_controller_u… | high |
| 069 | Oracle/application-API request body ping-pongs bytes → hex → JSON → re-serialize → hex again, with a per-byte… | native/grain-runtime/src/oracle_tools.rs:84–96 (`http`, esp. body_hex loop with `write!(&… | high |
| 069 | MCP broker acceptor busy-polls at 50 Hz forever | native/grain-runtime/src/mcp.rs:101–124 (`start_broker`'s acceptor thread; `set_nonblocki… | high |
| 069 | DeadlineRead re-arms the socket read timeout on every 8 KiB buffer fill | native/grain-runtime/src/mcp.rs:454–466 (`DeadlineRead::read` calls `self.stream.set_read… | high |
| 069 | Per-gitweb-call catalog round trip in the stdio edge | native/grain-runtime/src/mcp.rs:518 (`serve_stdio`, `tools/call` for `mini_gitweb_read`/`… | high (t… |
| 070 | Request body hex-encoded into the key-broker JSON frame | native/grain-runtime/src/provider.rs:1597-1603 (`forward_once`) | high |
| 071 | `resolve_guarded_provider_pending` re-reads every input 2–3× inside one `inspect`, then runs `inspect` twice | native/grain-runtime/src/provider_resolution.rs:196–219 (`inspect` input loop + `BASIC` l… | high (t… |
| 072 | `journal_digest` serializes the ENTIRE Journal per projection — and `reconciliation_log` is unbounded | native/grain-runtime/src/quiescence.rs:159–161 (`journal_digest`), called from `project` … | high |
| 072 | `Receiving::validate` re-derives the full `transition`, and whole-struct `hash` comparisons re-serialize ~2 M… | native/grain-runtime/src/resident_completion.rs:234–248 (`Receiving::validate` — line 243… | high |
| 072 | `stale_query_with` reads and hashes the same retained artifacts up to 3× | native/grain-runtime/src/query_observation.rs:96–110 (`stale_query_with`) | high |
| 073 | select() serializes the whole queue to pretty JSON once per admitted request | native/grain-runtime/src/resident_requests.rs:328 (`select`) | high |
| 073 | select() is O(pending × entries × members) deep Value comparisons every poll cycle | native/grain-runtime/src/resident_requests.rs:284, 296-297, 309-312, 316-323, 338-340 (`s… | high (p… |
| 073 | One delivery re-validates and re-hashes the same immutable record ~4-8 times | native/grain-runtime/src/resident_delivery.rs — `validate_pending`:384, `admits_room_call… | high (t… |
| 073 | bound_delivery parses the resident state twice per call | native/grain-runtime/src/resident_delivery.rs:619-620 (`bound_delivery`) | high (t… |
| 073 | prove_ordinary_final_reply reads and hashes ~21 files per legacy delivery | native/grain-runtime/src/resident_delivery.rs:747-769 (`prove_ordinary_final_reply`) | high (b… |
| 074 | `mini_answer_await` re-derives the whole pending-await list per answer — up to ~11 host turns for one write | native/grain-runtime/src/resource_tools.rs:1271 (the `mini_answer_await` arm) calling `pe… | high |
| 074 | Resident idle loop pays ≥4 signed host queries every pass even when nothing changed | native/grain-runtime/src/room_resident.rs:390 (`main` loop, default `interval_seconds` 30… | high on… |
| 074 | `mini_doc_show` and `mini_room_status` each cost two host turns where one would do | native/grain-runtime/src/resource_tools.rs:1100 (`doc links {doc}` spawned after `doc sho… | high |
| 074 | `require_workspace_volume` stats every file in the workspace on every sandboxed worker launch | native/grain-runtime/src/sandbox_tools.rs:247-268 (`require_workspace_volume` / `allocate… | high |
| 074 | `is_room_tool` rebuilds the entire 11-tool JSON schema catalogue — twice per tool call | native/grain-runtime/src/resource_tools.rs:829-831 (`is_room_tool` → `room_tool_specs()`)… | high |
| 075 | `current()` re-reads, re-parses and re-hashes the controller registration on every manager command | native/grain-runtime/src/systemd_manager.rs:280 (`current`) → `load` at 199–262; `custody… | high |
| 075 | `lifetime_environment` calls `current(task)` twice per worker init | native/grain-runtime/src/systemd_manager.rs:373 and 389 (`lifetime_environment`) | high |
| 076 | `NativeCall.acceptsReply` decodes the reply after already byte-comparing it | Compiler/AuthenticatedColumnPlan.lean:318–322 (`NativeCall.acceptsReply`) | high. |
| 076 | Bit-gadget construction recomputes `2^i`-style field constants and full digit tables per limb | Compiler/AirRange.lean:144–146 (`weightedSum`: `cst ((2 : F) ^ (i : ℕ))` per bit position… | high (m… |
| 076 | `finUnaryCodec` is a value-proportional unary encoding on a 2²⁵⁶ domain | Compiler/AuthenticatedColumnPlan.lean:866–871 (`finUnaryCodec.encode := List.replicate va… | high. |
| 076 | Keystone-witness `decide` examples reduce nested DSL terms in the kernel (elaboration-time only) | e.g. Compiler/AirModularView.lean:662–683 (four `set_option maxRecDepth 100000 … by decid… | high. |
| 077 | `collect` rebuilds the resolved-key list per node | Compiler/PolicyComponentResolution.lean:139–140 (`collect`) | high (m… |
| 079 | `verifySshsig` forks the Host per SSHSIG check, bypassing the coprocess built to prevent exactly that | Compiler/CredentialSignatureIO.lean:143–163 (`verifySshsig`, `IO.Process.output` at :158) | high |
| 079 | `prepare` re-derives the same footprint bytes, request bytes and envelope decode two times each | Compiler/CredentialSignatureAdmission.lean:277–296 (`prepare`); `footprintBytes` inside `… | high |
| 079 | `verifySignature` re-encodes the request twice per receiver admission to re-derive an already-proven equality | Compiler/CredentialSignatureAdmission.lean:572–575 (`verifySignature`, `decide (encodeReq… | high (c… |
| 080 | `appendRestored` encodes the delta frame twice and walks the whole witness list per input | Compiler/GenericSimplexIO.lean:502–514 (`appendRestored`), the `some (⟨…, old.length + (d… | high |
| 080 | Birth source re-derives the grain nonce / marker / canonical bytes ~6× per birth | Compiler/GrainResourceBirthController.lean:100–106 (`Source.grainNonce`), :113–118 (`Sour… | high |
| 080 | Legacy content reads re-hash constant digests and decode–re-encode–compare per query | Compiler/LegacyContentCarry.lean:337–338 (`digest`), :402 (`elementArchiveName`), :446 (`… | high (r… |
| 080 | COMMIT-certificate ingest rebuilds `prior.witnesses ++ ws` per incoming witness | Compiler/GenericSimplexIO.lean:843–845 (`receiveCommitment`, the `added` fold) | high |
| 081 | `ObjectiveBendCombinedResult.prepare` encodes every plan effect to bytes just to take a length | Compiler/ObjectiveBendCombinedResult.lean:108 (`prepare`, `producedBytes`) | high th… |
| 081 | `ObjectiveBendContract.close`/`missing`/`names` are O(n²) row scans per chain fix | Compiler/ObjectiveBendContract.lean:52-57,118,120-129 (`get?` = `List.find?`, `missing`, … | high on… |
| 081 | `NativeKernelPlan.publicPrefixExactCheck` is quadratic via `List.getD` and rebuilds `finRange` per call | Compiler/NativeKernelPlan.lean:270-272 (`finAll`, `(List.finRange n).all check`), 301-307… | high on… |
| 082 | packageLaw recompiles every package law into a Pred on every judged write | Compiler/ObjectiveBendLaw.lean:124 (`packageLaw`), called from Kernel/ObjectRecord.lean:3… | high |
| 082 | builtinModule re-parses the built-in source text on every context build | Compiler/ObjectiveBendElaborate.lean:2008–2012 (`builtinModule`) called from `context` :2… | high |
| 082 | decodeModule / context / emitDecl accumulate with `xs ++ [x]` | Compiler/ObjectiveBendElaborate.lean:245–250 (`decodeModule`: `laws := laws ++ [...]`, `d… | high |
| 083 | `fetchPolicySource`/`loadPolicy` re-encode and re-hash each policy record on every fetch; the decoded record … | Compiler/CanonicalCellRegistry.lean:1134 (`fetchPolicySource` → `LoadedPolicySource.canon… | high |
| 083 | `ObjectiveBendResultAdapter.prepare` encodes the result value 3–4×, decodes it, and re-encodes the plan just … | Compiler/ObjectiveBendResultAdapter.lean:224 (`prepare`), :142–148 (`decodeData` ends wit… | high |
| 083 | `readNatural` turns every decoded Nat into a decimal String and parses it back | Compiler/ObjectiveBendResultAdapter.lean:84 (`readNatural`: `takeWhile`, `String.fromUTF8… | high |
| 083 | `ObjectiveBendPlanAdapter.group` is O(n²) with two list rebuilds per effect | Compiler/ObjectiveBendPlanAdapter.lean:67 (`group`: `prior.find?` + `prior ++ [next]` in … | high |
| 083 | `indexOf` scans targets with O(n) list indexing per probe, per scalar | Compiler/ObjectiveNativeScalarBinding.lean:69 (`indexOf`: `(List.finRange command.targets… | high |
| 084 | `serve` moves the whole continuity request/response through `List UInt8` | Compiler/ReceiptContinuityIO.lean:258–267 (`serve`) | high |
| 085 | `capabilityChecks` evaluates all 11 admission components even when the first fails | Compiler/RefusalReason.lean:294 (`capabilityChecks`), :309 (`capabilityRefusal`) | high |
| 085 | `Ground.recorded` journal lookup is a linear scan of the journal list | Compiler/ServedBasis.lean:349 (`Ground.recorded`), :415 (`replayOf`); scan is Kernel/Dura… | high (m… |
| 085 | `SigningKeyCommitment.digest` rebuilds its domain-separation tag per call | Compiler/SigningKeyCommitment.lean:14 (`tag`), :16 (`digest`) | high (m… |
| 086 | Pred law evaluation per incidence: string-keyed linear-scan state, rebuilt per eval | Kernel/AgentGrain.lean:113 (`transitionPolicy`), :162 (`refillPolicy`), :177 (`policy`), … | high (r… |
| 086 | Holdings cell canonicalized and decoded twice per ending turn | Kernel/ActivitySeatEnd.lean:81–82 (`join`: `(SeatStore.readHoldings snapshot config.domai… | high (b… |
| 086 | StreamCell digest helpers re-derive their customization strings per call | Compiler/StreamCell.lean:102 (`payloadCustomization`, nullary `def` rebuilding `"DREGG.ST… | high on… |
| 087 | `Source.command` recomputed ~8× per recovery flow; each call re-encodes the signed report and double-hashes | Kernel/ApplicationFailedStartRecoverySource.lean:135-149 (`Source.command` — nonce hash o… | high |
| 087 | `event`/`stableNullifier` structure literals re-encode the full ingress twice per construction | Kernel/ApplicationFailedStartRecoveryIngress.lean:62-68 (`event`: `eventId` hash over `in… | high |
| 087 | `ApplicationFailedStartRecoveryCore.charge`: per-lane arms re-encode the ingress; `DeployedCharge.mismatch` q… | Kernel/ApplicationFailedStartRecoveryCore.lean:88-102 (`charge`); consumer Kernel/Deploye… | high |
| 088 | Claim admission re-derives `command` (full source encode + SHAKE) ~7× per claim | Kernel/ApplicationLifecycleClaimCurrent.lean:120–147 (`checkRead`, and `observationReques… | high |
| 088 | `CompletionCore.intent` builds `ingress.source.command` three times | Kernel/ApplicationLifecycleCompletionCore.lean:109–133 (`intent`) | high |
| 088 | Per-request rebuild of the full app-policy AST plus structural `Pred` equality | Kernel/ApplicationGrain.lean:170–230 (`transitionPolicy`, `policy`, `managedPolicy`, `pac… | high |
| 088 | `readState` does four separate DFinsupp lookups on the dispatch path | Kernel/ApplicationGrain.lean:82–84 (`readState`); reached per request via `ApplicationDis… | high |
| 088 | `markersCurrentOf` / nullifier builders recomputed per pass — minor | Kernel/ApplicationLifecycleBeginV3Admission.lean:68–110 (`markerNullifiersOf`, `markersDe… | high (t… |
| 089 | Completion V2 `intent`/`charge` rebuild the whole ingress per field and per charge lane | Kernel/ApplicationLifecycleCompletionV2Core.lean:93 (`charge`) and :109 (`intent`) | high |
| 089 | `Source.command` re-encodes the full physical report on every call, and callers call it 6–8× per admission | Kernel/ApplicationLifecycleCompletionV2Source.lean:144 (`Source.command`, same body in V1… | high |
| 089 | Completion route decodes the full payload 2–3× per request in Host/Main | Host/Main.lean:1752–1758 (`applicationLifecycleCompletionSubmitSession`) and :1777–1787 (… | high |
| 089 | `validFor` runs twice per admission and re-encodes the prospective manifest each time | Kernel/ApplicationLifecycleCompletionV2Report.lean:117 (`Report.validFor`); callers Kerne… | high |
| 089 | `Lookup.verified` re-encodes a just-decoded ingress and linearly scans all accepted records | Kernel/ApplicationLifecycleCompletionV2Lookup.lean:26 (`verified`); V1 twin Kernel/Applic… | high |
| 089 | `CreatedHistory.select` decodes the same completion event bytes twice | Kernel/ApplicationLifecycleCreatedHistory.lean:133 (`decodeSelected probe.event.canonical… | high |
| 090 | `Source.command` recomputed at every call site; each call re-hashes the whole physical report | Kernel/ApplicationLifecycleRetryCompletionV4Source.lean:144-158 (`Source.command`; nonce … | high |
| 090 | `Report.validFor` re-derives and re-encodes the prospective manifest; full structural ingress equalities, run… | Kernel/ApplicationLifecycleRetryCompletionV4Report.lean:117-144 (`validFor`; manifest re-… | high |
| 090 | Lookup verbs: per-call decode→re-encode→SHAKE, full byte-list equality, linear scan | Kernel/ApplicationLifecycleRetryV4Lookup.lean:32-44 (`select`: `findIdx?` at 33, `record.… | high |
| 090 | `lookupVerified` double-encodes two full IntentRecords (each encode evaluates all 10 charge lanes) | Kernel/ApplicationShareIssueGrainLookup.lean:50-52 (`DurableReceiverCodec.intentStream.en… | high |
| 090 | `authorizeLeg` computes `step` twice per leg | Kernel/ApplicationLifecycleRetryCompletionV4Policy.lean:165-166 (`let context := step …; … | high (d… |
| 090 | `CreatedHistory.select` reads and fully decodes the same record twice | Kernel/ApplicationLifecycleRetryCompletionV4CreatedHistory.lean:130-136 (probe `reader.at… | high |
| 091 | `loadBirth` dependency resolution re-run 3–4× per birth item by the neutral/rooted partition | Kernel/BirthExportAdmission.lean:93–106 (`isNeutral`, `rootedItems`, `neutralItems`), con… | high |
| 091 | `existingAddresses` re-encodes and re-hashes every policy record once per dependency address | Kernel/BirthCandidateAdmission.lean:28–29 (`existingAddresses`) | high |
| 091 | `view` rebuilds the identical `factoryRequest` for the old and new state of every item | Kernel/BirthExportAdmission.lean:70–85 (`view`), called twice per item at :143–144 in `ch… | high |
| 091 | `PreparedGrainBirth.readGuards` rebuilds the write-cell map inside the filter (adjacent to shard, same patter… | Kernel/ResourceBirthController.lean:874–876 (`PreparedGrainBirth.readGuards`) | high (r… |
| 092 | `step prepared` rebuilt per reference; each build runs `project` twice, and `project` re-encodes the command,… | Kernel/CapabilityDelegationController.lean:506 (`step`), 480-487 (`project`), 517-523 (`p… | high |
| 092 | Resource-submit charge cluster: ten-lane `Charge` re-encodes the operation and canonical post per lane, and `… | Kernel/AuthorizedResourceCharge.lean:170-191 (`operationalChargeOf`), 218-225 (`exactChar… | high |
| 092 | All three capability controllers build each `request` from scratch ≈4 command encodes + 3 hashes per construc… | Kernel/CapabilityRenounce.lean:114-150 (`commandBytes`, `argsDigest`, `effectsDigest`, `r… | high |
| 092 | `batchSourceRequest` computes the base request's `argsDigest` and `effectsDigest` and then discards both | Kernel/CanonicalResourceEffect.lean:330-337 (`batchSourceRequest`), 146-165 (`RequestCont… | high |
| 092 | `sourceArgsBytes` re-encodes the whole descriptor and the whole batch per source position (quadratic in batch… | Kernel/CanonicalResourceEffect.lean:313-328 (`sourceArgsBytes`, `sourceArgsDigest`); `Des… | high (c… |
| 094 | `ContentResource.project`: four whole-store encodes plus sorts, per write | Kernel/ContentResource.lean:1828 (`project`), calling `contentBytes` (1722), `sharedNames… | high |
| 094 | `prepareCell`: the patch is executed three times per write | Kernel/ContentResource.lean:1646 (`prepareCell`); Theory/CellState.lean:189 (`validate`) … | high |
| 094 | `documentOrder` / `elementCount`: whole-store support scan + per-element lookups per render and per edit | Kernel/ContentResource.lean:914 (`elementCount`), 918 (`treeFuel`), 953 (`walk`), 959 (`d… | high |
| 094 | `resolveRange`/`openingHolds`: per-atom lookups, duplicate endpoint scans, `List.range` garbage | Kernel/ContentResource.lean:2139 (`resolveRange`), 2146 (`alive := run.atoms.map (slotLiv… | high |
| 094 | `renderSnapshot` / `renderLive`: two lookups per pin where one suffices | Kernel/ContentResource.lean:2229 (`renderSnapshot`: `opening.pins.all (pinHolds ...)` the… | high |
| 094 | Constant digests re-hashed per call; `referenceOf` re-encodes `opening.descriptor` three times | Kernel/ContentResource.lean:729 (`contentDigest`), no-arg defs 733-752 (`transcludeRelati… | high |
| 095 | `lawLeaf`/`rangeLeaf`/`castAliasLeg`/`lawRefusal` evaluate `step` three times per leg | Kernel/DeclaredResourceController.lean:749 (`lawLeaf`), :811 (`rangeLeaf`), :830 (`castAl… | high |
| 095 | `DeclaredResourceScalar.request` encodes the whole command three times per call | Kernel/DeclaredResourceScalar.lean:193 (`request`), with `argsDigest` :164, `effectsDiges… | high |
| 095 | Charge closures re-encode the signed ingress per lane query | Kernel/DeclaredResourceController.lean:2334 (`sourceChargeFrom`), :2318 (`legacySourceCha… | high on… |
| 095 | `representsCheck`/`cellOk`: whole-cell encode + byte-list compare + two full decodes per cell | Kernel/DeployedRepresentsCheck.lean:70 (`cellOk`), :87 (`representsCheck`); called from C… | high |
| 096 | FieldClosure.check re-scans field values quadratically and re-enumerates the whole Store twice, per command | Kernel/FieldClosure.lean:82 (`firstUndeclared`), :78 (`candidates`), :266 (`check`); comp… | high |
| 096 | FieldClosure.Closed decided by walking the whole store support, twice per command | Kernel/FieldClosure.lean:186 (`Closed`), :189 (`closedDecidable`), :176 (`KeyDeclared`), … | high |
| 096 | Door.checkPoke re-encodes the next state and rebuilds the write list 4×; claimOutput computed twice | Kernel/Door.lean:114 (`checkPoke`), specifically :147, :150, :152, :154 (`d.encodeState s… | high |
| 096 | DocumentHistory.predecessor zips the whole key list per call; documentRows calls it per row → O(n²) | Kernel/DocumentHistory.lean:57 (`predecessor`); caller Kernel/ResidentContextProjection.l… | high |
| 097 | checkHistoricalPolicy fully validates every accepted record, twice-decoded, on every consumer submit | Kernel/FnConsumerOperation.lean:634-645 (`checkHistoricalPolicy`), via `originalBindingGr… | high |
| 097 | gatewayRequest computes signingBytes 4× per request, and Prepared.wanted re-runs gatewayRequest at every use | Kernel/FnConsumerFrontierGateway.lean:70-102 — `gatewayRequest` calls `signingBytes propo… | high |
| 097 | Validation encodes whole payloads just to check lengths — and re-validates the same evidence at every layer | Kernel/FnConsumerOperation.lean:310 (`PortableInbox.valid`: `(portableInboxCodec.encode i… | high |
| 097 | Intent construction re-encodes the ingress ~9× per event19/event20 write | Kernel/FnEmptyPollAdmissionAtV2.lean:83-98 (`Accepted.intent` calls `transactionId ingres… | high |
| 098 | FnReplyConsumption.evaluate/decide: two O(accepted-history) heavy scans per A-reply submit | Kernel/FnReplyConsumption.lean:321–334 (`evaluate`), 281–317 (`decide`), 243–271 (`origin… | high |
| 098 | FnOriginOutbox.originalPrepared: ~5 megabyte-scale passes + 3 SHAKEs per accepted record in selectUniqueParent | Kernel/FnOriginOutbox.lean:184–206 (`originalPrepared`), 244–255 (`selectUniqueParent`), … | high |
| 098 | FnReplyConsumption.check parses and canonically re-renders the Q source three times per call | Kernel/FnReplyConsumption.lean:102–106 (`Report.result`), 108–134 (`check`), 125/132/134 … | high |
| 098 | GenericSimplex.validBlock: quadratic rescan of the checked history, re-invoked ~4× per leader action | Kernel/GenericSimplex.lean:114–117 (`validBlock`), 107–108 (`applicationHistory` recomput… | high (w… |
| 098 | GenericSimplex.count: O(received²) via voteEquivocator inside the filter, called many times per pass | Kernel/GenericSimplex.lean:131–133 (`count`), 129–130 (`voteEquivocator` — its own filter… | high (p… |
| 098 | FnSelectedPollReleaseLink.select zips the whole accepted history per poll | Kernel/FnSelectedPollReleaseLink.lean:24–30 (`select`: `(target.image.accepted.zip verifi… | high |
| 098 | event/charge twins in the selected-poll path duplicate the ingress encode | Kernel/FnSelectedPollCoverage.lean:162–168 (`event`: `ingressCodec.encode ingress` at lin… | high |
| 099 | Branch request/step/config re-derived from scratch at every use (the `charge` bug's sibling) | Kernel/GrainResourceBirthAdmission.lean:140-160 (`branchRequest`), :162-173 (`branchIdent… | high |
| 099 | `project` encodes every grain target per branch — each target twice — plus the whole command | Kernel/GrainResourceBirthAdmission.lean:179-229 (`project`), specifically :217-229 (`.inr… | high |
| 099 | `physicalShapeDecidable` rebuilds `writes`/`readGuards` ~6× per evaluation; `writes` re-derived at 6+ sites o… | Kernel/GrainResourceBirthTransaction.lean:467-496 (`PhysicalShape`, `physicalShapeDecidab… | high |
| 099 | `policySourceGuards` filter re-derives the whole write set per guard; `PolicyGuardShape` decidability re-runs… | Kernel/GrainResourceBirthAdmission.lean:879-897 (`policySourceGuards`), :927-966 (`Policy… | high |
| 099 | Per-target read legs re-encode the whole grain command (and re-hash the marker) for every target | Kernel/GrainResourceBirthAdmission.lean:758-779 (`readRequest`), :781-794 (`readPreparati… | high |
| 099 | `rawLeg` derives `targetPatch` twice per grain incidence and `grainCommand` four times in one arm | Kernel/GrainResourceBirthTransaction.lean:146-208 (`rawLeg`), specifically the `.inr inde… | high |
| 099 | `SignedShape`/`SourceBound` decidability re-encodes source, birth descriptor and command that `decodeIngress`… | Kernel/GrainResourceBirthAdmission.lean:86-105 (`SignedShape`, `signedShapeDecidable`), e… | high |
| 099 | `layout` re-derives `grainCommand` per incidence query; `prepareTuple`'s injectivity check pays it pairwise | Kernel/GrainResourceBirthTransaction.lean:94-122 (`layout`), :360-381 (`prepareTuple`, in… | high |
| 099 | `grainCommand`/`grainNonce`/`canonicalBytes` are uncached derivations under the entire admission path | Compiler/GrainResourceBirthController.lean:100-118 (`Source.grainNonce`, `Source.grainCom… | high on… |
| 100 | `readJob` re-reads all 8 declared fields, and callers invoke it 2+ times per command | Kernel/JobMoney.lean:124-127 (`readJob`) with `readField` :119-122 | high |
| 100 | `Control.wellFormed` runs O(n²) `eraseDups` over the ever-growing decisions list on every gate call | Kernel/JointControlCell.lean:66-68 (`wellFormed`: `(c.decisions.map Prod.fst).eraseDups.l… | high |
| 100 | `commit`/`delta` apply `plan.batch.apply book` three-plus times per money command | Kernel/JobMoney.lean:249-256 (`delta`, `aggregateDelta`), :281-284 (`commit`) | high |
| 100 | `chargedBytes` re-encodes the entire message through the List codec on every send | Kernel/Inbox.lean:507-508 (`chargedBytes`), :519 (`storageDeposit`); big values `widestId… | high |
| 100 | Invitation `Registry` is three linear lists scanned per contract verb | Kernel/Invitation.lean:87-95 (`Registry.instance?`, `invitation?`, `fresh`), :99-107 (`mi… | high on… |
| 100 | Inbox `codec`/`frame` are no-argument defs rebuilt on every encode/decode | Kernel/Inbox.lean:416-419 (`frame`, `codec`, `encode`, `decode`); same pattern at Kernel/… | high on… |
| 101 | `commitment` re-hashes the full declaration many times per leg (eta-expanded closures in `plan`) | Kernel/JointPromiseAuthorization.lean:71 (`commitment`), :67 (`statement`), :75-82 (`want… | high |
| 101 | `authorize` recomputes `step` (4× `commonSlots`, 2× full command+statement encodes) per leg | Kernel/JointPromiseAuthorization.lean:179-200 (`authorize`: `lawConfig := config …` at :1… | high |
| 101 | `scalarSlots` builds the O(n²) pair-delta section twice per law evaluation, with linear gets inside | Kernel/LawView.lean:118-123 (`view`/`admits` — `view t pre pre` AND `view t pre t.post`),… | high |
| 101 | `Reservation.footprint` rebuilt per element inside `Compatible`'s runtime decide | Kernel/JointReservation.lean:52-53 (`Reservation.footprint`), :58-67 (`Compatible` + its … | high |
| 101 | `heldCharge` computed twice in one gate, plus filter/map/aggregate allocations each time | Kernel/JointReservation.lean:71-72 (`heldCharge` — `table.filter … />.map …` then `Charge… | high |
| 102 | `ordinaryOther` rebuilds `authorityCells session` for every target of every suffix record | Kernel/NativeReserveContinuity.lean:115 (inside `ordinaryOther`), :47 (`authorityCells`) | high |
| 102 | `observesWhole` builds the full filtered set then checks `.Nonempty` | Kernel/NativeObservationController.lean:900 (`observesWhole`, `filter … .Nonempty` at :90… | high (w… |
| 102 | `exactHardReserve` filters the target list twice with complementary predicates | Kernel/NativeProviderHistory.lean:144 and :155 (`reserve.targets.filter (·.target == prov… | high |
| 103 | `jamAtom` / `ofJamAtom` / `natBytes`: quadratic big-Nat byte conversion plus a full re-jam per noun slot cros… | Kernel/NockProgramCell/Sample.lean:70–72 (`cordValue`), 83–91 (`natBytesAux`/`natBytes`/`… | high |
| 103 | Sample path reads every slot twice per run (`overMax` pass, then `sampleOf`), and op 133's `readOf` is a nest… | caller Kernel/ResourceTransaction.lean:1400–1404 (`checkProgram`: `E.overMax (programSamp… | high |
| 103 | Sample keys re-encoded from Strings on every build: `cord slot.key` per slot, `targetKey i` = `targetPrefix +… | Kernel/NockProgramCell/Sample.lean:273–278 (`targetKey`/`targetEntries`), 291–301 (`sampl… | high |
| 104 | 5. `purseAssets` scans the entire Book's balance support per sweep | Kernel/ObjectiveActivity.lean:2463–2472 (`purseAssets`, `sweep`) | high (p… |
| 104 | 7. `birthTransaction` (full input re-encode + cSHAKE) recomputed per birth | Kernel/ObjectiveActivity.lean:2696–2700 (`birthTransaction`), computed at 2868–2869, agai… | high |
| 105 | `abandon` derives `abandonCharges` twice: a whole-Book apply plus a `sweep` support-walk-and-sort per derivat… | `abandon` :3693 (`postings book (abandonCharges ...)`) and :3696 (`posted.batch = abandon… | high. |
| 107 | `loadMethod` re-reads and re-decodes the whole package cell on every frame entry (and every send) | Kernel/ObjectiveCall.lean:1162 (`exec`, `.enter`), :1447 (`deliverable`), :464–479 (`load… | high |
| 107 | `methodOf`'s annotation closure recomputes `dataAnnotations` over the whole args on every annotation query | Kernel/ObjectiveCall.lean:413–419 (`methodOf`, the `AnnotatedTerm` literal) | high |
| 107 | `invokeBatch` recomputes its own parts and applies the batch's operations to the Book twice per turn | Kernel/ObjectiveCall.lean:2312–2315 (`invokeBatch`), :2065–2071 (`Mail.deregistrations`),… | high on… |
| 107 | `controlSlot` reads the same slot cell three times per control | Kernel/ObjectiveCall.lean:1598–1627 (`controlSlot`) | high |
| 107 | Send args are encoded, then decoded back, within one turn; `postMail` builds the message twice per send | Kernel/ObjectiveCall.lean:1543–1547 (`messageOf`: `dataBytes out.args`), :1555–1556 (`pos… | high |
| 108 | deliverMessage re-reads the inbox generation cursor ~7× and the inbox cell bytes 3× per delivery | Kernel/ObjectiveSend.lean:406–440 (`deliverMessage`), helpers at Kernel/ObjectiveActivity… | high |
| 108 | deliveryBatch computes `deliveryOperations` and `mail.registrations book` twice, and `Mail.deregistrations` r… | Kernel/ObjectiveSend.lean:288–292 (`deliveryBatch`), 280–287 (`deliveryOperations`); Kern… | high |
| 109 | `PayCell.Law` decided at runtime re-scans the whole pay support and re-parses every claim memo | Kernel/PayCell.lean:429 (`Law`), :370 (`rowShaped`), :338 (`claimMemoCoherent`), :347 (`o… | high |
| 109 | `enrolments` + `journals`: `sortedSupport` (enumerate + canonical sort) run twice per enrolment view | Kernel/PayCellDomain.lean:245 (`enrolments`), :251 (`journals`), :257 (`enrolmentView`) | high |
| 109 | `ObjectiveWorkAccount.Meter.draw` re-sums all draws and appends — O(d²) per turn | Kernel/ObjectiveWorkAccount.lean:201–204 (`Meter.draw`), :194 (`Meter.source`), :197 (`Me… | high |
| 109 | `PayClaimCommand.verifyNative` builds `possessionFrame` twice per claim submit | Kernel/PayClaimCommand.lean:178–185 (`verifyNative`), :99–102 (`possessionFrame`), :150 (… | high |
| 109 | `PayCellDomain.Loaded.write` encodes the whole pay cell twice per pay write | Kernel/PayCellDomain.lean:139–144 (`Loaded.write`), :58–62 (`cellBytes`, `cellRoot`) | high |
| 110 | `nextFree pay` evaluated twice and `bookSize pay` once more — each a full pay-cell support scan — per enrol p… | Kernel/PayClaimDecision.lean:197 (`makePlan`, `index := if nextFree pay < bookSize pay th… | high |
| 110 | PayClaimStatus: request validated twice and `hourOf clock.now` evaluated twice | Kernel/PayClaimStatus.lean:325–330 (`decodeRequest` checks `request.valid`) vs 378 (`proj… | high |
| 110 | Response encoding re-validates what the quote just validated | Kernel/PayClaimQuote.lean:438–443 (`encodeResponse` decides `value.small`) vs 366 (`¬unsi… | high |
| 111 | prepareEnrolLegs recomputes the identity set 7×, the birth draft 2×, grant prep 2× | Kernel/PayEnrolV2Legs.lean:291–334 (`prepareEnrolLegs`), helpers `enrolIds`/`enrolKey`/`e… | high |
| 111 | pricingAt re-derives the birth fee (full draft + ids) that the legs rebuild anyway | Kernel/PayEnrolV2Receiver.lean:95–101 (`pricingAt`), consumed at PayEnrolV2Decision.lean:… | high |
| 111 | enrolPlan counts the pay cell's whole support three times for the next free index | Kernel/PayEnrolV2Decision.lean:309 (`enrolPlan`: `if nextFree store < bookSize store then… | high |
| 111 | stableSubject (a cSHAKE hash) recomputed up to 4× per decision | Kernel/PayEnrolV2Decision.lean:74–75 (`stableSubject` = `PayEnrolMemo.subjectOf`, a full … | high |
| 111 | enrolmentAt and knownPendingSigner re-queried across decide/resolveCustody/classifyTerms | Kernel/PayEnrolV2Decision.lean:201 (`resolveCustody`), :382 (`decide`), :329 (`classifyTe… | high |
| 111 | pricingCommitment re-encodes the fixed tariff and factory template every decision | Kernel/PayEnrolPricing.lean:66–74 (`pricingCommitment`: `tariffStream.encode tariff`, `(S… | high |
| 111 | nullifier builds its input bytes twice and re-encodes its customization string per call | Kernel/PayObservation.lean:181–186 (`nullifier`: `nullifierBytes o` appears in both the h… | high |
| 111 | decideObservations duplicate check is O(n²) list equality over 96-byte pairs | Kernel/PayObservation.lean:306–307 (`transfers`), :319 (`(transfers observations).Nodup` … | high on… |
| 112 | PresenceIndex: association-list maps make the index O(history) per turn and quadratic to rebuild | Kernel/PresenceIndex.lean:65 (`get`), :70 (`put`), :90 (`putAll`), :122 (`Index.admit`), … | high (c… |
| 112 | `whoSeen` observation query is O(touched × pairs) per query | Kernel/NativeObservationController.lean:1010 (`whoSeen`, consuming Kernel/PresenceIndex.l… | high |
| 112 | ProviderMetering: ≥2^32 Nat literal `maxRate` parsed per validity check; model re-encoded twice | Kernel/ProviderMetering.lean:139 (`maxRate : Nat := 1000000000000`), :150–156 (`Tariff.va… | high (w… |
| 113 | 1. `ContentResource.project` fully encodes the whole content store four times per entitlement check | Kernel/RecipientReadEntitlement.lean:111 (`viewProject` → `ResourceObservationAdmission.r… | high |
| 113 | 3. `bytesSlots` builds one interpolated string slot per payload byte, scanned linearly | Compiler/ResourceAuthorityProjection.lean:43–45 (`bytesSlots`), called at Kernel/Recipien… | high |
| 113 | 4. `birthWrite` double-encodes and double-hashes every newborn, and recomputes the constant fresh root | Kernel/ResourceBirthController.lean:73–79 (`birthWrite`), mapped by `allocationWrites` (l… | high |
| 113 | 5. `PreparedBirth.readGuards` re-derives all plan writes once per guard | Kernel/ResourceBirthController.lean:917–922 (`PreparedBirth.readGuards`) and 869–876 (`Pr… | high |
| 113 | 6. `prepareDraft`/`prepareGrainDraft` run the entire pre-authority preparation twice in one call | Kernel/ResourceBirthController.lean:971–988 (`prepareDraft`), 889–909 (`prepareGrainDraft… | high |
| 113 | 7. `documentRows` walks document order twice and re-zips the whole order list per row | Kernel/ResidentContextProjection.lean:56–67 (`documentRows`), with DocumentHistory.lean:5… | high |
| 113 | 8. `decideRefill` applies the Book batch three to four times per refill turn | Kernel/PurseRefill.lean:130–148 (`decideRefill`), `delta`/`aggregateDelta` (117–123), `ci… | high |
| 113 | 9. `sameCreates` canonical-encodes both full create lists per prepare | Kernel/ResourceBirthController.lean:308–309 (`sameCreates`), used at :815 (`prepareBirth`… | high |
| 113 | 10. `opens` computes `systemLeaf` twice per endpoint, four hashes per verify | Kernel/ReceiptContinuity.lean:89–92 (`opens`) | high |
| 113 | 12. Small per-prepare recomputes: `IdentityBound` hashes `sourceIdentity` twice; `newbornSlots` re-derives al… | Kernel/ResourceBirthController.lean:464–473 (`IdentityBound` + `identityBoundDecidable`) … | high |
| 114 | `Pending.branchConfig` + `Config.resolve?`: the policy graph is re-loaded from the directory on every mention | Kernel/ResourceBirthPolicyController.lean:1620-1628 (`Pending.branchConfig`), 1786-1819 (… | high |
| 114 | `projectForRequest`: full descriptor re-encode + per-byte String slot list rebuilt on every call | Kernel/ResourceBirthPolicyController.lean:1245-1257 (`projectForRequest`), 1216-1217 (`us… | high |
| 114 | `branchRequest`/`branchIdentity`/digests: the whole descriptor is re-encoded and re-hashed dozens of times pe… | Kernel/ResourceBirthPolicyController.lean:1404-1412 (`branchRequest` — a plain def, recom… | high |
| 114 | `Pred.State` is a `List (String × Int)` searched linearly by `String ==` — and this file's projections make i… | consumer side built in Kernel/ResourceBirthPolicyController.lean:1245-1257 (`projectForRe… | high (r… |
| 114 | The four compiler verdicts (`supported`/`inputsInRange`/`castInjOn`/`Pred.eval`) run twice per branch | Kernel/ResourceBirthPolicyController.lean:1771-1778 (`planVerdict` — all four in one body… | high |
| 115 | 1. `projectWith` turns every cell byte into its own law slot (string-keyed, linearly searched) | Kernel/ResourceObservationAdmission.lean:214 (`projectWith`, via lines 219–222); helper C… | high |
| 115 | 2. `policyConfig`/`step`/`project` recomputed inside one `authorizeChecked` (the `charge` shape, on the read … | Kernel/ResourceObservationAdmission.lean:235 (`policyConfig`), 231 (`step`), 227 (`projec… | high |
| 115 | 3. `narrowPacked` re-encodes and re-hashes the whole narrowed store per observation reply | Kernel/ResourceObservationAdmission.lean:862 (`narrowPacked` = `materialize _ (DFinsupp.f… | high |
| 115 | 5. `sampleRead` re-projects the entire participant store on every slot read | Kernel/ResourceTransaction.lean:1293–1298 (`sampleRead`), 1275 (`targetProjection`), cons… | high |
| 115 | 6. `CellLaw` re-decided over whole cells at every touch — including the whole Book per account read | Kernel/ResourceObservationAdmission.lean:80–88 (`book`) and 90–93 (`balances`) → Canonica… | high on… |
| 115 | 7. RoomBirthGate recomputes clock, room cell, room law and view per birth item | Kernel/RoomBirthGate.lean:253–268 (`checkRoom`), 294–305 (`checkItem`), 308 (`checkAll`),… | high |
| 115 | 9. `openingsCheck` is an O(T²·A) nested scan with whole-payload equality tests | Kernel/ResourceTransaction.lean:1186–1199 (`openingsCheck`) | high |
| 116 | `RunComputeView.load` decodes the entire Book cell and throws it away | Kernel/RunComputeView.lean:66 (`let _book ← RunComputeBudgetDomain.loadBook deployment ph… | high |
| 117 | `writes`/`readGuards`/`charge` in SubjectKeyCommitmentAdoption re-derive per clause and per lane query — doze… | Kernel/SubjectKeyCommitmentAdoption.lean:220 (`writes`), :223 (`readGuards`), :289 (`char… | high |
| 117 | `TailBound.gate` re-decodes the system cell and rebuilds the Pred state twice on every record | Kernel/TailBound.lean:126 (`gate`), :119 (`systemPosts`), :115 (`valueOf`); Kernel/System… | high |
| 117 | Replay/receipt path recomputes the same SHAKE markers and re-encodes ingress with no `let`s | Kernel/SubjectKeyCommitmentAdoption.lean:106 (`marker`), :206 (`transactionId`), :209 (`e… | high |
| 118 | Objective checkpoint encoding is quadratic in tokens (`++` spine and `flatMap` over segments) | Theory/ObjectiveBendCheckpoint.lean:36-66 (`encodeTerm`/`encodeFields`), :270 (`encodeSta… | high (c… |
| 118 | `HashBytes.be` builds big-endian bytes by O(w²) `++ [x]` | Theory/HashBytes.lean:41 (`be`) | high |
| 119 | StoreNormalize's executable defs (`normalize`/`pushAux`/`pull`/`fuse`/`tidy`) are proof-side today — no hot-p… | Theory/StoreNormalize.lean:77–131, 264–289 | high |
| 121 | `install` loads the workspace twice on the non-auto path | native/resource-client/src/apps.rs:578 and apps.rs:608 (`install`), plus `apps_config` re… | high |
| 122 | Enroll re-queries the app's serving generation once per route | native/resource-client/src/apps_worker.rs:1226–1228 (`ProcessWorld::enroll`, first act: `… | high |
| 122 | Retry/advance of a terminal install redoes hashing, writes and a Host read | native/resource-client/src/apps_worker.rs:434–468 (`install` → `advance` unconditionally)… | high |
| 122 | Edge connector re-reads and re-parses the grain record per browser connect | native/resource-client/src/apps_worker.rs:654–666 (`connect_route`), 671–686 (`connect_ww… | high (o… |
| 123 | `tail --follow` recomputes the entire feed every 3 s poll: full clone, full sort, JSON re-parse of every held… | native/resource-client/src/chat.rs:1234–1237 (`Held::feed`), 1980 (`let (feed, _) = held.… | high |
| 123 | `merge` builds the (cell, sequence) → number index and drops it; every rendered `ref` then linear-scans the w… | native/resource-client/src/chat.rs:983–984 (index built, discarded), 1331–1337 (`render_e… | high |
| 123 | `kind_of` re-parses the payload JSON 2–3× per entry per render; `Entry` carries no parsed kind | native/resource-client/src/chat.rs:922–964 (`kind_of`, `serde_json::from_str` per call), … | high |
| 123 | `open_sealed` round-trips every private-room payload through hex → open → re-hex → the view JSON, which reade… | native/resource-client/src/chat.rs:1143–1171 (`open_sealed`: `mini_sdk::hex::decode`, the… | high |
| 124 | Per-row and per-dependency host process spawns in the context read | context_projection.rs:10-88 (`document`), context_projection.rs:175-220 (`summary_text`) | high |
| 124 | O(rows × entries) row matching with a deep Value clone per comparison | context_projection.rs:37-48 (`document`, the per-row loop) | high |
| 124 | Per-packet identity/digest recompute and seal+open self-check doubling crypto | cohort_tcp.rs:81-102 (`Profile::identity`/`digest`), cohort_tcp.rs:194-257 (`seal`/`open`… | high (o… |
| 124 | Extra full-payload copy per retained record read | cohort_tcp.rs:142-171 (`read_record`, `v[5..].to_vec()` at :164) | high |
| 125 | doc_search::search: collection fingerprint re-reads and re-parses every reference file per search request | doc_search.rs:192–206 (`search`, fingerprint loop over `names`), `collection` at 14–43 | high |
| 125 | doc_search matches/snippet: full lowercase copies of every line, and a whole-line fold per hit | doc_search.rs:168 (`matches`, `text.to_lowercase().contains(needle)`), 113–138 (`snippet`… | high |
| 125 | credit adopt_window: one signed Host view per inbox candidate, reference file re-parsed per candidate | credit.rs:401–449 (`adopt_window`), `window_of` at 372 (full `signed_view` — a Host round… | high on… |
| 126 | `feed` re-reads every account's topic stream from cursor 0 on every call | native/resource-client/src/fleet.rs:864-907 (`feed`, `let mut since = "0".to_owned()`), p… | high |
| 127 | Hermes resident re-verifies the immutable origin on every action | hermes_handoff.rs:305-493 (`verify`), called per action via check_delivery:554-569 / acti… | high |
| 127 | Per-file capability views fetched as N singleton retained queries | hermes_handoff.rs:446-466 (loop in `verify` calling `workspace::signed_view` per file); p… | high |
| 127 | `ask` does a full signed room read to re-find Hermes before every message | hermes.rs:706-711 (`room_hermes`: `workspace::load` + `crate::credit::room`), called from… | high |
| 127 | `verify_view` membership check is O(displayed × opened) with per-entry Nat allocations | hiding.rs:511-516 (`values.contains(&&bytes)` in `verify_view`); also declared_entry_byte… | high |
| 127 | `request_rows` is O(entries × rows) and re-parses entry JSON per scan | hermes.rs:183-203 (`request_rows`), fed by room_rows:209-218; `chat::kind_of` (chat.rs:92… | high |
| 128 | `check` sampleStale retry re-executes the whole job program just to refresh a stamp | native/resource-client/src/job.rs:826-830 (`check`, arm `Err(e) if e.contains("sampleStal… | high (r… |
| 128 | `settle` pays two extra full signed resource views for report cosmetics | native/resource-client/src/job.rs:895 (`before = fields(ws, &name)`), job.rs:899 (`after … | high |
| 128 | `join --wait` spawns a fresh host process per poll tick instead of using the socket inspect it already has | native/resource-client/src/join_solana.rs:934 (`inspect(&common.host, &common.config, "pa… | high on… |
| 128 | `claim` makes a second signed policy view just for WINDOW, and `answer` may make a third | native/resource-client/src/job.rs:676-685 (`claim`: `fields` resource view + `signed_view… | high on… |
| 129 | Duplicate key-status host round-trip in onboarding | join_solana_v2.rs:690 and :698 (`onboarding_record`) with key_rotation.rs:226–238 (`check… | high (d… |
| 129 | Per-poll scratch-dir churn and curl spawn in bootstrap `wait` | join_solana_v2.rs:757–833 (`wait` loop) → join_solana_v2.rs:173–199 (`request`) → join_so… | high (l… |
| 003 | `FnSelectiveReleaseAuthoring.checkPreimage`/`assemble`: release encoded three times plus a discarded sample r… | Host/FnSelectiveReleaseAuthoring.lean:174–183 (`checkPreimage`: `releaseCodec.decode`, th… | medium |
| 003 | `InspectRender.fieldValues` decodes every entry of the resource cell to list scalar fields | Host/InspectRender.lean:247–256 (`fieldValues`: `StoreCodec.entries DeclaredEffectCell.wi… | medium |
| 006 | 2. Every confirmed submit re-reads its receipt from history through a freshly built Reader | Host/Main.lean:1547–1560 (`sessionConfirmed`, called from `fnConsumerNamespaceSubmitSessi… | medium … |
| 006 | 8. Versioned lookups re-decode the payload up to four times | Host/Main.lean:1653–1669 (`applicationLifecycleBeginLookupSession`), :1682–1698 (`applica… | medium |
| 007 | Route-bound payload decoded twice per carried submit | Host/Main.lean:4506–4514 (`carriedApplicationSubmit`): `routeBoundCodec.decode payload` a… | medium … |
| 008 | Op 65 re-runs the whole frontier prepare just to compare plans | Host/Main.lean:7900–7905 (`runCommandStdio`, op 65; same pattern in `runCommandFnFrontier… | medium … |
| 010 | seat view `balances`/`totals` walk the DFinsupp posting chain per cell | Host/SeatJson.lean:301–310 (`viewJson`); representation at Theory/CanonicalResourceKernel… | medium … |
| 014 | The naive DFinsupp fold is still the exported default constructor | Compiler/FiniteDependentMapCodec.lean:42–44 (`fromEntries`: `(fromEntries entries).update… | medium … |
| 015 | Observation flow re-encodes the intent and re-hashes its identity per grant | Compiler/NativeObservationCodec.lean:224–226 (`intentIdentity`); call chain Kernel/Native… | medium-… |
| 016 | `sealCheckpoint` encodes the whole checkpoint body twice and hashes it three times (out-of-shard, found while… | Compiler/DurableCheckpointCodec.lean:793-797 (`sealCheckpoint`) + 766-770 (`checkpointMac… | medium … |
| 017 | `strictCodec` re-encodes the entire descriptor on every decode | Compiler/ResourceBirthCodec.lean:58–69 (`strictCodec`), applied at line 268–269 (`descrip… | medium … |
| 017 | Legacy source projection: decode-then-re-encode-compare and per-call tree walks | Compiler/SourceAgreementLegacyCodec.lean:172–177 (`inspectDocument`: `documentCarrier rec… | medium … |
| 018 | Transcript framing is unary-length and the state is a growing `List UInt8` copied twice per draw | Compiler/Tower256CshakeMerkleController.lean:63–68 (`encodeLength` = `List.replicate n 0 … | medium … |
| 021 | BEGIN admission rebuilds and structurally compares full policy trees | `appPolicyMatches` / `linkedCurrentPolicy` (ApplicationLifecycleBeginReceiver.lean:153-20… | medium … |
| 022 | `DurableCheckpoint.State.snapshot` builds a snapshot whose every query is a linear scan | Kernel/DurableCheckpoint.lean:121–144 (`State.snapshot`): `roots` = `tableLookup` over th… | medium |
| 022 | `DeployedTurnCompact.compactable`/`encodeLegAt` double-runs the patch and encodes both patches whole (latent … | Kernel/DeployedTurnCompact.lean:160–165 (`compactable`: `Patch.run s leg.patch` inside `l… | medium … |
| 023 | `Seed.snapshot`/`Seed.lookup`: linear scan per root query on genesis snapshots | Kernel/DurableReceiver.lean:158-175 (`Seed.lookup`, `Seed.snapshot`) | medium |
| 024 | `FnConsumerFrontierReplay` audit walks are list scans per historical record | Kernel/FnConsumerFrontierReplay.lean:34–58 (`registrationFor`/`cursor`: `registrations.fi… | medium … |
| 026 | `fleetPollAuthorizedLoaded`: one indexed `byTx` store round per polled event | Kernel/NativeHost.lean:1766 (`fleetPollAuthorizedLoaded`), :1746 (`fleetPolledEvent`), :1… | medium … |
| 033 | `DeployedCharge.storageAt` runs its `deltas` pass twice with no `let` (reached from this shard's `charge`) | Kernel/DeployedCharge.lean:63 `storageAt` (`(deltas bridge.codec cells writes).filterMap … | medium … |
| 035 | `transactionOf` re-encodes the whole turn per call | Kernel/SeatStore.lean:647–652 (`transactionOf`: `turnStream.encode turn` inside the hash … | medium … |
| 039 | ~46 fsyncs per paid dispatch, most for derived audit-trail artifacts | dispatch_native.rs:88-103 (`write_new` — `file.sync_all()` + directory `sync_all()` on ev… | medium-… |
| 041 | spk-browser-proxy serves one HTTP request per TLS connection (no keep-alive) | spk-browser-proxy.rs:395–461 (`handle`: `read_frame` → upstream → respond → return; the p… | medium … |
| 042 | Broker `serve` fsyncs the log on every request, on a strictly sequential loop | native/spk-host/src/broker.rs:734-740 (`Broker::log`, `sync_data` per line), called from … | medium |
| 052 | 4. `checked_observation` runs twice per v4 physical report; second pass re-parses journal, re-spawns systemct… | lifecycle_v4_retry_completion_native.rs:261 and :316 (`prepare_report_once`) | medium … |
| 053 | 2. Resident wake pins every file of every package and public-data tree, one fd each | namespace_identity.rs:205–217 (`prepare_root_handles`, called from resident_privilege.rs:… | medium … |
| 053 | 4. Restart recovery spawns the Lean Host process three times to re-inspect retained canonical bytes | resident_launch.rs:81–265 (`SourceBoundLaunch::load_retained`) — `operator.tool("inspect"… | medium |
| 056 | `pinned_executable` re-reads and re-hashes the whole launcher binary on every spawn | native/spk-host/src/spawn_gate.rs:164-217 (`pinned_executable`, hash loop at 206-215) | medium … |
| 065 | `drain_provider_after_prompt` sleep-polls the provider channel on the main thread | native/grain-runtime/src/main.rs:9089–9122 — `loop { try_recv ×4 … thread::sleep(20 ms) }… | medium … |
| 066 | Preflight re-implements each tool's argument validation (JSON-level duplicate of the execution path) | main.rs:12570–12949 (`preflight_foreground_arguments`) vs the same checks inside `tool_ca… | medium |
| 069 | Out-of-shard observation (route to whoever holds main.rs): full SHA-256 of the host executable per applicatio… | main.rs:12918 and main.rs:8356 — `sha256_file(&self.config.host)? != pin` on every `mini_… | medium … |
| 071 | `inspect` for a continuity rejection runs `verify_bindings` twice; each pass re-reads and re-hashes all bound… | native/grain-runtime/src/provider_continuity_rejection.rs:313 and :318 (`inspect`), `veri… | medium … |
| 071 | `lookup_provider_settlement` spawns the native client and re-reads the settlement evidence; its caller just r… | native/grain-runtime/src/provider_recovery.rs:31 (`lookup_provider_settlement`: `verified… | medium |
| 073 | owe/publish_notices re-read and fully rewrite notices.json per notice | native/grain-runtime/src/resident_requests.rs:175-190 (`owe`), 199-223 (`publish_notices`) | medium |
| 073 | record() prints each outcome receipt to stdout from library code | native/grain-runtime/src/resident_requests.rs:96 (`record`) | medium |
| 077 | Policy gate re-digests the committed record and re-lowers the predicate per request | Compiler/CanonicalPolicyAdmission.lean:426–442 (`CanonicalPolicyConfig.verifies`), :404–4… | medium … |
| 077 | `blinded` re-derives the blinding key per query | Compiler/CanonicalCellRegistry.lean:485–495 (`blinded`, `isBlinding`) | medium |
| 077 | Blake3: immutable-array compression and List-UInt8 spine on the frame path | Compiler/Blake3.lean:73–116 (`g`, `roundFn`, `permute`, `compress`), :204–211 (`Output.ro… | medium |
| 078 | Refusal diagnostics re-sort and re-evaluate the whole law after admission already judged it | Compiler/ComposedLawDiagnostics.lean:26–29 (`internalFailure`: `canonicalOrder` O(n²) + `… | medium |
| 080 | Index snapshot ↔ store round trip is all closures on a DFinsupp | Compiler/HyperdocumentCell.lean:767–781 (`snapshotValue`, `storeOfSnapshot` = `DFinsupp.m… | medium |
| 080 | Duplicate-suppression is a full structural-equality linear scan per message | Compiler/GenericSimplexIO.lean:735–740 (`receivedBefore`), :742–751 (`witnessBefore`), us… | medium |
| 082 | The built-in SpecMeta/SpecClaims row is re-resolved from source text on every reference | Compiler/ObjectiveBendElaborate.lean:670–812 (`sourceType`): the sum case at :758–781 bui… | medium |
| 082 | checkTemplates renders and re-decodes the full packet (with all sourceModules) once per template, and accept … | Compiler/ObjectiveBendFrontEnd.lean:157–190 (`checkTemplate`/`checkTemplates`: `packetJso… | medium |
| 083 | `ObjectiveInvocationClaim.family` re-encodes the whole claim per call | Compiler/ObjectiveInvocationClaim.lean:167 (`family claim := ⟨.objectiveMethod, encode cl… | medium |
| 084 | `pastWitness` dedups cell ids with O(n²) `List.eraseDups` and does per-cell root lookups | Compiler/ReceiptContinuityIO.lean:98–107 (`pastWitness`) | medium … |
| 085 | Law-denial explanation path re-parses slot names per clause and re-derives guards | Compiler/RefusalReason.lean:732 (`slotCovered`, `slot.splitOn "/"` per call), :761 (`read… | medium |
| 087 | `admitNative`: two full descriptor encodes for the equality check; retry/grant lookup canonicality re-encodes | Kernel/ApplicationAgentLifetimeGrantAdmission.lean:90-96 (`CanonicalCellRegistry.sourceEn… | medium |
| 088 | v3 `Ingress.shape` re-derives the authorization digest on every evaluation | Kernel/ApplicationLifecycleBeginV3Ingress.lean:100–118 (`authorizationBytes`, `Ingress.au… | medium … |
| 089 | Retry-BEGIN/CLAIM `shape` re-encodes and re-runs the full v3 shape repeatedly per retry claim | Kernel/ApplicationLifecycleRetryBeginV4Ingress.lean:74 (`Ingress.shape`), :57 (`authoriza… | medium |
| 089 | `linkedCurrentPolicies` reloads both policies on its fallback branch | Kernel/ApplicationLifecycleCompletionV2Admission.lean:144 (`linkedCurrentPolicies`) | medium |
| 090 | Share-issue delegation: whole app cell re-encoded into slots per policy evaluation | Kernel/ApplicationShareIssueDelegation.lean:109-118 (`project`: `(materializer …).codec.e… | medium |
| 093 | Cross-reference: `elementCount`/`treeFuel` re-filter the whole store support per order computation (ContentRe… | Kernel/ContentResource.lean:914–918 (`elementCount`, `treeFuel`), called by `documentOrde… | medium … |
| 094 | `Context.sourceRead`: function-as-map, linear scan + fresh hash per query | Kernel/ContentResource.lean:143-145 (`Context` with `sourceRead : Nat → Option SourceRead… | medium |
| 094 | Patch accumulation is `++ [op]` per step | Kernel/ContentResource.lean:535 (`allocate`), 548 (`replaceAtom`), 561/575 (`rewrapAnnota… | medium |
| 097 | FnConsumerFrontierCore State is an association List; step re-filters it with full Key equality per replay tra… | Kernel/FnConsumerFrontierCore.lean:175 (`abbrev State := List (Key × Cursor)`), :179-180 … | medium … |
| 097 | FnGatewayPolicy.checkCurrent re-loads the policy source cell on every call, and callers stack it | Kernel/FnGatewayPolicy.lean:87-101 (`checkCurrent`: `headAt` + `CanonicalCellRegistry.loa… | medium … |
| 099 | `plan.legEffectsDigest` re-derives the full leg record per digest query | Kernel/GrainResourceBirthTransaction.lean:283-288 (`plan`), :286-287 (`legEffectsDigest`) | medium … |
| 101 | Reserve ingress encodes/compares the same intents repeatedly across one request | Kernel/JointReserveIngress.lean:70-76 (`descriptorMatches` — `intentStream.encode p.custo… | medium |
| 101 | `proposeLocalYes`/`reserve`: candidate + image + projection re-encoded per participant, `table ++ [r]` per re… | Kernel/JointDecisionRecovery.lean:290-302 (`proposeLocalYes` — `(candidateStream custodyC… | medium |
| 102 | `recordMatches` fully encodes both intent records to compare them | Kernel/NativeHistorySelection.lean:142 (`recordMatches`: `decide (encode record = encode … | medium |
| 103 | `ObjectRecord.classOf` does a linear `∈` over the rebirth list on every retain/release | Kernel/ObjectRecord.lean:193–197 (`classOf`, `activity ∈ next.rebirth`), called by `retai… | medium |
| 103 | `pokeProduct` re-edits the door cell to validate the product on every poke | Kernel/NockEntry.lean:234–239 (`pokeProduct`: `if Noun.edit 6 state door = some core`) | medium |
| 104 | 9. `decodeDataBytes` validates by full re-encode + list compare on every decode (callers in this shard) | ObjectiveActivityWire.lean:199–202 (`decodeDataBytes`; read via grep), called per deliver… | medium |
| 107 | `Grant.judge` re-hashes the call's arguments once per naming grant, and `admits`/`amount` double-walk | Kernel/ObjectiveCall.lean:789–800 (`Grant.judge`), :742–745 (`ArgsBound.admits`: `decide … | medium … |
| 107 | `Journal.drained` re-runs the successor's law at commit for entries already judged at frame return | Kernel/ObjectiveCall.lean:2270–2282 (`Entry.drained`, `Journal.drained`), run uncondition… | medium |
| 107 | `deliverable`'s postage check replays the turn's whole draw list per send | Kernel/ObjectiveCall.lean:1415 (`postagePays` field), :1452 (`(Meter.start message.envelo… | medium |
| 108 | waitsForUpgrade decodes the target's full ObjectRecord for one Bool, then the run decodes it again | Kernel/ObjectiveSend.lean:400–404 (`waitsForUpgrade`, via `readObject` = `objectFor` over… | medium |
| 108 | Onward-send escrow and messages rebuilt per consumer | Kernel/ObjectiveSend.lean:159–169 (`onwardEscrow`/`onwardRefusal` — `onwardEscrow` comput… | medium … |
| 109 | `bookRows`: `List.range` + one DFinsupp lookup per book index | Kernel/PayCellDomain.lean:199 (`bookRows`), called from NativeHost.lean:2192 (`payViewLoa… | medium |
| 110 | v1 memo parser `cut` copies the memo roughly twice per parse | Kernel/PayEnrolMemo.lean:208–211 (`cut`), used by `parse` at 249; consumers: `classify` (… | medium … |
| 111 | (cross-boundary, caller-verified) the observation command is re-encoded ~5× per report | caller of this shard's codecs — Kernel/PayObservationReceiver.lean:118/140 (`commandCodec… | medium … |
| 112 | Every invoke draft is prepared twice: diagnosis pass, then submission pass | Kernel/NativeHost.lean:836–850 (`invokeRefusal`) with Kernel/PreparedInvocationDiagnostic… | medium … |
| 112 | PrivateSuccessorCustody: `Journal` operations are linear over monotonically growing lists (latent) | Kernel/PrivateSuccessorCustody.lean:96 (`reserve` — `id ∈ journal.spent`), :105 (`burn` —… | medium … |
| 113 | 11. `PhysicalPostLaw` re-decodes bytes it just encoded | Kernel/ResourceBirthController.lean:406–415 (`PhysicalPostLaw` + `physicalPostLawDecidabl… | medium |
| 114 | `preparePending`'s injectivity check: O(n) full request encodes + O(n²) byte-list comparisons | Kernel/ResourceBirthPolicyController.lean:1486-1491 (`letI : Decidable (Function.Injectiv… | medium |
| 114 | `check`/`checkTemplateAt` re-scan the grant list 3-5× with per-pair `ForBirth` decidability | Kernel/ResourceBirthPolicyController.lean:189-209 (`check` — 11 sequential `require`s, se… | medium |
| 118 | DeclaredTurn accessors re-materialize the whole store per call | Theory/DeclaredTurn.lean:136 (`Commit.post`), :151 (`Commit.postRoot`), :237 (`Outcome.ma… | medium … |
| 122 | `mini`/`spk-host` child spawned per workspace operation in lifecycle chains | native/resource-client/src/apps_worker.rs:971–985 (`ProcessWorld::run`/`mini`), called in… | medium |
| 122 | Member-verb serve loop is serial and holds a global lock across child processes | native/resource-client/src/apps_worker.rs:208 (`handle`: `self.lock` held for the whole v… | medium |
| 123 | `entry_ref` cache miss falls back to a full-history `read_room` to resolve one `#N` | native/resource-client/src/chat.rs:1466–1480 (`entry_ref`), used by `say --re`, `pin`, `r… | medium … |
| 126 | A fresh signed observation per page: one attempt dir, one Ed25519 sign, several durables, per 64 events | native/resource-client/src/fleet.rs:909-952 (`poll_value` calls `observe` per page), flee… | medium … |
| 126 | Fresh-workspace `guard` re-reads and re-hashes custody pins on every signed observation | native/resource-client/src/fresh_onboarding.rs:149-187 (`retained`: full RECORD JSON re-r… | medium |
| 128 | `now()` spends a second host round trip to render a field the client immediately stringifies | native/resource-client/src/job.rs:147-150 (`now`) | medium … |
| 016 | Proof-only / non-runtime content in this shard (no findings) |  |  |
| 069 | pending_prepare.rs and prompt_outcome.rs — no runtime findings |  |  |
| 103 | `decodeTyBytes` re-encodes the whole type to check canonicality after a successful decode | Kernel/ObjectStateType.lean:330–332 (`decodeTyBytes`, `tyBytes type == bytes`) | low (on… |
| 108 | Kernel/ObjectiveResumeContract.lean: no runtime findings |  |  |

### Startup, rare or build-time (61)

| shard | finding | where | conf |
|---|---|---|---|
| 000 | `ApplicationDispatchInspection.inspect` re-encodes and re-hexes bytes it already holds | Host/ApplicationDispatchInspection.lean:47 (`inspect`); same shape in `ApplicationDispatc… | high |
| 000 | `ApplicationAgentLifetimePaidIngressInspection.inspect` decodes the plan twice and reassembles the whole ingr… | Host/ApplicationAgentLifetimePaidIngressInspection.lean:63 (`inspect`: `paidPlanCodec.dec… | high |
| 000 | `prepareLoaded` encodes the birth descriptor three times and intents twice for one comparison | Host/ApplicationAgentLifetimeGrantAuthoring.lean:88 (`prepareLoaded`): `CanonicalCellRegi… | high |
| 000 | `inspectAcceptedCurrent` replays the entire history per call | Host/ApplicationAgentLifetimeGrantInspection.lean:145 (`inspectAcceptedCurrent`: `NativeH… | high |
| 003 | `FnInboxView.typedAtom` arm "1" decodes `binding.package` twice, including the whole accepted prefix | Host/FnInboxView.lean:214–215 (`originJson binding.package` immediately followed by `FnEv… | high |
| 003 | `InspectViews.capTree` rebuilds `allKnown items` per node and computes `links nodes` twice | Host/InspectViews.lean:137–143 (`nodeOf` calls `(allKnown items).filter` per id), :157–16… | high (w… |
| 004 | `worldDefinition` layers the DFinsupp Store once per default entry, re-looking up through all layers | Host/Json.lean:1157–1181 (`worldDefinition`), :1234–1239 (`worldEntriesJson`), :1241–1255… | high on… |
| 006 | 10. `readPaidAuditLine` reads one byte per syscall with quadratic append | Host/Main.lean:3252–3260 (`readPaidAuditLine`, `input.read 1`, `acc ++ byte`), looped by … | high |
| 007 | Quadratic ByteArray-append read loops feed the 64 MB operator snapshots and 3.2 MB article reads | call sites in this shard: Host/Main.lean:4657, 4755, 4813, 4899, 5005 (`snapshotOperatorF… | high |
| 014 | `encode` builds the whole frame prefix twice for the trailer hash | Compiler/FnWireGrammar.lean:396–402 (`encode`, `.frame` arm) and 358–360 (`framePrefix`) | high (w… |
| 014 | `.base64Lines` recomputes `unlines` twice; `.line` recomputes `takeWhile`/`dropWhile` | Compiler/FnWireGrammar.lean:437–442 (`decode`, `.base64Lines`: `lines width (unlines widt… | high |
| 016 | `restoreJournal` does nested linear membership over the spent list | Compiler/PrivateSuccessorCustodyCodec.lean:110-117 (`restoreJournal`), 139-144 (`reserveE… | high on… |
| 020 | 2. `event` encodes the entire ingress twice per call (eventId hash input + `canonicalBytes` field) | Kernel/ApplicationDispatchIngress.lean:163–169 (`ApplicationDispatchIngress.event`); iden… | high |
| 023 | `Image.currentBytes` re-walks the whole log per cell (world-root paths) | Kernel/DurableReceiver.lean:288 (`Image.currentBytes`); callers Compiler/NativeHostCodec.… | high |
| 024 | Kernel/HostRefinesWorldCore.lean — no runtime findings | whole file | high |
| 026 | Dead defs: `invokeLawLeaf`/`invokeRangeLeaf`/`invokeCastAlias` (zero callers) | Kernel/NativeHost.lean:766, :780, :792 | high (o… |
| 029 | `extendVerified`/`verifySuffixLoaded`/`extendSuffixVerified` re-encode the whole accepted prefix per extension | Kernel/NativeHostReplay.lean:4403–4406 (`extendVerified`), 4923–4926 (`verifySuffixLoaded… | high |
| 029 | `deriveSuffixAt` scans the whole preserved-prefix history per carried dispatch | Kernel/NativeHostReplay.lean:4680–4682 (`retained.source.durable.image.accepted.any (fun … | high |
| 039 | Lifetime paid assembly re-inspects the reserve plan the reserve stage already inspected | agent_api_lifetime_paid_native_v3.rs:92-99 (`assemble_once`) vs agent_api_lifetime_revers… | high |
| 039 | `check_pin` re-reads and re-hashes the pinned config on every tool/invoke call | dispatch_native.rs:440-459 (`check_pin`, called from `tool_until` :494 and `invoke_until`… | high |
| 042 | Checkpoint backup computes the same volume/active-state inventory twice | native/spk-host/src/broker_checkpoint.rs:160 (`checked` → `volumes_status` + per-volume `… | high |
| 046 | Every grain verb re-hashes the pinned `spk-host` and `bwrap` binaries in full | native/spk-host/src/grain.rs:289-290 (`Host::load` → `pinned_executable`), :140-152 (`fil… | high |
| 046 | `configs()` re-verifies the whole installed SPK image on every START | native/spk-host/src/grain_agent_route.rs:212-225 (`signed_path` → `verify_installed_spk`)… | high (m… |
| 050 | `OfflineSourceHost::check_pin` re-hashes the entire host executable with no inode memoization (2× per source … | launch_descriptor_native.rs:56-92 (`check_pin`), called at `run_step` entry (:101) and ag… | high |
| 052 | 1. Stopped-phase STOP runs the entire original-claim inspection twice back-to-back | native/spk-host/src/lifecycle_v3_stop_service.rs:1244 and :1259 (`run` → `inspect_origina… | high |
| 052 | 5. `check_pin` re-reads and re-hashes the pinned config on every operator call | dispatch_native.rs:440–458 (`check_pin`), invoked by every `tool` and `invoke` — 15–25× p… | high th… |
| 054 | Checkpoint drain busy-polls with 10 ms sleeps while holding the event loop | resident_service.rs:2039-2048 (inside `checkpoint.poll_once` drain closure) | high (m… |
| 054 | `read_until` resets the socket read timeout on every chunk | resident_route_control.rs:254-275 (`read_until`, used by `read_frame`) | high |
| 056 | Published-data tree walked 3–4× per generation (double walk inside `open_published_internal`) | native/spk-host/src/shared_data.rs:764 (`open_published_internal`, `collect_tree`), :777 … | high |
| 056 | Volume verbs spawn bash scripts and `findmnt` per invocation | native/spk-host/src/volume_helper.rs:215-225 (`script`, `Command::new("/bin/bash")` with … | high (s… |
| 060 | Custody/deadline wait loops poll at 10 ms and cap drain at 128 KiB per tick | custody_gate.rs:159–248 (`run_capture_with_hooks` loop: `thread::sleep(10ms)`, `drain_non… | high on… |
| 061 | Session recovery validates the same journal and re-hashes the same files up to 3× per invocation | foreground_session_recovery.rs:30–150 (`candidate_at`), 353–360 + 476 (`recover_foregroun… | high |
| 062 | retained_outcome linear-scans and JSON-parses the entire append-only history per lookup | native/grain-runtime/src/history_compaction.rs:199-208 (`retained_outcome`) | high on… |
| 063 | Startup config validation hashes the host binary up to three times | native/grain-runtime/src/main.rs:3199, :3227, :3315 (`validate_with_workspace`) — `sha256… | high |
| 067 | Hermes transcript store fully hashed twice per prompt | main.rs:14615 (`let current = hermes_state_fingerprint(&hermes_home)?` pre-prompt) and 15… | high. |
| 068 | `Journal.reconciliation_log` is unbounded and the whole journal is re-serialized to JSON per serve-loop event | native/grain-runtime/src/main.rs:588 (`reconciliation_log: Vec<Value>`, only ever `push`e… | high (m… |
| 071 | Legacy fence scan walks up to 4096 operation directories with full re-derivation per candidate | native/grain-runtime/src/provider_history.rs:297 (`recover_provider_fence`); reads + JSON… | high (c… |
| 072 | `resident_compute::settle` rescans the whole state dir and re-reads every historical compute ledger each prom… | native/grain-runtime/src/resident_compute.rs:66–75 (`settle` directory loop), 84–104 (`pa… | high |
| 080 | `Log.checkpoint` builds the full merged event list and throws it away | Compiler/GenericSimplexIO.lean:146–149 (`Log.merged`: `l.base.events ++ l.deltas.flatMap … | high |
| 084 | `castAliasPair` materializes the full O(n²) pair list on the refusal path | Compiler/PredRangeLeaf.lean:252–258 (`castAliasPair`, `castAlias`) | high |
| 087 | `markersCurrent` computes every marker nullifier twice; `retryToken` double-encodes the whole selector per co… | Kernel/ApplicationFailedCreateRetryEvidence.lean:123-137 (`markersCurrent` calls `markers… | high |
| 087 | `linkedCurrentPolicies` decodes each policy cell twice | Kernel/ApplicationFailedStartRecoveryAdmission.lean:139-165 (`linkedCurrentPolicies` — `l… | high |
| 087 | `prepareConditional`: `(DeclaredResourceController.writes prepared).map DataWrite.cellId` recomputed 3× | Kernel/ApplicationFailedStartRecoveryAdmission.lean:371-375 (`packageGuardReadOnly` and `… | high |
| 091 | `Ready.initialPolicies` encodes the policy record twice (digest + bytes) | Kernel/ApplicationShareIssueSource.lean:303–307 (`Ready.initialPolicies`) | high (t… |
| 096 | DocumentHistory.moves recomputes `common left right` and `common right left` up to 4× per row | Kernel/DocumentHistory.lean:62 (`moves`), :53 (`common`), :57 (`predecessor`) | high |
| 100 | `isJobLaw` rebuilds and structurally compares the whole 45-clause job law per money command | Kernel/JobMoney.lean:864-867 (`isJobLaw`), with `lawParams` :852-860 and `Job.jobLaw`/`jo… | high (c… |
| 109 | `ParticipantKeyEnrollment.allKeys`: three full authority-support scans per enrollment | Kernel/ParticipantKeyEnrollment.lean:223 (`allKeys`), :214 (`keyAt`), used at :312–314 (`… | high |
| 109 | `countIn` / `accountAssigned` / `nextFree`: whole-support filter+card scans on the pay decision path | Kernel/PayCell.lean:316 (`countIn`), :321 (`nextFree`), :324 (`bookSize`), :327–332 (`acc… | high |
| 117 | `SystemCellDomain.Loaded.write` serializes the post cell twice (bytes + root) | Kernel/SystemCellDomain.lean:57 (`cellBytes`), :60 (`cellRoot`), :154 (`Loaded.write`) | high |
| 119 | Voucher lookups are linear byte-list scans on the receive path | Theory/ReceivingVerifier.lean:124 (`vouches` = `decide (claim ∈ vouchers.verified)`), 131… | high (t… |
| 121 | `delegate_lifecycle` drives installation by exec'ing the whole `mini` binary per op, up to ~28 times | native/resource-client/src/apps.rs:1130–1161 (`delegate_lifecycle`), invoked from `instal… | high (s… |
| 125 | doc_search::direct: per-document durable scratch — fsync'd hex-encoded whole view, retained forever, on every… | doc_search.rs:47–67 (`direct`), `new_attempt`/`make_private_dir`/`create_private` at 54–6… | high |
| 128 | `why` renders the Lean view twice and probes with a separate host codec process | native/resource-client/src/inspect_views.rs:383-386 (`why` probe via `render_quiet`), 407… | high |
| 000 | `ApplicationCurrentBirthAuthoring` re-reads the platform record and re-checks the tariff per draft | Host/ApplicationCurrentBirthAuthoring.lean:55/71 (`appDraft`/`sessionDraft`: `platformRec… | medium … |
| 026 | `receiptRoot`'s fallback re-executes the whole prefix when the root log is empty | Kernel/NativeHost.lean:1196 (`receiptRoot`); fallback at :1200 | medium … |
| 054 | Head-of-line blocking: enrollment and agent frames share the single-threaded HTTP event loop | resident_service.rs:2065-2204 (`route_control.poll_once` admission closure and the `Prepa… | medium … |
| 067 | Hard disconnect / startup recovery spends ~7–9 signed Host turns, with same-authority double queries | `disconnect` 13750–13761 (`retry_pending` ×2, `retry_pending_slot` ×2, then `fence_tool`+… | medium … |
| 077 | Book codec: three `entries` sorts + `Nat.pair` per comparison per encode; fold-insert DFinsupp per decode | Compiler/CanonicalResourcePageMaterializer.lean:67–72 (`entries`), :101–109 (`bookTuple`,… | medium |
| 102 | `readPrefixFrom` double-encodes each whole window and re-drops from the list head per window | Kernel/NativeHistorySelection.lean:255–258 (both `(list intentStream).encode` calls) and … | medium |
| 104 | 10. `loadMigration` re-runs the front end per judged drained write | Kernel/ObjectiveActivity.lean:2570–2589 (`loadMigration`: `ObjectiveBendPublication.repla… | medium |
| 124 | Three host exchanges + fsync per consent decision | consent_proxy.rs:351-369 (`Worker::request`), 337-350 (`Worker::retain`) | medium … |

### Operator path, low priority (439 lines, reader one-liners)

- [003] Host/GrainOriginPreparation.lean:88–96 + Host/GrainOriginSource.lean:133 — the package is `FnEvidenceCodec.decodeChecked`-ed three times per disclosure prep (inside `FnEvidence.verify`, in `prepareFo…
- [003] Host/FnConsumerNamespacePlan.lean:152–166 + :185–198 — namespace registration `assemble`/`assembleSignature` re-run the whole `checkCurrent` triple (`freshSpec` + `currentRoots` + `prepareSigningHead…
- [003] Host/RequestRefusal.lean:228 — `noAppend` is a linear `.contains` over the 150-element `HostOperations.noAppendOperations : List UInt8` in `exceptionAnswer`; only on the handler-exception path, but a…
- [003] Host/FnOutcome.lean:132–156 — `frameReason` tries `readConsumerReply`, then `readStatusReply`, then `readPollReply 64` sequentially over the same stdout on failure; per fn command diagnostic, tiny.
- [003] Host/InspectRender.lean:69–72 — `hexText` rebuilds `"0123456789abcdef".toList` per byte inside `flatMap`; and :55–62 `unhexChars` is non-tail recursion building a `List UInt8`; both per inspect call,…
- [003] Host/FnSelectiveReleaseAuthoring.lean:82–85 — `parseRequest` field check is `names.all (· ∈ requestFields)`, O(16×16) string compares per authored request; harmless, noted only because it is the same…
- [004] `genesis` Host/Json.lean:1686–1750 — parses ~30 fields each via `field`+`exactObject`+`nat`; fine individually, but runs `exactObject` over the 28-key `names` list twice (observed/not); operator one-…
- [004] `signingKeyNextDigest` Host/Json.lean:3007 — `(toString …).toUTF8.toList` per call; operator.
- [004] `applicationBirthContext` Host/Json.lean:1995–2047 — re-parses the full `genesis` object on every application/session birth authoring (the config is operator-supplied each time); could accept the par…
- [004] `charge` Host/Json.lean:1650–1659 — 10-element `List Nat` indexed by position via `values[i]?` (O(i) scans); trivial, but an `Array Nat` or named record would remove the index gymnastics.
- [004] `encodeHex` Host/Json.lean:366–372 — recomputes `byte.toNat` twice per byte and goes through `Char.ofNat`/`UInt8.ofNat` round trips; readback-only.
- [005] Host/Json.lean:3712 (`payCommandJson`): up to 6 sequential full codec decodes of the same bytes (`pay-plan` inspect) — pass the already-known kind from the caller instead of guessing by cascade.
- [005] Host/Json.lean:4389–4390 (`challengeJson`): `value.headers.toArray.map hexJson` and `.map signedHeaderJson` — `toArray` built twice and headers traversed twice; one `let arr := value.headers.toArray`…
- [005] Host/Json.lean:5626–5631 (`view-capability`): three candidate codec decodes per call; fine as-is since `//` short-circuits, only worth touching if the op ever gets hot.
- [005] Host/Json.lean:3553–3557 (`signatures`): `(StreamCodec.list bytesStream).toLawful` re-assembled per call; trivial.
- [005] Host/LawSat.lean:91–103 (`scalarView`): per-slot `splitOn "/"` plus `s!"…{k}…"` string interpolation and `Nat`→decimal rendering on every `realize`d `monotone`/`writeOnce` atom (op 150 `law-sat`, `ca…
- [005] Host/KeyCommitmentAdoptionInspection.lean:27–40 (`hexBytes`/`publicKey`): List Char recursion and `text.toList` on a 64-char hex string with `UInt8.ofNat` per nibble — bounded (64 chars), rare (key a…
- [005] Host/Json.lean:3428–3508 (`grainRepinFixture*` + `grainPolicy_*` theorems): `native_decide` fixtures — elaboration-time only, no runtime cost.
- [006] Host/Main.lean:1458–1471 `presenceIndexJson`/`linkIndexJson` — stringifies whole indexes with `toString` per entry (operator output only).
- [006] Host/Main.lean:1056–1125 `inspectHost` — ~40-string if-chain per inspect call (trivial, but a match on a sumtype would be free).
- [006] Host/Main.lean:1200–1224 `descriptionLoaded`/`description` — decodes the platform cell record per op-0 describe instead of caching with the session (per client connect).
- [006] Host/Main.lean:3034/3049/1482–1484 — `IO.getEnv "MINIDREGG_HOST_TRACE"` up to three times per frame; read it once at startup into a `Bool`.
- [006] Host/Main.lean:2191–2196 `Settings.rateGate` — the rate table is a plain `List` (`IO.Ref SubjectRate.Table`); per-request `SubjectRate.check/charge` is linear in live subjects (fine until the subject…
- [007] Host/Main.lean:3505–3512 `requireExactFields` — O(fields×keys) `List.contains` both directions per manifest; operator-only.
- [007] Host/Main.lean:5957 `providerFromReserveCall` — `targets.filter (· ∈ providerIds)`, O(targets×providers); tiny.
- [007] Host/Main.lean:4391 `carriedEnrollmentLookup` — canonicality check re-encodes ingress (`canonicalBytes.toByteArray == payload.toByteArray`); request path but enrollment-only, ms-scale.
- [007] Host/Main.lean:6550 `usage` — multi-KB string concatenation rebuilt per error throw; one-shot CLI.
- [007] Host/Main.lean:5154/5275 `String.fromUTF8! report.operation.toByteArray` — List→ByteArray→String per decision JSON; trivial but per request.
- [010] Host/SeatJson.lean:183 (`commandJson`): re-encodes the already-decoded `Command` to hex for `canonical` — operator seat inspect only.
- [010] Host/SeatJson.lean:208 (`inspectPlan`): decodes the command bytes a second time inside the plan view — operator.
- [010] Host/SeatJson.lean:45–61 (`hex`/`unhex`): per-nibble `"0123456789abcdef".toList` allocation and whole-string `toList` for unhex — author/inspect CLI only.
- [010] Host/SourceAgreementJson.lean:102–110 (`exactObject`): O(k²) key membership via two list scans — k≈27 for `genesis`; authoring only.
- [010] Host/SourceAgreementJson.lean:957–983 (`worldDefinition`): per-default `Store.set` closure layering then one full `StoreCodec.encode` — world-kind authoring only.
- [011] Compiler/DurableCheckpointCodec.lean:504–561 — the epoch-refusal `native_decide` witnesses (`seedEpoch_spentMap_refused` etc.) each re-evaluate `SeedEpoch.ofBytes` over full frames; proof-time only, …
- [011] Compiler/DurableCheckpointCodec.lean:916–968 — `openSealed_seal`/`openSealed_foreign_key` seal and re-open whole states per elaboration; proof-only.
- [011] Compiler/BendWorldPlan.lean:79–84 — `encodeReturn`/`returnId` re-encode the whole `ReturnSlot` (including `bytes`) per id computation; one-shot tools only.
- [011] Compiler/CredentialAuthorityEntryCodec.lean:514–516 — the `Repr (StoredCapability)` instance encodes the full capability per show; diagnostics only.
- [012] `scratchReader` (Compiler/DurableHistoryStore.lean:40–52): computes `commitment.rootOf image` (whole-image world root) once per portable-image import — rare, fine to leave.
- [012] `Probe.run`/`stepOk`/`rootOf` at whole-map scale (Compiler/DurableIndex.lean:1060–1111): whole-trie rebuild per probe step — proof/probe-only (`native_decide`), not runtime.
- [012] `DurableStoreAudit`/`DurableServed` full re-apply of `IndexRows.apply` per record (seen only at their call sites): audit/rebuild verbs, operator-path, inherit the per-append findings above.
- [014] `DurableStoreAudit.audit` (Compiler/DurableStoreAudit.lean:186–189): `records := records ++ [record]` per entry — O(n²) over every log entry of the whole store; accumulate with a reverse/prepend or A…
- [014] `DurableStoreAudit.rebuildIndex` (Compiler/DurableStoreAudit.lean:142–156): per record rebuilds `DurableIndex.overlay (fun _ => none) rows` over ALL rows so far (every `IndexRows.apply` lookup walks …
- [014] `DurableStoreAudit.audit` (Compiler/DurableStoreAudit.lean:233): `checkpointHeights.find? (·.1 = height)` inside the per-record replay loop — O(records × checkpoints); the list is height-ordered, so …
- [014] `DurableStoreAudit.honestNodes` (Compiler/DurableStoreAudit.lean:125–133): re-walks the accumulator frontier that `walkFrontier` (called at line 196) already walked over the same entries; one walk co…
- [014] `FnEvidenceCodec.decodeCheckedWith` (Compiler/FnEvidenceCodec.lean:168–185): a historical (v1) package is decoded twice — once failing v2, once v1 — on every admission of an old-format event; bounded…
- [014] `FnWireJson.vectorCheck` (Compiler/FnWireJson.lean:235–288): computes `hexOf octets` (BLAKE3+hex) for the failure label on every vector, decodes the value twice (`valueOfJson` then re-encode of both …
- [015] Compiler/LegacyStoreCarry.lean:54–56 `decodeV2`: `frameV2 wire` computed twice per decode (take-length and compare), each a full `layoutDigest wire` re-hash — hoist to a `let` (carry/genesis path; sa…
- [015] Compiler/GenericSimplexCodec.lean:135–138 `Context.wellFormed`: `publicKeys.eraseDups.length == publicKeys.length` is O(parties²); only callers I found are Verify/NativeJointSourceFixture (verificati…
- [015] Compiler/LegacyStoreCarry.lean:241–248 `decodeAuthority`: decodes then walks all entries checking object grants per carry — fine for a one-shot carry; no action needed unless carry ever moves per-tur…
- [016] `PolicyRecordCodec.LegacyV4` (PolicyRecordCodec.lean:892-1038) — migration-only decoder, never called by the active path by design.
- [016] `Host/Main.lean:10293` epoch print and the `timed` bench block at Host/Main.lean:1300-1374 — diagnostics; note `foldSemantics` is evaluated multiple times inside it, so its timings partly measure fin…
- [016] `InspectRender.lean:294,486` / `Host/Json.lean:3586` / `SourceAgreementJson.lean:2049` — inspection views decoding footprints/policies per query; fine as operator verbs.
- [016] `scripts/probe-policy-source-cell.lean` — one-shot probe.
- [017] `DirectoryImage.decode` in scripts/probe-policy-source-cell.lean:155 — probe-only O(n²) decode; fine as-is.
- [017] `SemanticArtifactBundle.manifestToJson`/`codecPinToJson` (Compiler/SemanticArtifactBundle.lean:573–630) — artifact emit, operator path.
- [017] `MinidreggV1Artifact.#eval writeBuildTarget` (Compiler/MinidreggV1Artifact.lean:468) — build-time JSON write, fine.
- [017] `Host/Json.lean:2124–2177` birth authoring encode/decode — operator authoring verbs; inherits the strictCodec 3× cost only at authoring time.
- [017] `TokenCensus/Table.lean:45–48` quotes `DirectoryImage.decode` only as a proof premise — no runtime cost.
- [017] `Manifest.lookupCodec/lookupClause` (`List.find?` + `decide`) — small lists, called only from Prop-level registry closure today; fine.
- [018] `bytesEqual` (Compiler/Tower256ConcreteBackend.lean:69) — per-octet list recursion; only caller found is scripts/probe-grain-origin-source.lean:36 (one-shot probe).
- [018] `receivingContract` (Compiler/WorldExecutionContract.lean:15) — ~1 KB list rebuilt per evaluation; no runtime caller found in my sweep (likely unused or consumed elsewhere under another name).
- [018] `signedRequestBytes`/`planOf` (Compiler/TypedAuthorizationRequestCodec.lean:269–273) — re-encodes the whole request per signature check (PlatformInstallReceiver.lean:681 uses the equality only); smal…
- [018] `decodeDefinition`/`descriptor_roundtrip` (WorldKindDescriptor.lean:141–151) — full descriptor decode + `Valid` check per authoring call; fine for operator verbs.
- [018] `compactEvery` (Compiler/WorldCompact.lean:190) — correctly amortized (every 32nd height, DurableReceiverCore.lean:884/972); noted as the mitigation, not a finding.
- [020] Host/Json.lean:4163–4164 (`agentPaidReserveRequestJson`): recomputes `ApplicationDispatchCodec.requestDigest request.base.base.http` per JSON render — per inspection/authoring render, not per turn.
- [020] Kernel/ApplicationDispatchAgentPaidAuthoring.lean:96–100 (`Request.matchesPin`/`matchesFixed`): rebuilds `FixedSelectors` and runs a large derived-structure `decide` per pin check — authoring tooling.
- [020] Nullary frame/codec defs (`ticketFrame`, `interfaceFrame`, `manifestFrame`, `codec`): rebuild `"…".toUTF8.toList` and the framed codec record on every encode/decode call — per submit as well as opera…
- [021] `Ready.descriptorCurrent` (ApplicationGrainSessionBirth.lean:216-225): builds the full `previous` descriptor (grants, `initialPolicies` incl. per-record `PolicyRecordCodec.encode` + digest) then repl…
- [021] `Ready.initialPolicies` (ApplicationGrainSessionBirth.lean:189-195): encodes + digests each policy record at birth; one-shot genesis.
- [021] `enrollmentAtom` recomputed per use site (Construction `prepare`:112-113, `initialAction`/`renewalAction`:142-144, `decodeInstalled`:172-176 in ApplicationGrainSessionEnrollment.lean): SHAKE over a ~…
- [021] `ApplicationGrainSession.policy`/`transitionPolicy`/`descriptorIncidence` (ApplicationGrainSession.lean:149-195): build `Pred` trees with `s!"joint/target/{n}/…"` interpolation per call; birth/author…
- [021] `readState` (ApplicationGrainSession.lean:111-117): four independent `DeclaredFields.read` store applications where one pass over the four coordinates would do; per enrollment/appState read, hot only…
- [021] `Action`s/`slots` list plumbing (`actions`, `State.coordinates`, ApplicationGrainSession.lean:90-131): builds several 4-element intermediate lists per operation target; negligible.
- [022] CertifyReceiver.lean:481–498 (`authorize`) recomputes `request …` and `policyConfig prepared` 3–6× per certify, and `(step prepared)` twice more (:489, :492); each `step` → `project` (:415–427) re-ru…
- [022] CertifyReceiver.lean:238–243 + :268 + :294 + :308 + :541 (`marker`): the SHAKE256 identity hash is recomputed 3–5× per certify (in `declaration`, `request`, `context`, `policyConfig`, `admitNative`);…
- [022] ClockTickReceiver.lean:433–513, 552–566: the identical `authorize`/`project`/`marker`/`request` recompute pattern (ticks run per scheduled tick, NativeHost.lean:2312, not per request).
- [022] CertifyReceiver.lean:299/302 + ClockTickReceiver.lean:319/322: `commandCodec.encode command` re-encoded per `context` call and again per `argsDigestBytes` invocation — several full stream encodes per…
- [022] DurableCheckpoint.lean:335–339 (`State.ofSnapshot`) materializes a checkpoint via `image.cellIds` (an eraseDups over every write in the log) plus `snapshot.canonicalBytes` per cell (O(cells²) with th…
- [023] Host/Main.lean:1449 — per-stride `worldRoot` over `log.take (i+1)` makes the kept-roots audit O(steps × whole log); fine for an operator bench, listed only because it shares the `Image.currentBytes` …
- [023] `Image.currentCells` (Kernel/DurableReceiver.lean:212-215) — full `Image.restore` then per-cell snapshot reads; only used on operator/manifest surfaces now that `Loaded.cells` exists.
- [024] Kernel/JobMoneyReceiver.lean:752 `signingHeader` re-loads authority/pay/directory/book/job and re-runs `JobMoney.decideMoney` + `request` + `marker` on every call — drafting/signing path, not the tur…
- [024] Kernel/FleetTurn.lean:141/:158/:634 and JobMoneyReceiver.lean:135/:158 — `commandFrame`/`ingressFrame` re-run `"…".toUTF8.toList` on every codec encode/decode call; constants, trivial.
- [024] Kernel/GrainResourceBirthReceiver.lean:57 — `"DREGG/GRAIN-RESOURCE-BIRTH/EVENT/v1".toUTF8.toList ++ digestStream.encode domain` rebuilt per `event` call (rare path).
- [025] Kernel/MeterRefillReceiver.lean:276–284 `signingHeader` — `loadDeployment` + full `request` + `marker` built per plan call; one-shot operator verb (`meterRefillPlanLoaded`, NativeHost.lean:2135), acc…
- [025] Kernel/JointReceiver.lean:84–100 `applyReserved` — `digestStream.encode config.deployment.domain` re-encoded per call; one reserve per submit, negligible.
- [026] One-shot verbs (`NativeHost.submit` :3420, `lookup` :3553, `challenge` :713, `query` :1036, `prepare` :994, `enrollmentSubmit` :1400, …) each cold-open the Store (`openExisting` = full load + `valida…
- [026] `wellLedgerLoaded` :2258 — `accounts.sort` then a nested `(accounts.filter (· ≠ asset)).filterMap` with a `logical.balance` lookup per pair: O(A²) balance reads per ledger call.
- [026] `payLedgerLoaded` :2445 — `List.range (PayCell.nextFree store)` with `assignmentAt` per index: O(assigned) lookups plus a full range materialization.
- [026] `enrollmentPlanAuthorizedLoaded`/`provisionPlanAuthorizedLoaded` :436/:553 — the command bytes are codec-decoded twice per plan-op (once in the wrapper, again inside `enrollmentPlanLoaded`/`provision…
- [026] `staleObservableTarget` :3064 — `find?` over targets with directory slot lookups and `observesWhole` per target; runs only on stale-target rejections in `staleOutcome` :3088, so it taxes the rejectio…
- [026] `operatorAcceptedLogOfDurable` :1686 — explicitly operator-only (`Reader.range` windows of 256); fine as designed.
- [027] Kernel/NativeHostGenesis.lean:991 (`build`): `decide ((entries profile config).map Sigma.fst).Nodup` — O(n²) duplicate decide over the whole entry list, plus `Config.Valid`'s decidability instance (:…
- [027] Kernel/NativeHostGenesis.lean:315/316 (`configRawCodec.decode`): `bytes.take configFrame.length = configFrame` List ops per decode — genesis source load only.
- [027] Kernel/NativeHostContext.lean:335 (`Config.scratch`): fresh key write per call — operator scratch setup only.
- [027] Kernel/NativeHostGenesis.lean:838–839 (`pins`): `factoryPolicy profile config` (which builds the whole confined predicate) computed twice per call — genesis only.
- [029] Kernel/NativeHostStoreIdentity.lean:28–34 — `storeIdentity` CSHAKE over `List UInt8` with a `++`-built customization; genesis/startup only.
- [029] Kernel/NativeHostReserveBirth.lean:60–73 — `withReserveGrants` runs `decide (TemplateBound …)`, `decide (ReserveTemplateBound …)`, `decide result.GrantIdsDistinct` (full runtime decisions over descri…
- [029] Kernel/ObjectAudienceInstall.lean:97–106 — `prepare` evaluates `Decidable (SupportedObject …)` and `Decidable (ObjectAudienceController.Bound …)` (directory slots lookup + cell-law decision) per audi…
- [029] Kernel/NativeHostReplay.lean:3688–3689 — `admissionPhase` (16 × `String.toUTF8` + prefix `find?`) computed twice per record, but only when `MINI_AUDIT_TIMING=1` (AuditTiming thunks are disabled-by-de…
- [029] Kernel/NativeHostReplay.lean:4311/5046 — `verifyLoadedSelected`/`verifyBytes` one-shot audit entrypoints re-walk genesis; fine for their purpose.
- [030] Kernel/ObjectiveActivityReceiverCore.lean:2785–2793 `planOutcome` and ObjectiveActivityReceiver.lean:188–240 `planVerdict`/`planReport`/`planFrontEnd` each re-run the full `decideTurn`+`finish`; prod…
- [030] ObjectiveActivityReceiver.lean:203–219 `signingHeaderFor` repeats `loadDeployment` + `signedRequest` + `marker` that the submit will redo in `gate`; operator-facing plan/sign latency only.
- [030] Kernel/ObjectiveActivityReceiverCore.lean:1095–1596 the refusal codecs (`activityRefusalStream` and friends) are enormous 0-ary structures, but they only run when a charged failure is encoded/decoded…
- [031] `signingHeader` (PayAssignmentReceiver.lean:595–605, PayBookReceiver.lean:640–654): client-side helper re-derives authority/pay loads, `marker`, and full `request` per signing call — fine off the hot…
- [031] Concrete poles (`owner_assigned`, `genesis_change_accepted`, etc., `decide +kernel`): elaboration-time only, no runtime cost.
- [032] PayEnrolReceiver.lean:1699-1707 — v1 `signingHeader`'s fallback declaration builds `marker` and loads the pay cell even when the subsequent `plan` failure is already known; one-liner reorder.
- [032] PayClaimReceiver.lean:151-163 (`decisionBytes`) / PayEnrolV2Receiver.lean:105-118 — `decisionBytes` re-encodes origin+consumption+tip+record on every `declarationOf`; only matters off the hot path (q…
- [033] Kernel/PayReceivingContract.lean:48 `frames` / :53 `parameters` rebuild 14+ UTF8 `List UInt8` conversions per call; each call of `CanonicalRuntimeProfile.encode` (Compiler/CanonicalRuntimeProfile.lea…
- [033] Kernel/PayPendingRotation.lean:105 `patch`/`decidedPatch` — fine; no other waste beyond the findings above.
- [033] Kernel/PayObservationReceiver.lean:143 and PlatformInstallReceiver.lean:175: `"...".toUTF8.toList` domain-separation constants re-derived inside `marker` on every call — negligible individually, free…
- [034] Kernel/PurseRefillReceiver.lean:610–638 `signingHeader` calls `AgentGrain.readState command.task purse.logical` twice (lines 626 and 630) and re-runs `decideRefill`'s inputs; bind once.
- [034] Kernel/PurseRefillReceiver.lean:248–267 `context` embeds `argsDigestBytes := fun bytes => … commandCodec.encode command …`, re-encoding the command per consumer invocation; same closure pattern in Re…
- [034] Kernel/PurseRefillReceiver.lean:174–179 `marker` re-encodes the identity tuple per call; every caller listed in finding 8 pays it 2×+ per call site.
- [034] Kernel/ReceivingLaw.lean:156 `birthSlot` allocates `"birth/" ++ toString cell` per `namesBirth` probe (O(#authorizers) string allocs per birth judgement) — precompute the slot per write.
- [035] Kernel/TurnLog.lean:87–104 `genesisOfSeed`: `ids.Nodup` (quadratic `decidableNodup`) plus the failure diagnostic `ids.find? (ids.count c > 1)` (another O(n²)); genesis/one-shot.
- [035] Kernel/TurnLog.lean:224–228 `turnLogRoot`: re-encodes (`bytesOf` → `encodeCell`) and re-hashes every listed cell per call, and Kernel/TurnLog.lean:232 `idsOf` uses quadratic `eraseDups` where Kernel/…
- [035] Kernel/TurnLog.lean:120–130 `followFrom` + `writeLog`: whole-log replay on every reopen over `List UInt8` entries with the List codec spine — startup/audit, not per request.
- [035] Kernel/SeatReceiver.lean:97–103 `planVerdict`: runs a full `decideTurn` to produce a human-readable string — if ever wired into a request verb it doubles finding 1; currently I found no caller outsid…
- [035] Kernel/NativeHost.lean:2728 `seatAssemble`: decodes the whole command only for `.isSome` — one redundant decode per assemble op.
- [036] Kernel/TurnRecord.lean:114–120 `singleTurn` embeds `H.legBytes … + H.eventBytes ev` inside the charge closure — same per-query re-encode pattern as `chargeOf` above (with `eventBytes` a full event en…
- [039] Nothing in this shard is operator-CLI-only; all files here are resident/request-path or per-dispatch rails. The `sign_slots`/`verify_payer_slots` JSON-comparison items under the micro-cluster are the…
- [041] main.rs:11–17 — test-local `hex` builds strings via `format!` per byte (startup/one-shot only; `canonical::hex` is the good version).
- [041] agent_api_server.rs:102–113 `reclaim_socket` and 323–388 `bind`/`preflight_parent` spawn getfacl/setfacl and walk ancestors with a stat per ancestor — operator verbs, rare.
- [041] mini-spk-broker.rs `backup` verb — one-shot consistent copy, no hot path.
- [042] `Request::Place` (broker.rs:915-931): reads and serde-parses **every** placement file to find a free UID, per Place — rare (per new app); a single cached bound-set or a free-UID bitmap file would do.
- [042] `Broker::load` per one-shot checkpoint command (broker_checkpoint.rs:182, 190): the `PINNED_DIGESTS` cache (broker.rs:434) is per-process, so each `checkpoint check`/`backup` one-shot re-hashes the 1…
- [042] spk-data-publish.rs: clean (bounded reads, one-shot operator tool); nothing to report.
- [042] spk-sandbox-probe.rs: test-image-only probe, never production (header comment, line 3); nothing to report.
- [043] broker_runtime_adoption.rs:36–72 — `adoption()` re-reads the runtime record JSON, SHA-256s the whole admission file (≤4 MiB bound, line 51) and re-parses the admission evidence on every call; `requir…
- [043] broker_home.rs:100–205 — `render` re-runs the full `validate` inventory walk (canonicalize + per-component symlink_metadata + `read_dir` per dir, up to 256 paths) and re-reads 3 + per-entrance custod…
- [043] descriptor_native.rs:75–210 — `author_signed_package` performs four host process spawns (schema author/inspect, package author/inspect, via `source_step` at 105–158) plus repeated `hex(&schema)`/`hex…
- [043] completion_custodian.rs:15–55 — `pinned_context` re-parses the entire host config and re-derives the Ed25519 key per lifecycle verb (START/report/stop/retry call sites); rare, fine as-is.
- [045] dispatch_native.rs:749 `store_tag` / :763 `continuity_namespace` / :1402 `admit_resident_route`: each runs a `profile` helper spawn + JSON parse; startup/registration frequency only.
- [045] export_receipt.rs:75 `prepare`: `windows(4).position` header scan and receipt JSON+hex build — opt-in GET capture only, bounded by the 64 KB header check; no action.
- [046] `stage_package` (grain.rs:482-508): the SPK is read and SHA-256'd up to 3× per install — hash the input (:485), hash again while copying (:496), then unconditionally re-hash the just-written, just-ve…
- [046] `status` (grain.rs:1357-1360): spawns **two** `systemctl --user show` processes per generation (`unit_active` + `unit_property(…, "Slice")`); one `show --property=ActiveState,Slice --value` invocatio…
- [046] `scan_runs` (grain.rs:864-944): re-reads and re-parses `resident.json`, admitted, stop-plan and recovery JSON for every generation on every verb (start/stop/status/supervise/export each pay it, super…
- [046] `retained`/`selected` (grain_agent_route.rs:145-211): `selected` is O(records²) duplicate checks plus a per-record replacement-chain walk, run twice in `register`; bounded at 64 records — harmless to…
- [046] fixture_os `stop()` (fixture_os.rs:405-440): after the 20 s deadline it re-SIGKILLs and re-polls every 20 ms while the state file still says active; bounded by the manager exiting, but the kill shoul…
- [046] `routes()` (grain.rs:1041-1069) re-reads and protocol-checks every route dir's `route.json` + `dispatch-custody.json` per START; these are immutable derived records — a mtime/size-keyed cache would d…
- [047] `session_intents` (grain_profile_upgrade.rs:426–475) reads+parses each route's `dispatch-custody.json` three times per route — `routes()` at grain.rs:1061, `read_json` at 445, `file_sha256` at 460 — …
- [047] `verify_import` (grain_export.rs:169/183/187) fully copies the image and hashes it twice (source and staged); a hash-while-copy or reflink (the `fs::rename` fast path in `write_export`:88 shows same-…
- [047] `stopped` (grain_profile_upgrade.rs:319–367) spawns `systemctl show` synchronously and serially per app × generation during rebind; batchable into one `systemctl show` per unit list or parallelized.
- [047] `route` (grain_route.rs:262) runs `verify_installed_spk` (full package signature verification) plus 4 evidence-file reads on every invocation even when the route directory already exists; the re-deri…
- [047] `reconcile_failed_start`'s `observe` (grain_export.rs:350–363) fsync-retains + subprocess-inspects every Host reply, and `retain_exact` (263) re-reads up to 32 MB to byte-compare an already-retained …
- [048] hostd.rs:523/566 (`UnitStopAudit::source_stop_audit`): hand-rolled hex and decimal big-endian conversion loops — stop path only, once per STOP.
- [048] hostd.rs:813/815 (`Journal::audit_failed_start`): two `systemd_show` spawns bracketing the audit as a changed-during-audit check — failure path only, deliberate.
- [048] hostd.rs:1080 (`allocate_dispatch_operation` missing-counter fallback): full directory scan — only on counter loss, fail-closed by design.
- [048] hostd.rs:888 (`Journal::open`): ancestor-walk with `symlink_metadata` per component — startup only.
- [050] lifecycle_v3_completion_native.rs:184-189 (`assemble_once`): the signed report (bound ~12 MB) is hex-embedded into `request.json` (2× size), written to disk, and re-parsed by the Lean child — a hex r…
- [050] install_v3.rs:393-395, 514-518, 653-654 (`preflight_complete`): `Sha256::digest` of the same `begin.ingress`/`claim.committed` buffers recomputed up to 3× each across the flow (MB-bound buffers, ~ms …
- [050] launch_descriptor_native.rs:127-146 (`run_step`): 25 ms `try_wait`/sleep polling loop for the child; ≤25 ms added latency per step and wakeups — `wait` + a deadline thread (or `waitpid(WNOHANG)` at a…
- [050] dispatch_native.rs:587-595 (`invoke_until`): re-parses the 64-char hex host pin into bytes on every invoke — trivial, but it's per-call work a one-time field would remove. Per invoke.
- [050] io_context.rs:15 (`ctx`): formats an error string with path on every failure — fine as written (error path only); no finding, noted for completeness.
- [051] **Fresh Lean host process per `author`/`inspect`/`signatures` helper call** — dispatch_native.rs:518 (`tool_until`, `Command::new(executable)`), hit 4× by `submit_once` (lifecycle_v3_native.rs:470/49…
- [051] **`write_new` fsync pair for every retained artifact** — dispatch_native.rs:88 (`file.sync_all()` + directory `sync_all()` per call), called ~15× per begin verb from these files (request.json, both m…
- [051] **`sign_pinned_slots` re-derives the Ed25519 key per slot** — lifecycle_v3_native.rs:172, calls `private_signing_key(&pin.seed_path)` (dispatch_author.rs:226: 4 metadata custody checks + file read + …
- [051] **Whole-frame hex re-encodes across `prepare_once`** — report_native.rs: `hex(&begin.ingress)` computed 4× (124, 149, 234, 268) and `hex(report)` 3× (148 via each `checked_report` call at 230/291, pl…
- [051] **Duplicate hex + double marker serialization in STOP** — stop_native.rs: `hex(retained_plan)` twice (129, 143) and `hex(fresh_committed_frame)` twice (130, 150) in `from_verified_inspection`; `marke…
- [051] **Avoidable 2 MB copy in `inspect_current`** — stop_claim_native.rs:71 returns `payload.to_vec()` after `write_new` already retained the exact bytes, and the caller re-borrows it; return without the …
- [052] `encode_nat_decimal` (lifecycle_v4_retry_native.rs:80) is O(digits²) repeated long division, but inputs are ≤~78-digit decimals (u128 nonces, roots) — trivially fast; fine as is.
- [052] `write_new` fsyncs the file and its parent dir for every artifact (dispatch_native.rs:88–103), ~20–40 fsync pairs per STOP/retry flow — that is the crash-consistency design, not waste.
- [052] `hex(&evidence.begin)` / `hex(&evidence.committed)` recomputed at several call sites in `prepare_report` / `signed_report_retained` / `checked_report_view` (lifecycle_v3_stop_service.rs) — KB-scale, …
- [052] `set_aside_pure_begin` performs up to three directory fsyncs (lifecycle_v3_stop_service.rs:1100–1104) — rare and durability-motivated.
- [052] `completion_dir` replan chain (lifecycle_v3_stop_service.rs:892) is depth-bounded at 8 with per-level stats — fine.
- [053] materialize.rs:70–101, 316–323 (`write_tree`/`materialize_spk_with_profile`): `sync_all` per extracted file plus a per-directory sync walk and three artifact syncs — an fsync storm per install; accep…
- [053] materialize.rs:154–158 (`verified_identity`) and main.rs:11–17 (`hex`): hex strings built with `format!` per byte; trivial at operator frequency.
- [054] `RouteControl::apply` (resident_route_control.rs:484-496): linear scan of `accepted` (≤64) per registration — fine, enrollment-only.
- [054] `RegistrationPublisher::publish` (resident_route_control.rs:342-346): builds the 64-char fingerprint with per-byte `format!("{byte:02x}")` (32 small allocations) — enrollment-only, harmless.
- [054] START/reconcile path (`load_retained_start`, `reconcile_prior_start`, `retire_start_markers`, `ResidentConfig::load`, resident_service.rs:499-762/1023-1140/1142-1269): reads and SHA-256s a dozen smal…
- [054] Everything else I read in both files is proof of the one-shot lifecycle design doing bounded, per-generation work; I found no repeated re-derivation, no `List UInt8`-style representation traps, and n…
- [056] `publish` (shared_data.rs:538) walks the tree 4× and `sync_all`s every file and directory — one-shot operator CLI (`spk-data-publish`); fsync storm is deliberate custody, the 4 walks are not (see fin…
- [056] `audit` (shared_data.rs:782) re-hashes every payload byte — deliberate (it is the bit-rot audit).
- [056] `paused()` (volume_helper.rs:141) re-parses and re-SHA-256s `record.json` + `resident.json` per volume per `volumes-status` call — operator status verb.
- [056] `Registry::load` (volume_helper.rs:33) re-reads/re-parses the root registry JSON on every helper invocation including every `call()` — one sudo-forked process per verb already dominates.
- [059] application_enrollment.rs:79 `quiescent` — `serde_json::to_value(j)` serializes the entire typed Journal just to test the raw `providerRetryGate` field, and `run` already performs that exact check on…
- [059] application_enrollment.rs:486 `run` — journal parsed three times (`current` Value, `Config` clone at 569, `Journal` clone at 574) plus a full Value clone + pretty re-encode in `successor` (479); on a…
- [059] application_enrollment.rs:287-419 `native_query`/`source_dispatch` — 5+ sequential spawns of the pinned Host binary per enrollment; each is a full Lean process cold start, so bootstrap-dispatch enrol…
- [059] birth_refusal.rs:511 `adopt_legacy_session_refusal` — `retained_refusal_query` is called 4× (ids −2, −1, +5, +7) at 3 `refusal_codec` Host spawns each, plus 3 `mini` spawns in `replay_refusal_cleanup…
- [059] birth_refusal.rs:70-82 `bind_terminal_files` — hashes the 4 terminal evidence files, then `verify_terminal_files` immediately re-reads and re-hashes the same 4 files (2× reads of up to 4 MiB); read-b…
- [059] birth_refusal.rs:22 `legacy_execution_trace` — two full passes over `reconciliation_log` (max-scan then `any`); only reachable from the legacy adoption above.
- [060] control.rs:387–389 / control.rs:100–102 / dispatch_custody.rs:295–297: nonblocking accept loops spin with `sleep(20ms)` (3 listener threads ≈ 150 wakeups/s and up to 20 ms connect latency); a blockin…
- [060] concierge.rs:712–716 + 723–750 (`deliver_window`): per subject per pass, scans the whole outbox directory and stats every `renew-t*.json` for mtime; could record the delivered path in the journal ins…
- [060] concierge.rs:462–470 (`Runner::mini`): scans all `"\n{"` indices of stdout and re-attempts JSON parses backwards over candidate starts; harmless at current sizes, worst case re-parses the whole stdou…
- [060] custody_gate.rs:19 vs deadline.rs:26: two different capture bounds (1 MiB vs 16 MiB) and two parallel drain implementations; unifying would remove one polling loop (maintenance, not perf).
- [061] grain_create.rs:552–593 (`author_birth`): up to 8 read-and-author generations, each a signed `mini query` turn + a host authoring; a refused authoring discards the observation and re-pays a full sign…
- [061] grain_create.rs:216–225, 350, 360, 697 (`birth_confirmed`/`needs_genesis`): outcome.json re-read and re-parsed several times per create run — trivial, but one read would do.
- [061] grain_create.rs whole file: `create` chains ~10–20 `mini` subprocess spawns serially (query/author/submit/workspace/propose/delegate per witness); fine for a one-shot operator command, same batching …
- [061] gitweb_worker.rs:493, 568, 593–606: 4–5 local `/usr/bin/git` spawns (symbolic-ref/add/commit/rev-parse) per edit — negligible next to the forwarded turns.
- [061] hermes_room.rs:468–475 (`attach`): the tool `functions()` list is re-built per provider round; `room_tool_specs` is static — hoist, trivial.
- [062] hermes_session_verify.rs:64, :86 — `verify_hermes_session` performs two full signed parent queries (`Runtime::query`, main.rs:7527, a signed host observation each) per verify-session run; readiness v…
- [062] hermes_session_verify.rs:61, :93 — `serde_json::to_value(&self.journal.provider_replays)` computed twice per verification to compare before/after; trivial, only worth folding into a shared snapshot i…
- [063] main.rs:2086 (`Journal::validate_workspace`) — per-proposal double file read+hash at startup is the dominant part of the restart cost above; listed there.
- [063] main.rs:2710 (`next_retry_json`) — worst case ~20k `exists()` stats if an attempt directory ever accumulates thousands of retry files; bounded loop, only the uncertain-recovery path.
- [063] main.rs:2539 (`inspected_pre_submit_refusal`) — recovery path spawns the Lean host (`inspect outcome`) and re-reads a 12 MB signed observation per verification; rare by construction (only when a pre-…
- [064] `validate_resource_workspace_record` (3425–3471): 5 `symlink_metadata` + bounded read + JSON parse per validation — per tool-task spawn, fine.
- [064] `worker_env` (3644–3694): `Broker::load` re-reads the broker file per worker launch — prompt-scoped, fine.
- [064] `reserve_parent_work_lease` (3568–3589): one extra `self.query()` subprocess per prompt start — prompt-scoped.
- [064] `prove_launcher_gate` (3635–3643) and `open()`'s validation chain (6619–6622): startup-only.
- [064] `confirmed_publication_receipt` (6675–6786): per publication settle (rare); unbounded `fs::read` of source at 6714 after a bounded hash read — inconsistent but rare.
- [065] `inspect_application_api` (main.rs:8914) re-hashes the retained request and does socket exchanges — crash-recovery only, rare.
- [065] `verified_publication_report` (main.rs:7173) re-hashes call/outcome and spawns `mini retry --mode lookup` per receipt (7236, 7273) — recovery report, capped at 4+4, rare.
- [065] `require_managed_worker_policy` (main.rs:7677) shells out to `mini author` per candidate generation (7705, 7716) — policy renew only, rare.
- [066] main.rs:10524–10616 `finish_no_birth`: up to 3 signed queries + settle + disconnect per no-birth release, each a full `mini` process spawn plus an ID-allocating journal save — per birth attempt, rare.
- [066] main.rs:10423–10523 `provider_settle`: `query_as` at 10470, again per fresh-retry (10500), again at 10509 — 2–3 process spawns per settle; fine to keep, but the pre-loop signed hold check (10470–1047…
- [066] main.rs:10695 `create_resource` host-image hash per birth (covered by finding 1's memoization fix).
- [066] main.rs:11630–11636 `workspace_submitter_stopped` / `reconcile_foreground_audited` 13327–13400: bounded scans, no issue found.
- [067] `recover_v2_dispatch_reserve`: `sha256_file(&directory.join("call.bin"))` computed twice (15616 and 15703); same twin in `recover_v3_dispatch_reserve` (15934 and 15941) — startup-only, hash once into…
- [067] `reconcile_provider_evidence`: third same-authority signed query at 16854 (`provider_signed_route(&self.query_as(&authority)?, pin)`) re-reads state already observed unchanged at 16803 — one spare mu…
- [067] `run` (14153–14248): fixed 20 ms `thread::sleep` poll loop with `child_exited_unreaped` + `try_recv` per iteration for the whole worker lifetime — constant wakeups while any plain worker command runs…
- [067] `disconnect`/`reconcile_*`: `unresolved_external.iter().any(/e/ e == note)` linear scans before push — negligible at current sizes, becomes O(n²) if the list ever grows; use a `HashSet` alongside.
- [068] main.rs:17886–17889 `status` verb double-serializes: `serde_json::to_value(&rt.journal)` then `serde_json::to_string_pretty` of the projection — two full passes for one pretty print.
- [068] main.rs:17712–17722 `forward_display` allocates a `String` per 4 KiB chunk (`from_utf8_lossy(...).into_owned()`); trivial CPU at normal worker-output volume (and note as a correctness aside, chunk-bo…
- [068] main.rs:17179 `acknowledge_effects_with` spawns one signed `mini query` per authority (≤3) per reconcile — that spawn *is* the signed-query protocol, listed only for completeness.
- [070] native/grain-runtime/src/provider.rs:929-932 `error_reply` builds a JSON body with `json!().to_string()` per error — fine, but called from the busy-responder thread per rejected connection under load.
- [071] provider_owner.rs:27 `observe` — SHA256s the `mini` binary, host binary and host config twice per call (:43/:69), and `grant_evidence` (:86) calls `observe` a second time → 4× binary digests per prov…
- [071] provider_provision.rs:75 `query_only` — serializes the entire journal twice per call (current + a freshly built `Journal`) and compares `Value`s; invoked twice in `run` (:162, :182); one-shot CLI ver…
- [071] provider_owner.rs:127 `source_height` — a full `mini query` subprocess per call; provisioning only.
- [071] provider_homelab_tests.rs — entirely `#[test]` code (scheduler/gateway fixtures); zero runtime cost, no findings.
- [072] resident_context.rs:52–68 `brief` clones the entire context bundle before trimming — bounded (~100 KB), per prompt, negligible.
- [072] resident_completion.rs:649–681 `client` and quiescence.rs:377–396 `client` — one-shot operator socket verbs, no hot path.
- [072] resident_compute.rs:89–102 `pay`'s durable republish per paid turn matters only when many turns land in one settle — folded into finding 4.
- [072] publication_refusal_tests.rs — `#[test]`-only; zero runtime cost.
- [073] resident_reconcile.rs:208-270 `commit`: 6 write_new + 4 dir `sync_all` calls per failed-prompt reconciliation — recovery path, durability by design, fine.
- [073] resident_delivery.rs:952 `drain_completed`: re-reads the controller journal (bounded 4 MB) and makes two admin socket round-trips at every resident loop exit/completion — per turn, necessary for its …
- [073] resident_delivery.rs:685-697 `retained_final_resolution`/`delivery_receipt`: linear scans of `room_resolutions` with whole-Value comparisons per delivery — bounded by journal history, ms at worst.
- [074] resource_tools.rs:84 `validate_birth_families` — O(families² × births) namespace scans and repeated `id_range` string parses; config/startup only, bounded at 8 families.
- [074] room_resident.rs:130/137 vs 400/416 — `prompt_assignment` and `assignment_fingerprint` each computed twice per resident prompt with full `Value` clones of the whole prepared assignment; ms-scale besi…
- [074] resource_tools.rs:592 `read_resource_with` pretty-prints the intent JSON per resource read (`to_vec_pretty`); trivial, but compact would halve the bytes.
- [074] room_resident.rs:287-309 `publish_notices` — up to 4 invocations per resident pass; cheap when the queue is empty (a file read), but each *owed* notice costs 3 host turns (pay + fresh `mini_stream_en…
- [075] terminal.rs:224–240 `render_untrusted` formats one `write!` per character through `std::fmt`; a multi-MB `output` frame (bound 8 MiB, terminal.rs:14) renders slowly — scan chunks for unsafe chars and…
- [075] terminal.rs:124–151 `parse_status_command` collects the whole line into a `Vec<&str>` to match a 4-element slice; per input line, negligible but avoidable with `splitn`.
- [075] systemd_manager.rs:168 `launch_client` re-serializes config+path to JSON solely to hash a "bindingSha256"; one-shot operator verb, fine as is.
- [075] terminal.rs `state`/`completion` (via public_status.rs:5) run per status event and per public status call; they are a few dozen map lookups on bounded keys — no action needed.
- [076] Compiler/AirFlatten.lean:577–631 — `exFlat`/`exAsg`/`exForced` demo defs and their `decide`s: proof-time only, no runtime concern.
- [076] Compiler/AirModularView.lean:620–660 — `demoWires`/`demoAsg`/`demoBit` runtime defs exist only to feed the `decide` teeth examples; not called by any tool.
- [076] Compiler/BabyBear.lean:31 — `babyBearP := 2013265921` is a def with no arguments (re-read per use), but it is below 2³², so it does not hit the `lean_cstr_to_nat` decimal-parse hazard; no finding.
- [076] Compiler/Air.lean:150–182 — `boolGadget`/`eval`/`evalExec` compute, but their only callers are theorems, `decide` witnesses, and `Prop`-valued defs in `Assurance/SelvageV0Manifest`; not on any runtim…
- [077] Compiler/BignumKernelABI.lean:243 (`writeKernelCallJson`) / :234 (`kernelCallToJson`): full descriptor→JSON emission incl. `descriptorToJson` and `toString call.modulus` decimal Nat — only reachable …
- [077] Compiler/Blake3.lean:217 (`toHex`): `String.ofList (b.flatMap …)` with `Char.ofNat` per hex digit — used by scripts and `FnWirePinned` digest comparison only.
- [077] Compiler/CanonicalResourcePageMaterializer.lean:199 (`wireFrame`): the 16-byte frame list literal is rebuilt per `framedCodec` encode call (no-arg `def`); trivial, but a `let`-bound constant in the c…
- [077] Compiler/CanonicalPolicyAdmission.lean:861–957 (`demoRecord`…`demo_reflects_source`): the whole demo section is elaboration-time fixtures (`by decide` teeth); no runtime cost.
- [078] Compiler/CarriedSegmentIO.lean:256–264 (`stageAuthorized` foldRange): `window.map intentStream.encode == (remaining.take ...).map encode` re-encodes both sides per window and then every remaining rec…
- [078] Compiler/CarriedApplicationProvenance.lean:104–113 (`selectIssue`): `intentStream.encode record` computed up to three times (membership check, and both sides of `sameBytes`) — one `let` would do. Run…
- [078] Compiler/CarriedSegmentIO.lean:119–136 (`auditSource`): spawns the retained old host executable twice and string-compares stdout heads; fine for a one-shot carry, list only.
- [078] Compiler/CarryConfiguration.lean:30–39 (`checkLegacy`): whole-JSON rebuild via `setObjVal!` + `foldl erase`; one-shot tool, negligible.
- [078] Compiler/CredentialAuthorityCell.lean:435–441 (`retiredStateFrame`/`retiredPageFrame`): List-of-literal frames; proof-side only, no runtime concern.
- [079] Compiler/Emit.lean:168–173 (`flattenSystem`): per-term `fo.gates ++ rest.gates` is quadratic list append (the 2.7 M-gate spend would do O(n²) pointer work); today only `#eval`/build-time consumes it …
- [079] Compiler/Evaluator.lean:461–462 (`registryManifest`): rebuilds the UTF8 byte lists per call; trivial, operator/profile path only.
- [079] Compiler/CredentialAuthorityServed.lean:59–60 (`servedRows`) + `loadServedDirectory`: full whole-store decode per call, but the turn path uses the incremental `loadServedDirectoryFrom` (Kernel/Native…
- [080] Compiler/MinidreggV1Artifact.lean:99–102 — `residueRingCarrier` embeds three ≥2^32 Nat literals (`68719403009, 68719230977, 137438822401`): each demand of the carrier re-parses them from decimal stri…
- [080] Compiler/GenericSimplexIO.lean:574–586 — `verifyAttestations` re-derives `(signers.map Attestation.signer).eraseDups` per certificate; quorum-sized, operator/verification path only.
- [080] Compiler/GenericSimplexIO.lean:712–728 — `auditSegments` re-scans and re-replays every retained segment from genesis per audit; operator audit verb only.
- [080] Compiler/GenericSimplexSourceAnchor.lean:36–48 — `anchorBytes`/`semanticMembershipBytes` re-encode whole contexts per call; genesis/context-construction frequency only.
- [080] Compiler/MinidreggV1Artifact.lean:446–448 — `bundle_encoding_roundtrip` decodes the whole canonical encoding; theorem-side, but `bundle.canonicalEncoding` itself is rebuilt per demand of `bundle` (no…
- [081] NeutralCarriedSegmentIO.lean:72-84 (`prepare`): `plan.changes` evaluated twice in one body (`writesDigest plan.changes`, `prepareDerived … plan.changes`) and once more in `NeutralPolicyCarry.finishPl…
- [081] NeutralPolicyCarry.lean:163,193,403 (`collectSources`, `liftSources`, `deriveStoreV2`): `sources := sources ++ [⟨…⟩]` and `bindings := bindings ++ [⟨…⟩]` O(n²) accumulation; `bindings.find?` inside t…
- [081] NeutralPolicyCarry.lean:396-403 (`deriveStoreV2`): decodes then re-materializes and re-encodes every non-source cell (`LifecycleImage.bytes registry (.live cell) != bytes`) just to detect unchanged c…
- [081] NeutralCarriedSegmentIO.lean:45-59 (`checkTarget`): spawns the target host process (`IO.Process.output … "profile"`) and re-reads multiple files per carry — intentional verification, rare.
- [081] NeutralCarriedSegmentIO.lean:95-106 (`receive`): re-derives the entire plan at receipt — documented as deliberate (re-derivation is the point), listed only for completeness.
- [081] Compiler/NoteSpend.lean — proof-only file: the shielded-spend system (`noteSpendSystem`, `spendAsg`, `spendPath`, `demoNfSpec` over ZMod 13) exists for theorems and `by decide` witnesses; runtime con…
- [081] Compiler/NativeInvocationStatement.lean — besides the frame-per-call aggravator above and the known List-UInt8 codec spine, the codec defs are single-pass and canonical; nothing recomputed.
- [082] Compiler/ObjectiveBendElaborate.lean:2180–2196 (`runJob`) re-decodes every module's JSON per job in a batch — fine for a batch driver, just noting it shares all elaborator costs above.
- [082] Compiler/ObjectiveBendFrontEnd.lean:128–131 (`positive`): `toString n != text` Nat↔decimal round trip for canonicality — tiny, options-parsing only.
- [082] Compiler/ObjectiveBendFrontEndIdentity.lean:65 (`identity`): SHA-256 of the manifest recomputed per evaluation; each occurrence costs a pure-Lean hash over a few hundred bytes. It is compared in the …
- [082] Compiler/ObjectiveBendLaw.lean:171–191 (`tokenize`): `List Char` takeWhile/dropWhile with `(c :: rest).takeWhile`-style rescans per token — laws are one line at install; fine as is.
- [082] Compiler/ObjectiveBendElaborate.lean:486 (`duplicate` via `eraseDups.length`) — O(n²) per call but n = params/methods, small; compile path.
- [083] Compiler/ObjectiveBendPublication.lean:108/:116 — `publishedCore` and `publishedLaws` each run the full front-end `replay p` (parse all modules + lower); Host/ObjectivePackageAuthor.lean:109–114 and …
- [083] Compiler/ObjectiveBendParse.lean:120 (`searches`) — O(n²) rescan (drop 1 per position) with a per-position `Array.replicate 10` and 64×-fuel CPS backtracking over `List Char` (`run` :74, `anchored` :…
- [083] Compiler/ObjectiveBendParse.lean:549 (`lastIndexOf` — `List.range` + `find?` + `drop` per candidate, O(n²)) and :265 (`splitPieces`) — per-line parse cost, authoring only.
- [083] Compiler/ObjectiveBendPublication.lean:64–72 — `imports := imports ++ [ … ]` append accumulation per module (≤64 modules); trivial but free to fix with a reverse-accumulate.
- [083] Compiler/ObjectiveSourcePackage.lean:99–103 — `wellFormed` indexes `p.modules[i]` via `List.finRange` (O(n²), n ≤ 64) and re-runs `String.fromUTF8?` per module per call; install-time only.
- [085] Compiler/RetainedArtifactIO.lean:32 `fileSha256` spawns `/usr/bin/sha256sum` per call — Host inspection/probe verbs and carry registration only (Host/RetainedSegmentInspection.lean:326, CarryInspecti…
- [085] Compiler/Sha256.lean:14/24 `k`/`initial` are no-arg defs, re-allocating the 64-entry `Array` per reference (~64×/block); only used by the Objective front-end fingerprints (Host/ObjectiveBendFrontEnd.…
- [085] Compiler/SemanticArtifactBundle.lean:273 `encodeGuardTerm` is O(n²) (`leftWord.length` after recursion, `++` accumulation); used only at artifact emission (`writeArtifactBundleJson`, `BuildTarget.run…
- [085] Compiler/SemanticArtifactBundle.lean:555 `ArtifactBundle.contentAddress` Gödel-encodes the whole bundle into a `Nat` per JSON emission — emission-time only.
- [085] native/resource-client `host_image_sha256` (main.rs:594, transport.rs:110) re-reads and re-hashes the whole host binary several times within one command (carry.rs:384–385 hashes source twice + target…
- [085] Compiler/ServedBasis.lean:321–329/140 `declaresNullifier`/`declaresTransaction` List membership and `byTx` `find?` are linear — over per-request declared keys, so small.
- [086] Compiler/TranscriptController.lean:173–175, 188–190 — `absorbAs`/`deriveAs` build `absorbed`/`draws` with `state.absorbed ++ [frame]` (O(n²) transcript log); searched all of Kernel/Host/Compiler for …
- [086] Compiler/TypedCellHyperedgeArtifact.lean:77–79, 95–98 — `LegArtifact.words` widens `declarationBytes` to a `List Nat` (`map UInt8.toNat`) and `Header.words` `flatMap`s it with append accumulation; on…
- [086] Kernel/AgentGrain.lean:659–690 — `witnessTouchState`/`settlementState` are proof fixtures for `decide +kernel` theorems; elaboration-time only, no runtime cost.
- [087] Kernel/ApplicationAgentLifetimeGrantLookup.lean:39-49 `lookupCurrent`: opens the store, builds a whole-store `rootBytes` reader and runs `NativeHostReplay.verifyLoaded` (full history verification) pe…
- [087] Kernel/ApplicationFailedStartRecoveryReport.lean:62-80 `Audit.validFor`: rebuilds `"entered"/"failed"/"inactive".toUTF8.toList` per call — trivial, but free to hoist if it ever sits on a hot check.
- [087] Kernel/ApplicationAgentLifetimeGrantIntentTemplate.lean:97-108 `charge`: each lane re-calls `ResourceBirthReceiver.charge` and the `.storageBytes`/`.turnBytes` arms re-encode the ingress/event per qu…
- [088] Kernel/ApplicationGrainBirth.lean:235–244 (`Ready.descriptorCurrent`): computes the whole `ready.descriptor` (3 policy encodes+digests, 6 grants, 3 births, quoted fee) and then replaces grants and re…
- [088] Kernel/ApplicationGrainBirth.lean:203–209 (`initialPolicy` / `Ready.initialPolicies`): `PolicyRecordCodec.digest` + full encode per policy at every genesis/birth — one-shot path.
- [088] Kernel/ApplicationGrain.lean:464–497 (`headerStream`/`requestStream`/`dispatchFrame`/`dispatchCodec`/`DispatchIntent.canonicalBytes`): legacy dispatch codec; only referenced from laws/proofs (Applica…
- [088] Every file here defines `frame : List UInt8 := "DREGG/…".toUTF8.toList` re-encoded per use, and `stableNullifier`/`event` rebuild their label-prefix bytes per call (e.g. ApplicationLifecycleClaim.lea…
- [089] `storeTag` (Kernel/ApplicationLifecycleResidentProfile.lean:50): `Nat.toDigits 16 (store.value % 2 ^ 64)` + pad-replicate + string appends per call; callers are authoring/inspection only (Host/Json.l…
- [089] `unitName`/`processIdentity` (same file:55–60): fresh string append chain + `toUTF8.toList` per `beginMatches`/`beginMatchesV3`/`claimMatches` call; all callers are Host authoring/operator verbs.
- [089] `Binding.valid` → `volumeId domain binding.app` recomputes the SHAKE volume ID per validity check, and `custodyFrame` is re-derived (`toUTF8.toList`) inside `Custody.validFor` (Kernel/ApplicationLife…
- [089] `V2Source.packageAction`/`packageTarget` re-encode `manifestBytes` per call (Kernel/ApplicationLifecycleCompletionV2Source.lean:105–129) — also hit on the admission path (folded into finding 2's fix).
- [090] ApplicationShareIssueAuthoring.lean:104-105, 128 — `prepareLoaded` encodes the finalized descriptor three times (compare ×2, SigningPlan once); operator authoring.
- [090] ApplicationShareIssueGrainAuthoring.lean:163-165, 184-190 — same triple-encode compare; plus `(source.grainCommand tariff)` rebuilt per iteration inside the observations `mapM`; operator authoring.
- [090] ApplicationPermissionSchema.lean:102-105, 194-201 — `Schema.resolve` re-encodes the whole schema + SHAKE per call (`root`), and `resolveBit` scans `added`/`removed` lists per bit (O(perms × deltas));…
- [090] ApplicationShareIssueGrainLookup.lean:63-93 — `lookupOriginal` runs the entire grain share admission (`admitNative`) to answer one receipt lookup; documented cold-caller design, but it is the expensi…
- [090] ApplicationLifecycleRetryCompletionV4Admission.lean:379-383 — `(DeclaredResourceController.writes prepared).map DataWrite.cellId` computed twice in `prepareConditional`; trivial.
- [091] Kernel/ApplicationSpkPackageIdentity.lean:284 (`Descriptor.valid`) — `signedAppId.all (· ∈ appIdAlphabet)` calls the nullary `appIdAlphabet` (:119–120, `"…".toUTF8.toList`) once per byte: 52 rebuilds…
- [091] Kernel/Base64.lean:363–366 + 384–387 (`chunks`, `encodeLines`) — list `take`/`drop` chunking is O(n²/57) and the result goes through `String.ofList`→`intercalate`→`toUTF8`; only consumer is FnSelecti…
- [091] Kernel/ApplicationShareIssueSource.lean:77–78, 109–110 (`specFrame`, `ingressFrame`) — nullary defs rebuild their UTF8 `List UInt8` per call inside the framed codecs; per share-issue, rare.
- [091] Kernel/ApplicationStreamContinuity.lean:87–92 (`select` in Compiler/CarriedDispatchProvenance.lean) — `findIdx?` over the whole accepted image comparing full `record.event.canonicalBytes` per entry; …
- [092] Kernel/CarriedSegment.lean:175-186 (`imageDigest`, `originIndexDigest`): each check in `checkBody` (:204-206) re-encodes the entire Image and all accepted intents and hashes them — per carry/migratio…
- [092] Kernel/CarriedSegment.lean:106-116 (`Body.bytes`/`Body.id`): `identityBytes`/`capsuleBytes` recomputed per call, and `Body.id` re-derives `body.bytes` per call — rare.
- [092] Kernel/CapabilityDelegationController.lean:143-147 (`undecodable`): `bytes.take retiredFrameV1.length` prefix compare per undecodable command — trivial.
- [092] Kernel/ClockCellDomain.lean:57-61 (`cellBytes`/`cellRoot`): whole clock-cell encode per `Loaded.write`/tick — tiny cell, fine as-is.
- [092] Kernel/CellTable.lean — no finding: this is the *right* representation (ExtTreeMap, not a layered function/DFinsupp or a lookup list); `ofList`/`entries` are single-pass.
- [093] `rosterDeviceGuards` (ConfidentialAudienceAdmission.lean:42) has zero callers repo-wide — dead code; its `(map …).eraseDups` is O(n²) if ever revived.
- [093] ClockLaw `pole_*` theorems use `decide +kernel` (lines 318–384) — elaboration-time only, no runtime cost; noted only to close the shard.
- [094] Compiler/LegacyContentCarry.lean:481-487 and Compiler/SourceAgreementLegacyCodec.lean:198-204 re-derive `documentOrder` + `treeFuel` (finding 3's costs) per carried document — carry/migration only.
- [094] Kernel/BirthExportAdmission.lean:63 calls `ContentResource.project 0 initial ⟨[]⟩` at birth — genesis only, but note it runs the whole `project` block for an empty store, cheap there.
- [094] Kernel/ContentResource.lean:453 `commandFrame` re-encodes `"DREGG/CONTENT/MUTATE".toUTF8.toList` on every command encode/decode call (no-arg `def`); ~20 bytes, tiny.
- [096] Kernel/FieldClosure.lean:312 `declare`/`setAll` — foldl of DFinsupp `set`s (closure layer per entry) at grain/room birth only.
- [096] Kernel/DomainEpoch.lean:301 `AbsentOpening.decode` computes `bytes.take (E*n)` twice (once for the `all` check, once for the `map`) — relay/witness-side, tiny.
- [096] Kernel/DomainEpoch.lean:913 `Equivocation.check` re-derives `signingBytes` per record — evidence-object check, rare.
- [097] Kernel/FnEvidence.lean:53-59 `exportPackage`: `held ++ window` accumulator inside `foldRange` steps re-copies the whole gathered prefix per window — O(records²/window) List copies (NativeHistorySelec…
- [097] Kernel/FnArchiveJournal.lean:198-271: `State.slots : List Slot` used as a map — `lookup`/`State.update`/`slots ++ [slot]` are 2-3 O(n) passes with String equality per journal event, making `load` rep…
- [097] Kernel/FnConsumerOperation.lean:374-382 `originOperation`: `Nat.toDigits 16` → `String.ofList` → `toUTF8.toList` hex round trip per origin derivation; a fixed-width byte encoding of the digest would …
- [097] Kernel/FnConsumerOperation.lean:746-754 `decide`: `sameBytes binding.package report.package` computed in the equality chain and again inside `sameSource` — duplicate full-package `toByteArray` conver…
- [097] Kernel/FnConsumerOperation.lean:140-141 `sameBytes`: converts BOTH sides to ByteArray per comparison (2 O(n) allocs); comparing via length-first + `List.isPrefixOf`-style loop or carrying ByteArray e…
- [098] Kernel/FnPortableSource.lean:58–66 (`extract`): `(body.splitOn "\r\n").reverse` then `rest.reverse`, then `(lines.reverse.drop 1)` a third time, plus `String.intercalate` + `.toUTF8.toList` — E1 auth…
- [098] Kernel/FnReplyPublication.lean:223–238 (`Selection.source`): `value.messageId` (full `identityPreimage` encode + SHAKE + hex) evaluated twice (lines 225, 231) and `replyCodec.encode value.reply` twic…
- [098] Kernel/FnReplySource.lean:28–40 (`Extracted.render`) rebuilds the whole article string for the canonicity compare — necessary as a check, but it runs 3× per `check` (covered in main finding 4).
- [098] Kernel/GeneralSimplexReachability.lean:129–165 (`Network`, `advance`, `initial`): `localState : Nat → State` is a function-as-map built by closure chaining; `initial`'s closure re-runs `start` (a ful…
- [098] Kernel/FnSelectiveReleaseArticle.lean:99–107 (`extract`): `.reverse` computed twice on the base64 line list; bounded 1.5 MB source, receiver-side per article (could matter at volume; listed here beca…
- [100] Kernel/JointControlBootstrap.lean:41-50 (`phase`): decodes the full `LifecycleImage` *and then* `JointControlFrame.readControl` decodes the cell again; `birthCheck`/`ownerBirthCheck` (:60-67, Bundle …
- [100] Kernel/JointControlBootstrapBundle.lean:81-88 (`birthIntent`): computes `sourceBytes source` (frame ++ encode) three times (twice in the `StableEvent`, once per `turnBytes` charge query via `overhead…
- [100] Kernel/JointControlBootstrapBundle.lean:58-61 (`decodeSource`): decode-then-re-encode full round-trip compare against the input — canonical check by re-serialization; bootstrap-only.
- [100] Kernel/Inbox.lean:134-138 (`extract`) / :161-162 (`Inbox.withdraw`): linear scan with prefix rebuild — fine at `bound` = 16, listed only for completeness.
- [101] Kernel/JointControlBootstrap.lean:84-85 — bootstrap re-encodes `controlStream.encode` twice to compare with `emptyControl`; genesis only.
- [101] Kernel/LinkIndex.lean:828-831 (`latestLinks`) — folds the whole log per cell; used in statements/reads of backlink proofs, not on the per-turn write path.
- [101] Kernel/JointDecisionRecovery.lean:164-174 (`retainRecovery`), :178-182 (`recordApplied`) — O(participants) scans and `List (List UInt8)` prefix checks per consensus step; small n, consensus path only.
- [102] Kernel/NativeHistorySelection.lean:192 (`foldRange`): `for _ in List.range (…)` allocates a Nat list just to count windows — use a while/cursor loop.
- [102] Kernel/NativePlanHeight.lean:126 (`pin`) and :220 (`pinEnrollment`): decode + full re-encode of every slot header / sponsor header per pin — authoring-time only, acceptable, but a header-level splice…
- [102] Kernel/NativeObservationController.lean:1049 (`sinceFrom`): walks the whole accepted log from `genesisHeight+1` per `.since` query — inherent to K-INDEX's `since` semantics, noted only because `after…
- [103] Kernel/ObjectAudienceController.lean:51,66–67 (`check`, `checkBound`): runtime `decide (Valid …)`/`decide (Bound …)` over derived DecidableEq comparing whole `State` structures (incl. list-valued fie…
- [103] Kernel/ObjectRecord.lean:351–356 (`UpgradePolicy.permits`, `strengthen`): O(floors²) `contains` and `==` on whole `Pred` structures — ADOPT/upgrade turns only.
- [103] Kernel/ObjectRecord.lean:810–811 (`lawFieldIssue`): flatMap + `find?` re-scanning — creation/ADOPT only.
- [103] Kernel/NockEntry.lean:140–146 (`decodeParams`): per run (Run.lean:251) it cues the arm and re-jams it for the canonicality compare; the arm atom is tiny so this is cheap, but the compare could be a b…
- [103] Kernel/NockProgramCell.lean:36–46 (`checkProgram`, op 131): `codeDigest program.jam` re-hashes the full program jam per check, and `loadProgram` runs again inside the verdict — client read op, not pe…
- [104] `frontEndQuote` (1272–1276): decodes the whole stored pair to quote two numbers — one-shot per publish/quote, fine as-is.
- [104] `recordFrame`/`storedFrame`/`retiredImage` nullary defs rebuild their bytes per use — trivial sizes, listed only for completeness (folded into finding 1's fix).
- [106] Kernel/ObjectiveActivityUpgrade.lean:203 (`forgotten`): `reads.contains field` per old field over the `parameterReads` list — O(fields×reads) with fuel 100000; ADOPT-time only.
- [106] Kernel/ObjectiveActivityUpgrade.lean:103 (`floorEntailed`) via `firstUnentailed`: runs the DNF `difference?`+`decide` per floor per ADOPT; could early-share the translated problem across floors.
- [106] Kernel/ObjectiveActivityUpgrade.lean:724/730 (`abortDrained`): `responseData .upgraded view` computed twice in one body (type response and resume); cheap but free to `let`.
- [106] Kernel/ObjectiveAdmissible.lean:149 (`Proposal.check`): re-executes the whole intent (`execute .complete`) for the `Installs` check, which a writer would then execute again — but I found no runtime c…
- [106] Kernel/ObjectiveBendNativeInput.lean:144 (`parseArguments`)/:116 (`exactKeys`): key-set check is O(keys²) via `actual.all keys.contains` per JSON node; argument-parsing-time only, tiny.
- [108] Kernel/ObjectiveDomain.lean:692,772,785 — `register` recomputes `RegisterRequest.id` (`domainId`, a tagged hash over the encoded members+law) 3× per registration (readDomain, judgeJoint, transaction …
- [108] Kernel/ObjectiveDomain.lean:97–108 — `memberSlots` builds `"member/" ++ toString index ++ "/" ++ slot` per slot per member per domain judgment (String concat + Nat→String on the per-turn judgment pat…
- [108] Kernel/ObjectiveDomain.lean:292,295 — `eraseDups` is O(n²) list dedup with Digest byte-equality; n is cap-bounded (≤8 domains/object) so it's noise next to the canonicalBytes multiplier.
- [109] `payLedgerLoaded` (NativeHost.lean:2454): `List.range (nextFree store)` + `assignmentAt` per index, plus `nextFree`'s support scan — operator CLI one-shot; same fix as `bookRows`.
- [109] `PayCellLegacyV4.frozenGenesisDefault` (PayCellLegacyV4.lean:183–187): literals `10000000000`, `5952380`, `1000000` (≥ 2^32 → decimal-string parse per call) but only reachable via the frozen v4 genes…
- [109] `PayClaimCommand.Action.valid` / `PayChainTip.valid` decide `2 ^ 64` / `2 ^ 256` bounds at runtime per ingress decode — GMP `Nat.pow`, cheap; listed only for completeness.
- [109] `PayCellUpgrade.lift` is clean (uses the executable `entries` enumeration, not `Finset.toList`); migration-only, no finding.
- [110] Kernel/PayEnrolClaim.lean:519 `Consumption.acceptanceIdentity` — full codec encode, but zero runtime callers repo-wide (only its own def); dead code, candidate for deletion rather than optimization.
- [110] Kernel/PayEnrolDecision.lean:437–535 — the big decimal literals (`10000000000`, `999999840`, `50000000`, …) all live in fixture defs consumed only by `decide +kernel` proof poles; elaboration-time on…
- [111] Kernel/PayEnrolQuote.lean `quote` — public quote verb; plain arithmetic, no waste found.
- [111] Kernel/PayStarterAllowance.lean `recommendation` — one-shot arithmetic, fine.
- [111] Kernel/PayTariff.lean `genesisDefault`/`exampleTariff`/fixtures — closed constants feeding `decide +kernel` proofs; elaboration-time only, no runtime cost.
- [111] Kernel/PayObservationProofs.lean — entirely theorems and kernel-decided poles; nothing runs in the host.
- [111] Kernel/PhysicalResourceReadGuard.lean `current` — a theorem; no executable body.
- [112] Kernel/PlatformCell.lean:143 (`History.push`) / :141 (`History.current`): `installs ++ [p]` and `getLast` are O(n) per install — fine at install frequency (controller-signed, rare).
- [112] Kernel/ProviderRoute.lean:555–596 (`fixture_*` `by decide`): elaboration-time only, no runtime cost.
- [114] Kernel/ResourceBirthPolicyController.lean:2201-2205 `DecodedIngress.bytes` re-encodes the whole ingress (`ingressCodec.encode`) per call — replay-compare path only, fine to leave.
- [115] Kernel/ResourceTransaction.lean:99–110 — `Repr Payload` re-encodes a content command through `commandStream.encode` on every repr; diagnostics only.
- [116] `checkProgram` (Kernel/NockProgramCell.lean:36–46, host op 131): hashes the program jam via `codeDigest program.jam` and `programId program`, and calls `CanonicalCellRegistry.loadProgram` again at li…
- [116] Kernel/Run.lean's pole theorems and Seat.lean's `Example` namespace are `decide +kernel` proof fixtures — elaboration-time only, no runtime cost; nothing to fix there.
- [118] Theory/PolicyInstall.lean:69 `checkSuccessor` — `decide` on structure equality per install; fine, installs are rare.
- [118] Theory/ObjectiveBendCheckpoint.lean:296 `roundTrips` — encodes, decodes, re-encodes (3 full traversals); preview-only (Host/ObjectiveBendPreview.lean:80).
- [118] Kernel/DomainEpochExport.lean:442 `be 8 …` — export encoding, rare.
- [119] native/resource-client/src/activity.rs:150–153 (`turn_nonce`) — `while name(n + 1).exists() { n += 1 }` re-stats the operations dir linearly per submit; number of records grows forever.
- [119] native/resource-client/src/agent_lifetime_grant.rs:88–122 + 124–135 (`pin`, `same_pin`) — each grant verb re-hashes the full Lean host image (`host_image_sha256`) plus request/plan/config several tim…
- [119] native/resource-client/src/agent_lifetime_grant.rs:343–344 (`sealed`) — `bounded(...) != [vec![ASSEMBLE_OPERATION], call.clone()].concat()` clones the whole call (up to frame size) just to compare; c…
- [119] native/resource-client/src/activity.rs:296–341 (`submit`) — five-plus sequential Host round trips per submit (view/author/plan/inspect/assemble/submit); protocol-shaped, listed only for completeness.
- [119] native/resource-client/selected-release-drop-reply.rs — one-shot fault fixture; no findings.
- [120] **`same_paid_pin` re-runs the entire `paid_pin` verification, 5× per seal / 4× per submit** — paid.rs:137-154 (`same_paid_pin` → `paid_pin` at 96-135): each recheck re-parses `pin.json`/`seal.json`/`…
- [120] **`opened` fsyncs the directory on every decrypt — a read** — app_document.rs:215-217: `File::open(parent).sync_all()` inside `opened`; `status` calls `opened`, and `capture`/`publish`/`rebase` each …
- [120] **`store_key` re-acquires lock + re-reads key + fsyncs per call** — app_document.rs:135-159: `capture` triggers it ≥3× (line 496 pre-warm, inside `seal` at 171, inside each `opened` at 200). Fix: com…
- [120] **`capture` does 3 sequential singleton signed reads instead of one batch** — app_document.rs:506/514/516 call `signed_view` three times where workspace.rs:1188 `signed_views` / :1263 `signed_views_m…
- [120] **Host process spawn per codec step** — `source`/`source_inspect` (agent_reserve.rs:46-81) spawn the full Lean host per call; `lifetime_paid_plan` = 3 spawns, `lifetime_paid_seal` = 3, `agent_payer::…
- [120] **`payer_anchor` reads + serde-parses every retained outcome file** — agent_reserve.rs:399-426: up to 10,001 × 64 KB `*.outcome.json` full parses per payer-sign. Deliberate "all confirmations agree" …
- [120] **`same_pin` full re-read per recheck** — agent_reserve.rs:199-211 / lifetime_v3.rs:79-91: `pin()` re-parses `pin.json`, re-reads + re-digests `request.bin`/`plan.bin`, and re-reads `plan.frame` (≤12…
- [120] **`approve_slot` re-reads and re-derives the same key per slot** — agent_reserve.rs:318-326, called in loops of up to 16 (`seal`, `encode_signatures`): `read_secret_in_private_dir` + ed25519 key expa…
- [120] **1-byte-prefix compare via full-buffer clone** — agent_payer.rs:41-46 (`exact_current_plan`), agent_reserve.rs:185/567, lifetime_v3.rs:65/296, paid.rs:122/549: `[vec![op], plan.clone()].concat()` al…
- [121] apps.rs:645–660 (`catalogue` search): `verdict()` does two 16 KiB file reads + serde parses per matched entry — 196 file reads for an unfiltered `--json` listing of 98 apps; batch-load the verdicts/m…
- [121] apps.rs:317–331 (`search_unordered`): allocates a lowercased copy of each of 6 fields per entry per search; apps.rs:311–315 (`search`) calls linear-scan `featured()` (27 entries) O(n log n) times ins…
- [121] app_lifecycle.rs:457–458 + 269–297 (`run`/`selectors`/`workflow_result`): on completion `selectors()` reads three `prepared.json` files and is computed twice (once for the `management-selector.json` …
- [121] app_lifecycle.rs:241 (`retain_discovery`): `declaration()` built twice per call (both sides of the comparison) — needed for the check, but it re-validates every field twice.
- [121] append_proof.rs:158–367 (`prove`): ~6 sequential `minidregg-host` spawns and a full re-read/re-hash of every evidence file at the end; the re-read is deliberate tamper checking, but the host invocati…
- [121] apps.rs:485–493 (`report`): clones the whole reply `Value` just to insert a `budget` key — trivial.
- [122] attempt_state.rs:64–81 (`run`): `--file NAME` still repairs and reads `outcome.json` + every retry answer to build the full state, then picks one — could read just the named answer after `repair_dir`.
- [122] bend.rs:505–512 (`finish_run`) and 536–561 (`show`): two extra full `activity::view` Host round trips per run/show; a combined view request would halve the round trips.
- [122] bend.rs:278–294 (`Bend::latest`): scans and parses every `.meta.json` under attempts to find the newest; monotonic attempt naming would make it a stat.
- [122] can.rs:157–175 (`delegated_recipients`): re-reads every `proposals/*/proposal.json` per probed resource — O(refs × proposals) file reads for bare `can --all`.
- [122] can.rs:345–361 (write probing): up to 8 fields × 2 directions = 16 full propose+dry-run+cleanup Host round trips per scalar resource, each with a proposal dir create/`remove_dir_all` (can.rs:96–125).
- [122] apps_worker.rs:234–252 (`Worker::list`): re-reads and parses every grain file per `list` verb; fine at small N, the edge-finding cache would cover it.
- [123] client_consent.rs:55–67 (`with_consent`): re-reads the settings file from disk and re-runs `Selection::from_env()` on every consent frame (per signed turn); cacheable per process. Microseconds agains…
- [123] chat.rs:700–703 (`propose_submit_in`): parses all concatenated JSON docs from the submit output keeping only the last; and leaves each `HOME/requests/{id}.json` in place after submit (unbounded small…
- [123] chat.rs:1306–1315 (`clip`): allocates the full flattened String and counts chars before truncating to `max`; per rendered entry.
- [123] clock.rs:368–382 (catch-up loop): one full tick (≈5 host ops + journal fsync) per bounded step during catch-up — protocol-bounded by maxStepSeconds, only noted for completeness.
- [123] clock.rs:152–179 (`journal`): fsync per tick line plus parent-dir sync on rotation — correct cadence for a timer verb, nothing to change.
- [123] checkpoint.rs:105–147 (`certify`): ~5 host invocations per certify, one `current.clone()` of the view JSON for the not-due path — one-shot operator verb, fine as-is.
- [124] consent_proxy.rs:469-481 (`serve_connection`): worker-lock acquisition busy-polls `try_lock` with 10 ms sleeps up to 30 s — fine at consent volumes.
- [124] consent_proxy.rs:529-541 (`serve`): non-blocking accept loop polls at 20 ms while any connection is open — negligible, but a `poll`-on-listener would idle for free.
- [124] cohort_tcp.rs:284-343 (`send`): pre-seals the whole link inventory (up to 64 MiB) into memory at start — bounded and documented, listed only for completeness.
- [124] cohort_tcp.rs:853-862 (`number`) and 1314-1344 (`run`): stringly argv parsing at startup only — irrelevant.
- [125] credit.rs:282 `my_account` — parses every ref file in the workspace (JSON + validation) per CLI run to find "the one account"; pay/topup/balance each pay it once.
- [125] credit.rs:591 + 773/801/883/949/963 — each `credit` verb re-derives `room(&root,&ws,&name)` at least once even when the action needs only one field; harmless per turn (one fleet turn dwarfs it) but t…
- [125] current_birth.rs:165 `author` — `retained_bytes.clone()` (up to 4 MB) although `session_invoke` (main.rs:714) takes `payload: &[u8]`; one wasted copy per birth.
- [125] current_birth.rs:107 + main.rs:724 `author`/`session_invoke` — `host_image_sha256` computed twice per birth (cached by (path, identity) at main.rs:627, so second call is a metadata check only — fine,…
- [125] enrollment_bootstrap.rs:292 `paid_body` — `[vec![op], body.to_vec()].concat()` makes two extra copies of a ≤4 KB body per paid request to prefix one byte; one `Vec::with_capacity` + push/extend would…
- [125] enrollment_bootstrap.rs:536 `RateLimit::allow` — `retain` walks the whole client table (≤1024) on every request and a full table adds an O(n) eviction scan; µs-level, deliberate bookkeeping, noted on…
- [126] fleet.rs:968/997 — `pay_turn_recorded` parses the pinned config twice (`tariff` for the asset, then again for the base); pass one parse down.
- [126] fresh_onboarding.rs:41-51 (`verifier_pin`) and 95-147 (`prepare`) hash the full 159 MB verifier image per call — join/onboarding only, but each call pays the finding-1 cost once; memoize the same way.
- [126] fleet.rs:783-799 (`resubmit`) and 265-282 (`lookup_exact`) count matching files with a full `read_dir` + string filter per call — trivial, but a numbered-next-file convention would avoid the scan.
- [126] fleet_sign.rs:546-552 (`write_private`) fsyncs the staging file but never the parent directory after rename — a durability gap rather than a perf cost, noted in passing.
- [126] fleet_sign.rs:267-274 (`current_balance`) does a full signed observation just to render a balance for an already-joined profile at `join` time — one-shot verb, fine as is.
- [127] grain_share_issue.rs:571+592 (`lookup`): `historical_anchor` runs twice per lookup and each call reinspects *every* prior stem (`submit`, `lookup-0000`…), each a fresh host process spawn via `inspect…
- [127] grain_share_issue.rs:522-551/553-595 (`submit`/`lookup`): `verify_retained` ×4 per verb, each a full `retained()` = 6 bounded file reads + 6 SHA-256 digests.
- [127] grain_share_issue.rs:317/405 (`plan`/`prepare` `check_inputs` closure): re-reads config + request/approval files before and after every host operation (~8–10 re-reads per prepare); host image hash it…
- [127] historical_call_receipt.rs:94-136 (`lookup_verified`): config read 3×, call read 2×, and `inspect_direct` spawns the host process per inspection — deliberate custody exactness, but 3 of the 4 reads a…
- [127] hermes.rs:581-594 (`summon`): `credit::room` read 2–3× within one summon (before till birth, after, before fields) — one-shot verb.
- [128] inspect_views.rs:117-124 (`caps`) — one sequential signed-view host round trip *per capability id* (up to 3) per reference; could batch into one input to the cap-tree view.
- [128] inspect_views.rs:329-344 (`refusals`) — builds `held` by fully reading and cloning every found frame, then dedupes the extra dir with `held.contains(&bytes)`: O(n·m) full-frame byte compares plus ful…
- [128] join_solana.rs:516-539 (`host_reads_back`) and 955-967 (`wait`, `pay-enrol-ids`) — explicit `Command::new(&common.host)` process spawns; one-shot per join/renew so rare, but the same socket-INSPECT f…
- [128] job.rs:408-462 (`settlement_needs_recovery`) — re-reads (≤1 MB each) and JSON-parses every `submit-*.started.json` / `outcome-*.json`, and job.rs:870-890 re-runs it for *every* prior `<name>.settle-*…
- [128] join_solana.rs:398-405 (`percent_encode`) — allocates a heap `String` per byte (`(b as char).to_string()`) over a 400-byte memo; write into one `String::with_capacity`.
- [128] job.rs:270-301 (`write` via `client`, job.rs:153-171) — propose and submit each re-enter the whole shell verb (`crate::run`), re-reading workspace.json/refs per leg; Rust-side only, negligible next t…
- [129] `request` re-validates the bootstrap URL on every call (`validate_url(base)`, join_solana_v2.rs:176) although `run` already validated it once at :1008 — string scans per request.
- [129] `pinned_config` re-parses the pinned config JSON (`serde_json::from_slice(&common.config_bytes)`, join_solana_v2.rs:138) at every use site (`preparation_pins`, `source_context`, `metadata`) though th…
- [129] `rotate_key` builds `binding` by reading and hex-embedding the entire workspace config (`custody::bytes(&ws.config, transport::HOST_MAX_FRAME)`, key_rotation.rs:502) just to compare bindings for equa…
- [129] `resolve` writes a fresh `lookup-{random_nonce}.frame/.bin/.json` triple per uncertain lookup (key_adoption.rs:304–306) with no bound or compaction — unbounded file accumulation across retries of one…
- [129] key_adoption `run` re-reads all nine retained attempt files (`private_bytes` each up to 256 KiB, key_adoption.rs:521–535) on every post-submission invocation — could be done only when `seal`/`resolve…
- [129] `key_status` issues a second full status query for the NEXT key (key_rotation.rs:397) even when the workspace manifest's `nextPublicKey` equals the daily key's digest — one avoidable host round-trip …
- [130] **One full host process spawn per satisfiability question** — lawsat.rs:34-66 (`ask`), called from `check` (lawsat.rs:280-295, up to 4 spawns per `law check`: any, write, mine, relaw) and `can_any` (…
- [130] **Unbounded query-file accumulation** — lawsat.rs:53-59 (`ask`) permanently writes `{tag}-{nonce}.request.json` + `.answer.json` into `WS/lawsat/` on every question, never pruned; every `law check` (…
- [130] **Whole host image re-hashed per `mini key` invocation** — key_service.rs:198-203 (`exchange`) calls `crate::host_image_sha256` (main.rs:594, cached only per-process; the CLI is one-shot) plus `trans…
- [130] **Workspace pin JSON loaded twice per key command** — keys.rs:54 (`owner` → `workspace::load`) and keys.rs:209 (closure loads the same workspace again). Trivial (one small file); fix: load once and p…
- [130] **Extra full-frame copy per broker write** — key_service.rs:116-117 (`write` builds `frame = header.to_vec()` then `extend_from_slice(bytes)`); a `write_vectored` (header slice + body slice) would av…
- [130] **law_export.rs `next_revision` (law_export.rs:14-26) and `retained` digest check (law_export.rs:82)** — decimal-string bignum increment and one SHA-256 over `intent.json` per retained-proposal reuse…

# Route latency: state (lane/un-route-latency)

Red: a request through the grain route takes 6 to 15 s (TextEditor `POST /.sandstorm-login`
11 s alone, 18 s with a DDP websocket open; the app waits 10 s for the login rendezvous).

## Per-request Host call map (native/spk-host/src, tip b3c2b0578 + origin/main)

Dispatch is serial: `http_entrance.rs serve_dynamic_with_aux` runs one `deliver_request` at a
time (a reader thread parses; the dispatch loop dispatches). Per request,
`dispatch_delivery.rs deliver_once` -> `dispatch_native.rs author_and_submit`:

1. helper tool `author application-dispatch-request` (one-shot Host spawn, `tool_until`)
2. Host call `APPLICATION_DISPATCH_PLAN` via the operator socket (`invoke_until`, author_signed_ingress)
3. helper tool `inspect application-dispatch-plan`
4. helper tool `signatures`
5. Host call `APPLICATION_DISPATCH_ASSEMBLE` (invoke)
6. route-bound grains: helper tool `author application-route-bound-dispatch`
7. `submit_once`: Host call with the route-bound opcode (the chain write)
8. helper tool `inspect application-dispatch-committed`
Then `record_delivery_requested`, `prepare_cancellable`, the app call, `finish` (journal only).

## Timings (hbox, SandMD, e89fe7b8b + instrumented spk-host, one run, no other grain traffic)

Lines in the resident journal: `dispatch-timing`, `http-timing`, `author-timing`, `tool-timing`.
- queue 20 ms; preflight, fence, admit, allocate, record, project each < 25 ms
- helper tools 50 to 270 ms each (spawn is not the cost)
- app call 11 to 123 ms
- author_and_submit: GET 6.1 s and 11.6 s, POST 15.3 s, WebSocket open 13.0 s
- op1: author 424 ms (plan and assemble fast), submit 5.6 s; op2: author 5.2 s, submit 5.8 to 9.9 s;
  op3: author 5.5 to 5.8 s, submit 5.8 s. Each slow Host call is 5.2 to 6.0 s.
- Install of the 24 MB TextEditor package timed out twice (spk-ingest 132 s, 1.75 s CPU): load.

## Ruled out

Queue wait, journal fsyncs (allocate-operation 9 ms), helper spawn, the app, lock holders (a 0.3 s
`lslocks` sample during the slow calls showed none on the world's store), the SQLite 5 s busy timeout
as a visible lock wait.

## Not known / next

What the serving Host does in each 5 s call. Method (decided by the coordinator): on candidate
349e59ef1, SandMD world on hbox (`flock -o /tank/lanes/world-up.lock`), run the serving Host under
`strace -f -tt -T -e trace=%file,%desc,%process,fsync,fdatasync,futex,connect,sendmsg,recvmsg,poll,ppoll`
through a wrapper in the world's own bin, and split each call into exec/startup, Store open/read,
consent round trips, fsync, world-root derivation (long CPU with no syscalls), waits on another process.
Startup -> a resident Host for the dispatch path. Per-turn Store or world-root work -> a read-only
request through an enrolled route should not make 2 to 3 chain turns: a design change, written as one
paragraph for the coordinator and the statements auditor before any Lean.

## Wanted after the split

Head-of-line: a WebSocket open (13 s) blocks the next request because dispatch is serial.

## Hygiene notes

hbox umask is 0002: staged trees must be `chmod -R go-w` or world-up refuses ("companion custody
refused", "writable ancestor"); world-up needs a fresh run root; the world-up lock queue was 40 to 66 min.

## Result of the strace split (hbox, candidate 349e59ef1, SandMD, 2026-10-28 11:01, host load 8 to 13 on 24 cores)

Method as above: `sudo strace -f -tt -T` on the world's serving Host (a stdio server; the
operator process hands it frames), trace set %file,%desc,%process,fsync,fdatasync,futex,connect,
sendmsg,recvmsg,poll,ppoll; frames delimited by `read(0, ...)` and the next `write(1, ...)`.

One request's submit frame (`DREGG/RESOURCE/SIGNED-INGRESS`, 11:01:23.880, 5.75 s). Its 355 syscalls
total 0.27 s of syscall time (a 0.269 s wait on the Store `serve` child reply, nothing on fsync, futex,
connect or another process). The rest is six stretches with no syscall at all, in the Host's one
thread: 0.45 s (after the request is read and its public key written/removed), 0.22 s, 1.48 s (after
the first durable read's `request.bin` is handed out, before `record.bin` is written), 0.27 s, 1.53 s
(after the second durable read's `read.bin`, before `checkpoint.key` is read), 1.35 s (before the
`DISPATCH-COMMITTED-PERMIT` reply is written). About 5.3 s of single-thread computation inside the
Lean Host. The other submit frame (11:01:00.358) was 5.38 s the same way; the plan frame
(`DISPATCH-AUTHOR-REQUEST`) was 0.03 s on later requests and 1.1 s on the first.

Not startup (the Host is resident; no exec, no olean load in the window), not Store open/read (0.27 s),
not consent (none in the window), not fsync (none), not a wait on another process (none).

### Design finding (one paragraph, for the coordinator and the statements auditor; no Lean touched)

Every request through an already-enrolled route, GET included, is a full signed chain turn: the Host
verifies the signed call, reads the durable state twice, re-derives and checks it, and builds the
committed permit, about 5.3 s of single-thread CPU per request, serialised behind one dispatch loop. That
is why a bare GET costs 6 to 12 s and a Meteor login POST (11 s alone, 18 s with a websocket open) can
never meet the app's 10 s rendezvous wait. Performance is published, never a gate, so the number is
not the red; the red is that a read-only request needs a chain turn at all, and that the turns queue.
The fix is a design change (no new chain turn for a request the enrolment already authorises, or a turn
whose state check is incremental instead of re-derived), which needs a statement first.

## Head-of-line: no fix to build (ruled with the coordinator, 2026-10-28)

Each spk-host resident serves exactly ONE grain (`resident_service.rs` `serve_dynamic_with_aux`: one app,
`&mut resident.rpc`, `entrances` = that grain's participant routes). Different grains are already separate
processes and run in parallel. Within a grain every request names the grain's chain tip (plan, assemble and
submit are a compare-and-swap on it) and shares one exclusive app rpc handle, so concurrent same-grain
submits would refuse each other. A websocket open does not hold the loop while streaming: `deliver_once`
hands the upgraded stream to `open_web_socket` and returns `Vec::new()` right after admission. The 13 s
websocket open is the admission itself (three serial Host calls). Do not re-propose parallel dispatch.

## perf profile (hbox, candidate 349e59ef1, SandMD qualify, 2026-10-28)

World: `world-up` on the candidate bin, SandMD `featured-qualify.sh` (b1 table, letter j) PASS 2 of 2
(create, install, share, start, enrol, page 265 s; POST /new 303 then download 200). Host CPU over the whole
run: utime 114.2 s, stime 0.83 s (57,248 samples at 499 Hz = 114.7 s). The Host is CPU-bound, not waiting on
the run queue (load 12 on 24 cores, and the 5 s calls are 5 s of utime).

Method notes: the Host is exec'd from a memfd (`/proc/<pid>/fd/7`), so `perf record --call-graph dwarf`
attached late had no mmap event and no unwindable stacks (depth 1 for 93% of samples) and printed raw
addresses. Self time was resolved by hand: address minus the memfd base (from `/proc/<pid>/maps`), against
`nm` of the same binary. Inclusive time and stacks come from 10 `gdb -batch -ex "thread apply all bt"`
snapshots of the serving Host taken mid-request (a GET through the route, 6.3 to 17 s each under gdb stops).

### Top 15 by self time (percent of Host CPU samples)

 19.2 `List.reverseAux` | 9.0 `lean_dec_ref_cold` | 7.4 `lean_apply_1` | 6.9 [libc/other] | 4.2 `List.lengthTR`
 3.8 `__gmpz_set_str` (+2.0 `__gmpn_bc_set_str`: `lean_cstr_to_nat`) | 3.8 `lean_apply_2` | 3.7 `keccak` (Rust)
 3.5 `mi_malloc_small` | 3.0 mathlib `List.Lex.decidableRel` | 2.5 `mi_free`
 2.3 `List.foldl` in `Sp800185Cshake256.Fast.pushList` | 2.1 `List.find?` | 1.4 `lean_byte_array_push`
 1.2 `Pred.State.get` lambda. Then `DTreeMap.Impl.getD` in `FiniteDependentMapCodec.fromEntriesFast` 0.8,
 `NatDigits255Fast.smallDigits` 0.7, `Tower256ConcreteBackend.StreamCodec.decodeNatPrefix` 0.6.
Every stretch of 3 s or more (11 of them, 3.4 to 11.1 s) has the same profile: reverseAux 14 to 27%,
dec_ref_cold 8 to 11%, apply_1, lengthTR. It is one mechanism repeated, not a spike.

### Inclusive: what the 10 stacks show (8 compute, 2 idle waiting on the Store coprocess/stdin)

- 5 of 8 are in whole-Store codec and root work: `StoreCodec.rootBytes` -> `saltedRoot` -> `leaves` ->
  `opening` -> `entryStream` -> Tower256 `encodeNat` -> `NatDigits255Fast.digitsBytes` -> `lean_cstr_to_nat`
  (sample 1, reached from `CredentialSignatureAdmission.keyRegistry/prepare` <- `DeclaredResourceController.admit`
  <- `ApplicationDispatchAdmission.checkCurrentFromSourceBytes` <- `NativeHostReplay.admitDispatchAt`);
  `StoreCodec.encode` of a lifecycle image (sample 3: `ResourceBirthCodec.LifecycleImage.bytes` <-
  `CredentialAuthorityDomainReceiver.Loaded.write` <- `GrainResourceBirthAdmission.policySourceGuards`);
  `saltedRoot` via `PolicyComponentResolution.loadRoots` <- `PhysicalLawResolution.readGuards` (sample 6);
  `StoreCodec.payloadStream` decode = `FiniteDependentMapCachedOrdering.fromEntriesCached` building a
  `DTreeMap` with mathlib `List.Lex` key compares (samples 7 and 9).
- 2 of 8 are `CanonicalRuntimeProfile.receiverSemanticsFrom` (Compiler/CanonicalRuntimeProfileCore.lean:118:
  a cSHAKE over a `StreamCodec.product` encode of the whole compiled component list plus template) reached
  from `DeclaredResourceController.targetWrite` <- `ordinaryWrites` (samples 5 and 8).
- 1 of 8 is `PolicyRecordCodec.encodeToken` (sample 10).
- All 8 sit under `Host.dispatchApplicationSubmitSession` -> `ApplicationDispatchReceiver.receiveVerifiedWith`
  -> `NativeHostReplay.exactCandidate` / `admitDispatchAt` -> `DurableReceiverIO.Loaded.extend` ->
  `DurableEngine.Engine.install` -> `ApplicationDispatchPending.candidateIntent/charge`.

Definitions: Compiler/StoreCodec.lean:788 `leaves`, :784 `opening`, :799 `saltedRoot`, :812 `rootBytes`
(decode payload then `saltedRoot`), :513 `payloadStream`, :326 `sortedSupport`, :297 `addressKey`;
Compiler/FiniteDependentMapCodec.lean:64 `fromEntriesFast`, :118 `entryStream`; Compiler/NatDigits255Fast.lean:134
`digitsBytes`; Compiler/Tower256ConcreteBackend.lean:802 `encodeNat`, :939 `encodeMany`;
Theory/Sp800185Cshake256Fast.lean:735 `pushList`; Compiler/ResourceBirthCodec.lean:336 `LifecycleImage.bytes`,
:465 `rootBytes`; Compiler/CredentialAuthorityDomainReceiver.lean:66 `cellBytes`/`cellRoot`;
Compiler/CredentialSignatureAdmission.lean:210 `keyRegistry` (reads `snapshot.cell.root`);
Compiler/PolicyComponentResolution.lean:172 and PhysicalLawResolution.lean:62 `loadRoots`.

### Verdict

Yes, it is whole-image recomputation. Per turn the Host re-derives the full authority cell's salted root
(entries in canonical order, a salted leaf per entry, cSHAKE256 over the flattened leaves), re-encodes and
re-decodes the full Store image through list-of-byte streams (Nat digits via decimal-string `lean_cstr_to_nat`,
`List UInt8` appends and `List.reverseAux`, `ByteArray` pushes one byte at a time), and recomputes
`receiverSemanticsFrom` over the whole compiled manifest, in several call sites per turn
(`snapshot.cell.root` is a function of the cell, recomputed at each read, never held). Nothing is
incremental and nothing is memoised across the 2 to 3 turns of one request. Candidate cuts, each needing a
statement first (none is a quick fix): (a) hold `cell.root` (and `receiverSemanticsFrom`) once per snapshot;
(b) an incremental or cached `saltedRoot` keyed by the changed entries; (c) byte-array streams instead of
`List UInt8` in `StreamCodec` and `NatDigits255Fast` (no `lean_cstr_to_nat`). No Lean was touched.

Timed POST row: `scripts/spk-platform/market-writes/b1.sh write_SandMD` now times `POST /new`, prints it in
the row ("in Ns (published; budget 90s)") and fails only above `ROUTE_POST_BUDGET_S` (default 90 s, about 5x the
6 to 18 s seen on a busy hbox). Unrun (hbox world torn down; shell syntax checked).

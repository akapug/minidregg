# resource-client shard B: transport, relay, traffic privacy, proxies, drain

| Field | Value |
| --- | --- |
| Shard | resource-client B, "transport, relay, traffic privacy, proxies, drain" |
| Crate | `/Users/ember/dev/minidregg/native/resource-client` (binary `mini`, `src/main.rs`) |
| Date | 2026-10-26 |
| Reader | Opus, read-only (no build, no test run) |
| Files owned (lines) | `src/transport.rs` 3,975; `src/relay.rs` 1,500; `src/channel.rs` 898; `src/cohort_tcp.rs` 2,314; `src/pq_mailbox.rs` 2,074; `src/scheduled_transport.rs` 1,245; `src/proxy.rs` 300; `src/public_proxy.rs` 808; `src/serve_queue.rs` 246; `src/worker.rs` 908; `src/async_dispatch.rs` 480; `src/bounds.rs` 29; `src/fsio.rs` 211; `src/trace.rs` 57; `src/content_privacy.rs` 203; `src/hiding.rs` 648; `src/drain.rs` 2,136; `src/operator_drain.rs` 392 |
| Shard total | 18,424 lines (+ context files `native/hybrid_kem.rs` 471, `native/crypto_transit.rs` 380 = 19,275) |
| Of which `#[cfg(test)]` | about 5,965 lines (32%); about 12,459 lines of non-test code |
| Scratch | `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-B/` (`routes.py`, `routes.tsv`: the allowlist-vs-registry comparison) |

## Executive summary (15 lines)

1. `transport.rs` is the one client-to-Host wire. Every hop uses the same frame: a u32 little-endian length, then the bytes. The client-to-service envelope is `version(1|2) | u32 LE config length | config | [v2: 32-byte Host image SHA-256] | op | payload`. The Host reply is `op | payload`, where op is the request byte, 255 (Host refusal), or 34/164 for dispatch. The service adds 254 (transport refusal). Only Unix sockets are used, plus an ssh stdio pipe. No layer resends anything on its own.
2. The two central allowlists the scanner checks are `allowed_operation` (transport.rs:308-512, public) and `allowed_operator_operation` (transport.rs:526-618). Byte for byte they match `routes` in `protocol/host-operations.json`: 115 public ops, 69 operator-only, 2 stdio-only (24/25), and the reserved 191/192 refused. No operator op is reachable through `socket-proxy`, `serve-public-proxy`, `traffic`, `mix` or `mix-live`, and no public op is blocked.
3. Lean has no notion of which socket a request came in on (`dispatchSession` takes only op and payload; Host/Main.lean:2006-2011). So "operator-only" is decided entirely in Rust, by these allowlists plus filesystem permissions and SO_PEERCRED. Any Host op whose safety depends on being operator-only has no Lean gate behind it.
4. What the demo needs from this shard: `mini serve` (public mode, transport.rs:1186) runs one `minidregg-host CONFIG stdio` child behind a bounded fair queue. The deployed candidate starts it (deploy/candidate/run.sh:157). Behind that sit `mini socket-proxy` (proxy.rs, the ssh forced command in deploy/shell/mini-socket-proxy), the client `invoke*` functions, and on the read path `hiding.rs` (view verification) and `content_privacy.rs` (document action grammar).
5. `relay.rs`/`channel.rs` (the CH-RELAY constant-rate channel, which calls Lean through `dlopen`), `pq_mailbox.rs`/`cohort_tcp.rs` (the PQ mix cascade) and `scheduled_transport.rs`/`async_dispatch.rs` (the PSK fixed-cell facade) are three separate traffic-privacy stacks. They have three membership models and three crypto suites. None is on the demo path, no systemd unit starts any of them, and 8,891 lines (with crypto_transit) can go without touching the demo.
6. `relay.rs` is not the public ingress relay. That is `public_proxy.rs`. `relay.rs` is the channel-domain relay for traffic privacy.
7. The lost-reply story holds at the transport layer. The service answers 254 only for requests it never forwarded (transport.rs:1566-1578, 1770-1776). A Host failure mid-request closes the connection without a frame, which the client reports as "uncertain". The public relay never invents a 254 once it has written upstream (public_proxy.rs:361-374).
8. Retries happen only at the application level, by resending the exact retained `call.bin`. Lean decides sameness. The fn consumer worker (`drain.rs`) resubmits the same bytes only after Lean says "absent" (drain.rs:1430). It sends at most one exact ACK retry, fenced by a durable marker (drain.rs:947-953).
9. Two places can still produce a second effect. (a) The traffic facade persists a request before queueing it (scheduled_transport.rs:667-678). On queue-full it drops the caller, but the request file stays and is dispatched after the next restart (702-737), possibly long after the caller's 600 s window, while the caller may have authored a fresh call. (b) Any op Lean does not dedup by call identity, if re-delivered after a server journal is lost (Q8.5, Q8.16).
10. Real bug: `drain.rs:1303-1310` treats `state-*.tmp` as the leftover staging-file shape. `mini_sdk::durable` actually stages as `.state.json.durable-PID-N-NANOS` (native/mini-sdk/src/durable.rs:118). A crash during the first `save_state` therefore wedges the worker until someone cleans it up by hand.
11. Real availability flaw: in the split topology the public relay must run as the same uid as the operator socket (public_proxy.rs:358). Strangers' traffic and the operator's lifecycle calls then share one fair-queue peer, 32 queue slots and 64 connections. A public flood can starve operator lifecycle and drain clients.
12. Stranger-reachable resource bugs in the research stacks. `relay.rs` spawns an unbounded thread per TCP connection with per-read 5 s timeouts (relay.rs:867-886, 599). `relay-witness` allocates from a socket-supplied u32 (relay.rs:1361-1366). `cohort_tcp` runs an ML-KEM keygen for every unauthenticated TCP connection on a single-threaded accept loop (cohort_tcp.rs:731-735, 756-791). The traffic server serves one session at a time (scheduled_transport.rs:846-854).
13. Rust makes semantic or policy decisions with no Lean counterpart in several places. Per-op body bounds (op 7 at 4 MiB, op 9 at 16 KiB, and 20 or so more; transport.rs:39-49, 308-512). A "pure op" Host budget whose claim "reads no Store" is false for op 8 object-audience and op 0 (transport.rs:54-68 vs Host/Main.lean:2016, 2050). Drain's "recoverable refusal" check against the hex phase "fn-session" (drain.rs:1144-1147). Cohort slot admission from a roster JSON (cohort_tcp.rs:495-539, 740). The sealed-action policy in `content_privacy.rs`, which duplicates Host/Json.lean:899-960.
14. Twins: `public_proxy::connect` vs `transport::connect_unix_deadline`; `BoundedStream` vs `DeadlinePipe`/`DeadlinePipeWrite`; three `SocketGuard`s; hand-declared `poll`/`fcntl` FFI next to the `libc` crate; `hybrid_kem::random` vs `mini_sdk::random`; `native/resource-client/scripts/cohort-native-tcp.py` vs `cohort-native-tcp.py`; `mini_sdk::operator`'s frame codec vs `transport`'s. The doc claim that every key exchange is hybrid (hybrid_kem.rs:1-15) is false for `channel.rs:201-208` (raw X25519).
15. `crypto-transit-main.patch` is already applied (main.rs:90-92 carries exactly its three lines): it is dead residue. `channel-lib/` is a hand-run `build.sh` that links a Lean shared library for `mini relay`/`channel`; no gate or unit builds it. `check-traffic-crypto-alias.sh` names a test that no longer exists, and the per-lane check scripts write logs and artifacts into the source root.

---

## 1. What this code is and does

### 1.1 Module inventory

| File | Role | Reached from |
| --- | --- | --- |
| `transport.rs` | Shared framing; the client `invoke*` family; `mini serve` (public) and `mini serve-operator` (private) with the Host supervisor; the two route allowlists; Host image/config pinning and sealing | main.rs:3281-3293 (`serve`), 3307-3323 (`serve-operator`), 612 (`session_invoke`), 3137/3152 (`invoke` v1), many crate modules |
| `serve_queue.rs` | Bounded per-peer fair queue between connection threads and the single Host thread | transport.rs:14, 1690, 1719 |
| `proxy.rs` | `mini socket-proxy` (the box side of `ssh:DEST`) and the client-side `exchange` over `mini_sdk::operator::SshPool` | main.rs:3204-3208; transport.rs:1130 |
| `public_proxy.rs` | `mini serve-public-proxy`: a Unix-socket ingress relay from a public socket to the operator socket, filtering with `public_envelope` | main.rs:3324-3336 |
| `operator_drain.rs` | Owner-private `mini.control` socket for `serve-operator`: `operator-status` and `drain-operator` | transport.rs:1717; main.rs:3337-3348 |
| `drain.rs` | The fn B consumer and A reply consumer wake state machine (Polling → Preparing → Ready → Sending → Acking → completed, or Held), held-ACK recovery, consumer Host upgrade | main.rs:3512-3602; worker.rs:739, 758; main.rs:2448 (`HostUpgrade`) |
| `worker.rs` | The unattended fn consumer scheduler: authenticated NNTP GROUP wake hint over STARTTLS with a pinned certificate; the fn POST client used by publishers | main.rs:3603-3624; publisher.rs:295/391; selected_publisher.rs:403/472 |
| `scheduled_transport.rs` (+ `async_dispatch.rs` via `#[path]`) | `mini traffic`: PSK fixed-cell TCP facade (client Unix sockets `.sock/.control/.repair`, one server per peer), dispatch journal; `dispatch_once` and `AsyncDispatch` used by the mix | main.rs:3250; pq_mailbox.rs:319, 1489; cohort_tcp.rs:1047 |
| `pq_mailbox.rs` | `mini mix`: 4-layer hybrid-KEM batch cascade, registrar manifest, relays, mailbox receiver, broadcast reply scan; `live_*` helpers for `mix-live` | main.rs:3252; cohort_tcp.rs:881-1273 |
| `cohort_tcp.rs` | `mini mix-live`: roster-enrolled (MCE4) fixed TCP links and workers (cover, registrar, relay, mailbox, scan) | main.rs:3254; pq_mailbox.rs:1096 |
| `relay.rs` | `mini relay`, `relay-emit`, `relay-witness`, `relay-key`: one constant-rate channel domain's relay; Lean library loaded with `dlopen` | main.rs:3240-3246 |
| `channel.rs` | `mini channel key/join/say/tail/status`: channel member client | main.rs:3248 |
| `hiding.rs` | K-NARROW-HIDE client: blinding key and salt derivation, KMAC256, `verify_view` | main.rs:2237, 2245 (`verify_query_presentation`), 3736-3800 (`mini key --action export-blinding/cell-blinding/derive-salt`) |
| `content_privacy.rs` | Strict content-action grammar and sealed-action policy (a workspace submodule via `#[path]`) | workspace.rs:49-50, 2727; protected_document.rs:6, 102, 792; private.rs:789 |
| `fsio.rs` | String-error adapters over `mini_sdk` durable writes, secret loading and private directories | crate-wide |
| `bounds.rs` | Generated constants from `Kernel/Bounds.lean` | transport.rs:18, 23 |
| `trace.rs` | `MINI_TRACE` per-exchange JSON-lines trace | transport.rs:960, 1132 and others |

### 1.2 `transport.rs` in detail (THE client→Host wire)

**Frame layout, every hop.** `write_frame` (transport.rs:664-674) writes `u32 LE length || bytes` with `1 <= length <= MAX_FRAME`. `read_frame_bounded` (transport.rs:629-662) reads 4 length bytes. A clean EOF before any byte returns `Ok(None)`; a partial prefix is an `UnexpectedEof` error. A length outside `1..=min(MAX_FRAME, bound)` is `InvalidData`. The body is then read with `take(size).read_to_end`, which grows the buffer as bytes arrive, so a length prefix alone reserves no memory (transport.rs:651-654).

**Bounds** (transport.rs:17-25; bounds.rs:7, 9):

| Constant | Value | Meaning |
| --- | --- | --- |
| `HOST_MAX_FRAME` = `Kernel.Bounds.frameBytesMax` | 12,102,760 | Host frame including the op byte |
| `CARRIED_LOOKUP_MAX_FRAME` = `lookupFrameBytesMax` | 12,103,788 (= HOST_MAX_FRAME + 4 + 1024; asserted at :24) | op 153 only |
| `MAX_CONFIG` | 65,536 | config pin carried in every envelope |
| `MAX_FRAME` | 12,169,361 (= 12,103,788 + 5 + 65,536 + 32) | whole socket envelope |
| `MAX_CARRIED_CALL` | HOST_MAX_FRAME − 1 | raw call inside op 153 |

**Client→service envelope** (built in `invoke_inner`, transport.rs:1118-1126, and `invoke_pinned_deadline`, :936-942):

```
u32 LE frame length
  byte 0           envelope version: 1 (no Host pin) or 2 (Host image pin)
  bytes 1..5       u32 LE config length C (must equal the service's pinned config length)
  bytes 5..5+C     the exact config bytes (must equal the pin byte for byte)
  [v2] 32 bytes    SHA-256 of the --host executable the client selected
  1 byte           Host operation (request byte)
  rest             operation payload
```

On the service side, `split_envelope` (transport.rs:173-205) and `request_from_envelope` (:207-217) refuse the following: length < 5, a version other than 1|2, a config length or bytes that differ ("config pin mismatch"), a v2 pin that differs from the served image ("host image pin mismatch"), and an empty request. The request byte is the first byte after the pins. Version 1 is still accepted, and still sent by three call sites: main.rs:3137 (op 112), main.rs:3152 (op 8) and publisher.rs:154 (op 18). This contradicts native/resource-client/README.md:195-198 ("Every current `mini` socket request also hashes its selected `--host` executable and sends that image digest in the v2 envelope").

**Service→Host (stdio).** After the checks, the service strips the envelope prefix (transport.rs:1893-1898) and writes `u32 LE len || op || payload` to the Host's stdin (`HostProcess::exchange_within`, :1495-1514). The Lean reader agrees (Host/Main.lean:2667-2694, `serveSession`). It reads the 4-byte length with `frameLength` (little-endian fold, :2311-2312). Length 0 is answered with a 255 refusal `malformed "empty native host frame"`. Over `lookupFrameBytes` the frame is discarded and answered 255 `overBound`. Then it reads the op byte, applies the op-specific bound (`frameBound`: 153 → lookup bound, others → `frameBytes`, :2289-2291; theorems `frameBound_accepts`/`frameBound_refuses` :2295-2314), and calls `serveFrame`. Rust's `request_within_bound` (transport.rs:27-32) mirrors `frameBound` exactly: op 153 goes through `carried_lookup_request`, everything else must be `<= HOST_MAX_FRAME`.

**Host→service reply.** `writeSessionFrame` (Host/Main.lean:2318-2324) writes `u32 LE len || op || payload` and refuses `> maxFrame`. Rust reads it under the per-op deadline and refuses `> HOST_MAX_FRAME` (transport.rs:1504-1513). Reply op values:
- the request byte (ordinary success or the op's own outcome codec);
- 255: `RequestRefusal.frame` (Host/RequestRefusal.lean:74-75) for any exception (Host/Main.lean:2652-2663), or an explicit `(255, refusalFrame ...)` from a handler (e.g. :2022);
- 34 for request 164, and 164 (exact payload `DREGG/APPLICATION/DISPATCH-NO-RECORD-REFUSAL/v1`) for request 34 (Host/Main.lean:2326-2366). Rust accepts exactly these combinations in `response_operation_matches` (transport.rs:1089-1098), tested at :3330-3342.

**Service→client reply.** The Host frame is relayed verbatim (transport.rs:1931-1935). A refusal decided by the service is a frame `254 || UTF-8 reason` (`refusal_frame`, :1630-1634). Reasons: `invalid socket frame: …`, `config pin mismatch`, `host image pin mismatch`, `invalid socket envelope`, `host frame exceeds bound`, the per-op body refusals, `operation unavailable on selected socket`, `operator peer UID mismatch`, `operator peer credential unavailable`, `busy: connection limit`, `busy: host queue full`, `busy: queue residence deadline`, `busy: host queue share displaced`, `caller abandoned queued request`. 254 is never relayed from the Host. The Host never emits 254: `grep 254 Host/Main.lean` finds nothing. Q8.9 asks for a declaration. The registry reserves 254 and 255 as `request_reserved` (protocol/host-operations.json `response_markers`).

**Client checks on the reply** (`invoke_inner`, transport.rs:1133-1149). Reply > HOST_MAX_FRAME → "uncertain". `reply[0] == 254` → `Err("socket rejected request: …")`, a certain refusal. A tag that is not the op, 255, or the 34/164 pair → "uncertain host response: unexpected operation". Then `check_signing_plan_reply`: for plan operations it runs `client_consent::operator_plan` on the reply (:904-910). A 255 reply is returned as `Ok(reply)`, so callers must decode it.

**Socket kinds.**
- Unix stream sockets only: `UnixListener` (:1250), `UnixStream::connect` (:1155), and a hand-rolled nonblocking connect with a deadline (:980-1084).
- Remote is `ssh:DEST` (`Endpoint::Remote`, :117-145). It goes through `proxy::exchange` to `mini_sdk::operator::SshPool`, one `ssh -T DEST` session per (destination, credential) per process (proxy.rs:75-98), whose far side is `mini socket-proxy`. There is no TCP in transport.rs.

**Timeouts.**

| Where | Value | Line |
| --- | --- | --- |
| client connect (`exchange_unix`) | none (blocking `UnixStream::connect`) | transport.rs:1155 |
| client write | 10 s socket write timeout | :1158 |
| client 254 sniff after a failed write | 1 s | :1166-1173 |
| client reply read | 600 s absolute (`DeadlinePipe`) | :1176-1181 |
| `invoke_pinned_deadline` | one caller-supplied absolute deadline across connect, write and read | :914-978 |
| service: envelope read from accept | 10 s (`SERVE_BOUNDS.read_deadline`) | :1547 |
| service: reply write to client | 10 s write timeout | :1868 |
| service: connection-limit refusal write | 1 s, on the accept thread | :1841 |
| service: request write to Host | 30 s | :1499 |
| service: Host reply | 120 s for ops 0 and 6..=11 (`HOST_PURE_OP_BUDGET`), 600 s otherwise | :53-68, 1491 |
| service: queue residence | 60 s | :1550 |
| service: connections / queue | 64 / 32 | :1548-1549 |

**Retry policy.** Nothing in transport.rs resends a request. `invoke` documents that a failed write or read leaves the status unknown and that callers retain the signed call and use historical lookup before resubmitting (transport.rs:869-870). The Host child is restarted after an exchange error (`serve_host_observed`, :1783-1796). The in-flight job is dropped without a reply (`drop(job)`, :1792), and the client sees EOF, which is reported as "uncertain host response: connection closed" (:1181). When a resend does happen it is made by application code (`mini retry --attempt A --mode lookup|submit`, `retry_with_upgrade` main.rs:2444-2532, and the drain worker). Rust resends exactly the retained `call.bin` bytes (main.rs:2453-2457, 2520). **Lean decides whether a resend is the same operation**: submit (op 2) and lookup (op 3) receive the same signed call, and the Host's replay detection answers `confirmation: replayed` for the original transaction (see the `historical` arm writing `.confirmed .replayed`, Host/Main.lean:2350-2351, and drain.rs:1499 fixtures). Rust's only claim is byte identity. Q8.5 asks which Lean declaration keys the dedup.

**Service structure (`supervise_bounded`, transport.rs:1683-1702).** Three kinds of thread:
- One accept thread polls the listener every 100 ms (:1811-1858) and admits up to 64 live connections. The 65th gets `busy: connection limit`.
- One connection thread per connection (256 KiB stack, :1846-1852) does the following in order: sets a 10 s write timeout, checks the peer uid in operator mode only (:1872-1881), reads one envelope by its deadline, splits the pins, checks the bound and body bound, and checks the allowlist (public, or operator ∪ public in operator mode: :1905-1913). It then queues a `HostJob` under its peer uid and waits for the reply.
- The single Host thread (`serve_host_observed`, :1763-1800) takes jobs in fair order. Before writing a job to the Host it re-judges `unforwardable`: caller hung up (poll + MSG_PEEK EOF, :1583-1608) or residence exceeded (:1570-1578). Either way the job is answered 254, so a 254 only ever describes a request that was never forwarded (test `serve_refuses_254_only_before_forward`, :2793-2838).

`serve_with_mode` (:1224-1282) does the following:
1. Hashes the Host image and reads the config (≤64 KiB).
2. Requires the socket's parent to be owner-private (`check_private_dir`), takes `socket.lock`, and pins `socket.mode` (`public-v1` or `operator-v1`). A public pin cannot become operator (:737-749).
3. Clears a stale socket only after proving it is an owned socket with no listener and an unchanged inode (:751-774).
4. Pins `socket.config`, binds, records the inode for the `SocketGuard`, and chmods the socket 0600.
5. Starts the Host child.

**Host process pinning (`HostProcess`, `PinnedLocalInvocation`, transport.rs:1288-1522).** On Linux the Host image and config are copied into sealed memfds (`F_SEAL_WRITE|GROW|SHRINK|SEAL`, :1368-1393) and hashed after sealing (:1402-1428). The child is executed as `/proc/<pid>/fd/<n> /proc/<pid>/fd/<m> stdio` (:1432-1456), so a later change to the path cannot alter what runs. Elsewhere the code checks the path before and after hashing (inode, size, mtime, ctime; :1416-1424) and keeps the race window it documents (:1311-1318). Every restart re-checks against the original image hash and config bytes (`start_pinned`, :1348-1352). Host stdin is set nonblocking for the bounded write (:1473). Dropping the process kills and reaps it (:1517-1522).

**Route allowlists.** See section 2.2.

### 1.3 `serve_queue.rs`

A `Mutex<State>` holds a `BTreeMap<peer, VecDeque<T>>`, a round-robin `order` and a capacity (serve_queue.rs:29-66). `try_send` never blocks. When the queue is full, a peer holding fewer jobs than the heaviest peer by more than one displaces the heaviest peer's newest job, which is returned so the caller can answer it 254 (:73-111; transport.rs:1618-1627). The receiver iterates one job per peer in turn and ends only when the queue is empty and every sender is dropped (:140-162). The operator drain relies on that property (test :226-238). The peer key is the kernel peer uid; unknown means `u32::MAX` (:19; transport.rs:1918). The module docs say plainly that when all public clients share one uid (an ssh proxy account) the queue is FIFO (:10-14).

### 1.4 `proxy.rs`

The box side: `serve(socket)` requires an absolute non-`ssh:` path (proxy.rs:58-61) and reads the pinned config from `socket.with_extension("config")` (:62). `relay` (:30-54) loops reading frames from stdin with no read deadline (`transport::read_frame(input)`, :38). It checks each with `transport::public_envelope(frame, &config, catalog)` (:69). On refusal it writes `254 "proxy: " reason` and closes the session. Otherwise it forwards with `transport::exchange_unix(socket, frame)` (:70), a fresh Unix connection per frame, and writes the reply.

The client side is `exchange(destination, frame)`, which goes through `SESSIONS.channel(ssh).exchange(frame, 600 s)` (:85-98) and collapses `Failure::Unsent` and `Failure::Uncertain` into `String` (:95-97). The certain/uncertain distinction is lost in the error type, though the text keeps it. The ssh identity comes from `crate::ssh_identity()` (:87). The forced-command wrapper is deploy/shell/mini-socket-proxy (it runs `exec "$mini" socket-proxy --socket "$socket"` and refuses any `SSH_ORIGINAL_COMMAND` except `mini-provider-credentials-v1`, which goes to `mini-keys relay`).

### 1.5 `public_proxy.rs`

`serve(socket, upstream, config, group)` (public_proxy.rs:483-540) does the following:
1. Checks the public directory: owner-private, or with `--socket-gid` an owner/group directory with mode ⊆ 0750 and owner rwx (:237-260). The upstream directory must be owner-private (:262-268).
2. Refuses identical resolved paths (:486-495).
3. Requires the upstream `.mode` == `operator-v1` and `.config` == CONFIG, both owner-private, and the upstream socket owner-private (`check_upstream`, :269-291).
4. Probes the upstream and requires its peer uid == own euid (:500-505).
5. Takes `socket.lock`, pins its own mode `public-v1` and config, clears a stale socket and binds. The socket is 0600, or 0660 to the group (:518-525).
6. Installs SIGTERM/SIGINT handlers that set an atomic (:17-57).

`run` (:405-469) accepts nonblocking, up to 64 worker threads. A busy refusal is one nonblocking write of `254 busy: public ingress connection limit` (:438-446).

Each `connection` (:306-391) runs these steps:
1. Reads one envelope by `accepted + 10 s`.
2. Runs `public_envelope`.
3. Re-runs `check_upstream`.
4. Connects with a 10 s deadline and re-checks the upstream peer uid.
5. Writes the frame (10 s). Any failure after this point closes without a frame (:361-374).
6. Reads the reply (600 s) and writes it to the public client (10 s).

All waits poll a stop flag every ≤100 ms (`wait_fd`, :82-114).

### 1.6 `operator_drain.rs`

`Control::start` (operator_drain.rs:115-174) binds `socket.with_extension("control")` (0600), generates a random 32-byte `instance`, and records the config and Host SHA-256. One thread accepts nonblocking. For each connection it requires peer uid == euid, reads a ≤4096-byte frame with a 200 ms deadline, parses JSON and calls `State::answer` (:46-107), then replies with a 200 ms write deadline. `answer` requires exactly 7 fields (`format`, `action`, `instanceId`, `processId`, `configSha256`, `hostSha256`, `requestNonce`) and matching pins. `drain` additionally requires instance and pid to match, and sets `close`. `phase` is one of serving, closing, draining, drained.

The drain itself is in `transport::supervise_operator` (transport.rs:1707-1750). The accept loop sees `close` and returns. The listener is dropped, then `admission_closed` is set. The Host thread drains the queue, which ends only when every connection worker has dropped its sender. `drained` is then set only if `admission_closed` and `live == 0`. `hold_closed` keeps the Host owned and admission closed until the control thread ends (operator_drain.rs:177-190).

The client `command` (:265-315) polls status every 50 ms up to a 1..3600 s timeout and keeps the same instance. Despite the name it has nothing to do with `drain.rs`.

### 1.7 `drain.rs` (fn consumer wake) and `worker.rs`

**Data model.** The durable state lives in `STATE_DIR/pending/state.json` (written by `save_state`, drain.rs:105-111, as replace_private + ancestor sync), keyed by `phase`:

| Phase | Action | Exit |
| --- | --- | --- |
| `Polling` | `attempt(...,"poll")` increments `serial` and saves it before the effect (:131-140). `consumer_poll` (main.rs:2701-2772) sends op 12 or 14 with an empty payload through `session_invoke`, retains `reply.frame`, `decision.json` and `intent.bin`. `classify_poll_route` (drain.rs:724-798) | idle → delete `pending`, `Stop::Idle`; skip or publication → `Preparing`; unusable reply → `Held` |
| `Preparing` | `attempt(...,"prepare")`, then `submit(..., prepare_only = true)` (main.rs:1849-1865) authors and signs a call without sending it; syncs `call.bin` | → `Ready` |
| `Ready` | Saves `Sending` **before** sending (drain.rs:1376-1377), then `retry_outcome(path,"submit")`, which goes through main.rs `retry_with_upgrade` (Host op 2 path via `host_files`) | confirmed → anchor + `Acking`; refused → `Held`; other → `Err`, phase stays `Sending` |
| `Sending` | Exact lookup (`retry_outcome(...,"lookup")`). On confirmed, anchor and → `Acking`. On "absent" with no upgrade, resubmit the same call (`confirmed_after_retry(...,"submit")`, :1430-1436). With an upgrade, absent is held | `Acking` or `Held` |
| `Acking` | `consumer_ack` (main.rs:2847-2880) sends op 13 or 15 with the canonical decimal txn. `recover_acking_route` (drain.rs:912-981) inspects the retained reply: Exact → done; Covered or Refused → Held; Uncertain or TransportFault or none → one exact retry fenced by `ackRetryStarted` (:947-953) | archive to `completed/<txn>` (`finish`, :805-816) |
| `Held` | Refuse until an operator acts (`consumer-resume-ack` handles only the held-ACK case, :1073-1186) | — |

`pin.json` binds the Host path, config hex, socket, key path and public key. v2 adds the Host SHA-256 and the digests of the fnPoll manifests (`v2_pin`, :170-185). A changed pin refuses. `consumer-host-upgrade` (`upgrade_host`, :433-617) rebinds one retained Sending call to a new Host image. It requires the service lock, so the service must be stopped. It runs the new Host's direct CLI `inspect outcome` and `lookup` and requires that all four confirmed fields (acceptedCount, transactionId, eventId, worldRoot) equal the operator-supplied known outcome (:558-570). It then writes `migration.json` and replaces the pin (:579-614).

**worker.rs.** `run_route` (worker.rs:719-785) loads the wake config. That is an owner-private ≤16 KiB JSON file with port, cert path, password file, username, group, interval 1..3600 s and maxPages 1..16, and the GROUP must equal the hex `query` in the Host config's pinned fn scope (:187-288). The function then:
- takes `consumer-worker.lock` (in the socket directory) and `worker.lock`;
- pins the route and the wake;
- loops: sleep, GROUP hint, and run `drain::run_locked_route` up to 64 rounds while the hint changes or a publication or page cap occurred (`needs_another_round`, :677-679).

NNTP access (`protected_auth`, :359-444) works as follows:
- TCP to `127.0.0.1:port` with a 10 s connect;
- a `200`/`201` greeting, then `STARTTLS`/`382`;
- rustls with `ExactPinnedVerifier`: end entity == the pinned DER, no intermediates, SNI `localhost`, certificate within its validity period, SAN or CN `localhost` (:18-88);
- `AUTHINFO USER`/`PASS`.

Lines are read byte by byte, ≤4096 bytes, under a deadline (:307-329, 598-618). `post_exact_carrier` (:548-596) is the fn POST client used by `publisher.rs` and `selected_publisher.rs`. It dot-stuffs, and `classify_post_reply` maps exact reply texts to `Accepted`/`AlreadyStored`/`Conflict`/`ExplicitUncertain`/`Refused`/`TransportUncertain` (:501-516).

### 1.8 `scheduled_transport.rs` + `async_dispatch.rs` (`mini traffic`)

**Profile** (scheduled_transport.rs:38-85): cell 1 KiB..1 MiB, tick 10 ms..60 s, pending 1..256, retained ≥4×pending and ≤1e6, max_body ≤ `MAX_ENVELOPE` (= CARRIED_LOOKUP_MAX_FRAME + MAX_CONFIG + 38). `check` refuses profiles where two worst-size transfers in the reserved quarter class exceed 570 s (:60-70). The schedule is `[0,0,1,2]`: two application slots, one control, one repair (:36).

**Handshake** (:521-542): the server sends 32 random bytes and the client answers 32. `Codec` keys are `HMAC-SHA256(psk, profile-context || server || client || direction)` (:131-150).

**Cell**: `size − 16` bytes of plaintext: `"MTC1" | seq u64 | kind 1 | class 1 | id 16 | total u32 | offset u32 | len u32 | data | zero padding`, under XChaCha20-Poly1305 with nonce `0^16 || seq` and AAD = context (:156-196). `open` checks magic, seq, class and padding (:197-248).

**Fragment reassembly**: `Assembly` (:251-297).

**Server** (:557-606): one session per listener, run sequentially (:846-854). Each tick it reads one cell, assembles, offers to the backend (`backend_offer`, :407-439) and writes one cell half a tick later.

The backend journal (`Journal`, :313-393) files are immutable: `<ticket>.request`, `.class`, `.dispatch` (fsynced SHA-256 of the body **before** the effect) and `.reply`. `admit` returns `Fresh`, `Cached` or `Uncertain` (`.dispatch` exists without a `.reply`), and refuses a changed body. The worker thread does `claim`, then `public_envelope`, then `exchange_unix`, then `finish` (:440-488). Outcome bytes: `0 || Host frame`, `1 || "transport dispatch outcome uncertain…"`, `2 || pre-dispatch refusal` (:400-406).

**Client** (:738-792 and :857-933) binds three local Unix sockets 0600: `S`, `S.control`, `S.repair`. Each local connection is handled as follows:
1. Same-uid check.
2. Read one frame (10 s, ≤max_body).
3. Draw a random 16-byte ticket.
4. Persist `<ticket>.request` (class byte + body).
5. `try_send` into the class queue.
6. Wait for the reply; map 0 → raw Host frame, 2 → `254 || reason`, else close (:614-701).

After a restart, `recover_local` re-queues every `.request` that has no `.reply` (:702-737).

**`dispatch_once`** (:492-519) is the synchronous single-shot journal path used by `mix --action mailbox`.

**`AsyncDispatch`** (async_dispatch.rs:39-233) keeps custody durably for the mix receiver. `offer` checks `public_envelope` first, then reserves `.class` and persists `.recovery` (a 32-byte access capability) before `admit`. Three per-class workers (`run_next`, :253-311) scan the directory for `.request` files without `.dispatch`, claim them, exchange, and finish. `fetch` needs the original access capability, the body digest and the class, and never dispatches (:211-232). State `Accepted` maps to transport kind 3, "durable transport custody; fetch exact result later" (:20-27).

### 1.9 `pq_mailbox.rs` (`mini mix`)

**Layers**: 4 (3 relays + mailbox), each `crypto_transit::seal_raw_context`, i.e. hybrid X25519 + ML-KEM-768 + XChaCha with a commitment. Overhead per layer is 1,192 bytes (pq_mailbox.rs:19-23, 67-98; crypto_transit.rs:19-24).

**Core** (:209-243): `"MPC1" | epoch | class | real 1 | id 16 | reply cap 32 | len u32 | native envelope | zeros`.

**Batch** (:114-154): `"MPB2" | epoch u64 | hop | width u16 | payload u32 | packets`. Duplicate packet hashes are refused.

**Manifest** (:381-427): `"MPM2" | epoch | width | payload | 5 sorted hash sets | 4 HMAC tags`, one per operator key. The registrar checks each packet against the client's private 160-byte route commitment.

**Relay** (`process_relay`, :185-208): peel all packets, then `claim` (input hash pinned, `.claimed` fsynced, cached `.output`; :157-178), then a Fisher–Yates shuffle with rejection sampling (:99-113), then the next batch.

**Mailbox** (`process_mailbox`, :297-340): peel, `parse_core` all, claim, `dispatch_once` for each real core, then `reply` sealed under the client's reply cap (XChaCha, :244-269), shuffled, and the whole broadcast batch.

**Client `scan`** (`consume_broadcast`, :599-641): trial-open all W replies with each retained `.cap`. More than one hit is refused as a drain attack. `.spent` is persisted before `.opened`.

**`live_*`** (:645-1077): helpers used by `mix-live`, with grouped admission records (`live-epoch-E-stage-H.admitted`) and `AsyncDispatch` for the receiver.

**Release scheduling**: `release_at`/`wait_release` need an explicit `--origin-ms`. A missed epoch fails closed (:507-584).

### 1.10 `cohort_tcp.rs` (`mini mix-live`)

**Profile** (cohort_tcp.rs:31-102): generation 16 bytes, slot, phase 0..5, width 2..64, payload 1 KiB..256 KiB, tick 100..60,000 ms, processing slots 1..32, epochs 1..4096.

**Link record**: `"MCL1" | profile digest 32 | epoch u64 | nonce 24 | XChaCha(ready/unavailable marker, len, payload)`, with the key HMAC-derived per profile/epoch header (:194-257).

**Enrollment MCE4** (:396-792):
1. The receiver sends `"MCE4" | nonce32 | ephemeral hybrid public key`.
2. The sender answers with two hybrid encapsulations (to the roster's receiver link key and to the ephemeral key) plus a hybrid Ed25519+ML-DSA-65 signature over the transcript.
3. The link key is derived with HMAC from both KEKs and the signed transcript.
4. The receiver acknowledges with a 32-byte tag.

The roster is `minidregg-cohort-roster-v3` JSON (:495-539), and it is the only admission authority.

**Sender** (`send`, :284-395): pre-seals a fallback per epoch (≤64 MiB) and spawns a preparation thread. The clocked loop writes exactly one record per epoch at `when(epoch)`. A slot more than 25 ms late fails (`wait`, :112-127).

**Receiver** (`receive`, :793-852): reads one record per epoch and adopts it durably on a writer thread (`adopt` writes `epoch-E.record` and then an `epoch-E.adopted` token, :258-283).

**Workers** (`worker`, :998-1313): cover, registrar, relay, mailbox and scan poll record directories, check `enrolled-link` markers, and call `pq_mailbox::live_*`.

### 1.11 `relay.rs` and `channel.rs` (CH-RELAY channel domain)

**Lean via dlopen.** `Lean::load` `dlopen`s the library built by `channel-lib/build.sh`, calls `mdc_init` and resolves 17 symbols (relay.rs:65-144). The symbol-to-definition table is at relay.rs:10-24. ByteArray marshalling goes through `channel-lib/shim.c`.

**Wire** (relay.rs:26-45, big-endian):
- HELLO: `"DCH1" | slot 4 | subject 8 | ed25519 pk 32`, 48 bytes.
- CHALLENGE: nonce 32.
- AUTH: signature 64 over `"DREGG.CHANNEL.HELLO/v1" | domain | slot | subject | nonce`.
- WELCOME: `"DCH1" | status | class | domain | n | frame key`, 44 bytes.
- TICK: `0x01 | domain | epoch | tick | k | prevRoot | sig 64 | n·C vector`, 119 + n·C bytes.
- The member sends one C-byte cell per tick.
- Witness message: `"DCW1" | epoch | rlen | record | olen | opening`.

**Relay loop** (`run_relay`, :805-1165). Per tick k it does the following:
1. Fans out the previous vector to every slot (Lean `fanout`) while holding the slot mutex, with a 50 ms write timeout per member.
2. Seals the previous epoch (Lean `seal`), sends it to the witness, optionally publishes `<epoch>.rec` and optionally appends it to a workspace stream through a `mini workspace propose/submit` subprocess (`append_loop`, :742-791).
3. Collects arrivals until the deadline.
4. Builds the fill PRF stream outside Lean (`fill_pad`/`fill_bodies`, :424-477).
5. Assembles with Lean, computes the tick root with Lean, and writes CSVs.

**Lease file**: `slot holder pubkey-hex from to` (:370-414). **Fault plants**: `--fault-gap-at-epoch`, `--fault-drop` (:820-832).

**`channel.rs` member loop** (`join`, :349-632):
1. Verifies frames (`check_tick`).
2. Checks its own slot (kept or replaced, re-queuing on replace).
3. Trial-decrypts every other cell.
4. At `emit − μ`, picks the smallest queued payload or padding.
5. Seals with X25519 → cSHAKE256 → ChaCha20-Poly1305, with fields placed by Lean `seal_cell` (:192-221).
6. Emits at `arrival + T − δ`.

After each epoch it checks the published records against verified roots (`check_records`, :653-702). State lives in `HOME/ROOM/` (:32-36).

### 1.12 `hiding.rs`

A Rust re-implementation of the client half of `Compiler/StoreCodec` hiding (hiding.rs:1-43):
- KMAC256 per SP 800-185 (:117-123), checked against Lean conformance vectors (:538-550);
- a base-255 `StreamCodec.nat`, zigzag `intStream`, and `bytesStream` (:125-245);
- `blinding_key`, `cell_blinding`, `ratchet_step`, `ratcheted_blinding`, `owner_salt` (:247-305).

`verify_view` (:445-531) recomputes `ROOT/v2 = cSHAKE256(frame || leaves)` from opened and sealed items, compares it with `cell.root`, checks declarations (`check_declaration`, :344-402), and requires every displayed declared entry to be an opened entry. The ratchet vectors are pinned to the compiled Lean core (:610-622).

### 1.13 `content_privacy.rs`

`classify` (content_privacy.rs:66-140) applies an exact field list per action tag and recursive identifier/decimal checks. It returns an `Exposure`. `actions` (:142-153) allows 1..64 actions and refuses `Unsupported` actions (`link`, `unlink`, `mark`, `unmark`) when `sealed`. It mirrors Host/Json.lean:899-960 `contentAction` (same tags, same exact-field lists). It is on every content proposal path (`workspace::content_actions`, workspace.rs:2726-2728).

### 1.14 `fsio.rs`, `bounds.rs`, `trace.rs`

- `fsio.rs` is the crate's single file I/O layer: create, replace, retain-exact, sync, read-bounded, private directory and socket checks, seed loading with `Zeroizing`, randomness (fsio.rs:15-163).
- `bounds.rs` is generated by `Kernel/Bounds.lean` (`#eval Bounds.emitRust`). It carries a `#![allow(dead_code)]`. Only `FRAME_BYTES_MAX` and `LOOKUP_FRAME_BYTES_MAX` are used in this crate; the other 10 constants have 0 uses (grep).
- `trace.rs` appends one JSON line per event to the absolute path in `MINI_TRACE`, using `O_APPEND` and mode 0600 (trace.rs:12-40).

### 1.15 Processes, sockets, files, environment

**Processes.**
- `mini serve` / `serve-operator` and one `minidregg-host CONFIG stdio` child (transport.rs:1449-1476).
- `mini socket-proxy`, one per ssh session.
- `mini serve-public-proxy`.
- `mini consumer-worker` (long-lived), which spawns direct Host CLI children for upgrades (drain.rs:61-91).
- `mini relay`, which spawns `mini workspace` children (relay.rs:759-777).
- `mini traffic` client and server, `mini mix-live` actors (one per role and slot).

**Sockets.**
- `X.sock` (0600) with siblings `X.lock`, `X.config`, `X.mode` (transport.rs:1241-1249) and, in operator mode, `X.control` (operator_drain.rs:121).
- Public proxy `P.sock` with `P.lock`/`P.config`/`P.mode` (public_proxy.rs:506-513).
- Traffic client `S`, `S.control`, `S.repair` (scheduled_transport.rs:886-899).
- TCP: the traffic server (`--listen`), mix-live endpoints, the relay `--tcp`, and the NNTP client to 127.0.0.1.
- Relay member/witness Unix sockets, created with umask permissions (relay.rs:863-864, 1336-1337).

**Files.** As listed in 1.7 through 1.11.

**Environment.** `MINI_TRACE` (trace.rs:16); `MINI_CHANNEL_HOME`, `HOME` (channel.rs:73-77); `MINI_SSH` (proxy.rs:19, in mini_sdk); test-only `MINI_TEST_FOREIGN_UID` (transport.rs:2077) and `MINI_FAKE_HOST_LOG` (:2533). `MINIDREGG_HOST_TRACE` is read by the Lean Host (Host/Main.lean:2648).

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations used, with the Lean cross-check

| Sender in shard | Ops | Rust encoding | Lean receiver | Agreement |
| --- | --- | --- | --- | --- |
| transport.rs (all clients) | any | envelope/frame in 1.2 | `serveSession` → `serveFrame` → `dispatchSession` / `fnDispatch` (Host/Main.lean:2667, 2616, 2006) | Length LE u32 including the op byte: agrees (Host/Main.lean:2311-2316). Op-153 bound: agrees (`frameBound`, :2289-2291 vs transport.rs:27-32). Empty frame: Rust refuses before sending (`write_frame` :665), Lean answers 255. Reply tags 255 and 34/164: agree (Host/Main.lean:2326-2366 vs transport.rs:1089-1098) |
| drain.rs / main.rs `consumer_poll` | 12 (B) / 14 (A) | empty payload (main.rs:2704) | `fnDispatch` 12→`runFnPollSession`, 14→`runFnReplyPollSession` or the catalog variant (Host/Main.lean:6690-6711) | Rust public filter `[12 | 14] => true` admits only the empty form (transport.rs:334). Lean returns 255 `fn consumer poll service is not configured` when unset (:6691-6693). The JSON reply schema (`fn-consumer-poll-session-v1`, `status`, `intentHex`, `decision`) is checked in Rust (main.rs:2713-2772). I did not read the Lean poll producer, so the schema is unverified from this side (Q8.3) |
| drain.rs / main.rs `consumer_ack` | 13 / 15 | canonical decimal txn id, 1..80 bytes (main.rs:2855-2861) | `runFnAckSession` / `runFnReplyAckSession` (Host/Main.lean:6697, 6703-6709) | The filter requires canonical digits ≤80 (transport.rs:335-340). The reply `fnAck` ∈ {durable-accepted, covered-by-durable-frontier, refused, uncertain, transport-fault} is parsed in Rust (main.rs:2774-2845); the Lean side was not read (Q8.2, Q8.4) |
| drain.rs `retry_outcome` | 2 (submit) / 3 (lookup) through main.rs `retry_with_upgrade` | exact retained `call.bin` | `fnDispatch` 2\|3 → `carriedOrdinaryCall` or `NativeHost.lookupLoaded` (Host/Main.lean:6673-6689) | Byte-exact resend; Lean decides replay (Q8.5) |
| drain.rs `upgrade_host` | Host CLI `inspect outcome`, `lookup` (not socket ops) | file paths on the CLI (drain.rs:533-557) | the Host/Main.lean CLI verbs | Requires the service lock, so the Store is not concurrently served |
| scheduled_transport / async_dispatch / pq_mailbox | any public op | exact client envelope forwarded with `exchange_unix` after `public_envelope` (scheduled_transport.rs:466-477; async_dispatch.rs:297-305; pq_mailbox.rs:319-327 → :508-516) | as above | Same gate as the public socket |
| proxy.rs, public_proxy.rs | any public op | exact envelope | as above | Same gate (proxy.rs:69; public_proxy.rs:334) |
| relay.rs | none directly; spawns `mini workspace --action propose/submit` (relay.rs:752-777) | — | — | — |
| operator_drain.rs, channel.rs, cohort_tcp.rs, hiding.rs, content_privacy.rs | none (local control socket, TCP links, or local computation) | — | — | — |

### 2.2 The two central slice-pattern allowlists vs `routes` in `protocol/host-operations.json`

`protocol/HOST-OPERATIONS.md` says "The scanner understands the current three-layer Host dispatcher and the two central Rust slice-pattern allowlists". Those two are:

- **public**: `fn allowed_operation(request: &[u8], catalog_enabled: bool) -> bool` at transport.rs:308-512;
- **operator**: `fn allowed_operator_operation(request: &[u8]) -> bool` at transport.rs:526-618. The operator socket admits `allowed_operator_operation(r) || allowed_operation(r, catalog)` (transport.rs:1905-1911).

I encoded both arm sets by hand from the source (scratch `routes.py`) and compared them with all 186 registry entries (`routes.tsv`):

| Class | Count | Rust behaviour |
| --- | --- | --- |
| `routes: ["operator","public"]`, status active | 115 | All admitted by `allowed_operation`, and therefore by both sockets |
| `routes: ["operator"]` | 69 | All admitted only by `allowed_operator_operation`: 22-23, 26-27, 32-85 (except 28-31), 117-120, 152, 154, 164, 206-209 |
| `routes: []` (stdio only) | 2 | 24, 25 (`SELECTED_SOURCE_PUBLISH_*`): in neither list. Correct |
| reserved (191 `CARRY_PAY_CLAIM_LOOKUP`, 192 `LAW_DIAGNOSTIC`) | 2 | In neither list. Correct ("may not appear in a shipped dispatcher or allowlist until explicitly promoted") |
| Unallocated bytes | — | No Rust arm admits an unallocated byte |

**Result.** No operator-only op is reachable through `socket-proxy` (proxy.rs:69), `serve-public-proxy` (public_proxy.rs:334), `traffic` (scheduled_transport.rs:469), `AsyncDispatch::offer` (async_dispatch.rs:158-160) or `dispatch_once` (scheduled_transport.rs:508-510). All of them call `public_envelope` → `allowed_operation`. No public op is blocked.

**Defects inside the lists, none of which change exposure:**
- **Stale operator arms** for "C14 TAIL-BOUND" at the old numbers 130-133 (transport.rs:593-597). The comment at :489 says the lane moved to 170-173, and the public list carries 170-173 (:490-493). Op 130 is now `AFFORDANCE_DRY_RUN` and 131-133 are NOCK. On the operator socket the stale `[130 | 132, payload]` arm admits op 130 with any non-empty payload, while the public arm requires an `exact_pair` (:413). The union makes the operator socket's filter for op 130 looser than the public one. This is harmless, since the Host's `splitPair` refuses (Host/Main.lean:2062), but it is a second, wrong definition of op 130's shape that the scanner's "duplicate/shadowed arm" detection did not flag across the two lists.
- **Duplicated arms present in both lists** (28/29, 86-95, 126-129). Redundant because of the union.
- **A misplaced doc comment** describing operator routes sits above `exact_pair` (:514-516).
- **Many public ops are bounded only by the frame** (12 MB): `[0..=11, ..]`, `[123..=125, _, ..]`, `[131..=137, ..]` (:326-333), including NOCK dry runs and the realm wells.

### 2.3 Operating-system facilities

| Facility | Where | Portability |
| --- | --- | --- |
| Unix stream sockets, `SO_PEERCRED` (Linux `getsockopt(1, 17)`), `getpeereid` (BSD/macOS) | transport.rs:1938-1996 | Other platforms: operator peers always refused |
| `memfd_create` + `F_ADD_SEALS`, exec through `/proc/<pid>/fd/<n>` | transport.rs:1368-1393, 1432-1447 | Linux only; other platforms check the path and keep a TOCTOU window (documented :1311-1318) |
| `poll`, `fcntl` (hand-declared FFI) plus `libc` crate calls | transport.rs:676-693 (FFI), 1001-1083 (libc) | `O_NONBLOCK` constants hard-coded per OS (:779-782) |
| `sigaction` SIGTERM/SIGINT | public_proxy.rs:22-57 | Unix |
| `dlopen`/`dlsym` (`#[link(name="dl")]`) | relay.rs:67-72 | Unix; needs the Lean shared runtime (`-lleanshared` with rpath; channel-lib/build.sh:39-40) |
| `/proc/loadavg` | relay.rs:691-693 (silently empty on macOS) | Linux |
| `clock_gettime(CLOCK_PROCESS_CPUTIME_ID=2)` with a hard-coded constant | relay.rs:675-689 | Linux/macOS value coincidence |
| flock-based `mini_sdk::lock::Lease` | transport.rs:695-711 | Unix |
| No bwrap, seccomp, cgroups, setuid or systemd API in this shard | — | — |

### 2.4 Network services and external programs

- **fn NNTP** on `127.0.0.1:port` with STARTTLS, an exact pinned certificate, and AUTHINFO USER/PASS (worker.rs:359-444). The GROUP is a wake hint only.
- **ssh client** through `mini_sdk::operator` (`MINI_SSH`, host-key checking forced on: proxy.rs:16-20).
- **No** Solana, Discord, OpenAI-compatible providers or gitweb in this shard.
- **TCP peers** in the research stacks (traffic, mix-live, relay).

### 2.5 Other crates and artifacts

- `mini-sdk` (path dependency): `lock`, `durable`, `private`, `secret`, `operator` (ssh), `hex`, `decimal`, `random`, `fsread`, `signer::HybridSigner`, `store::AttemptDir` (main.rs:2441).
- `hybrid_kem.rs`, `crypto_transit.rs` (`#[path]` includes, main.rs:88-92).
- Pinned external crates (Cargo.toml:13-37): libc, ring, rustls+pemfile, x509-parser, chacha20poly1305, x25519-dalek, ed25519-dalek, sha2, sha3, aws-lc-rs/aws-lc-sys, serde_json, zeroize.
- The Lean library `libminidregg-channel.so` (relay/channel only) from `channel-lib/build.sh`. It requires `lake build` of 12 module objects first (build.sh:8-12) and refuses if the closure grows beyond Init plus the workspace (:24-31). **No gate, journey row or unit builds it.** `journey.sh` hooks KCHR and KCHC exist (journey.sh:23-25), and they exit when the library is absent (journey.d/jchan-relay.sh:52).

---

## 3. Does it decide anything semantic?

Each entry is labelled **VIOLATION**, **POLICY-IN-RUST** (policy that arguably belongs to Lean or should be Lean-emitted, but Lean still gates admission), or **MIRROR** (Rust pre-checks what Lean decides anyway).

1. **Which ops each socket exposes: VIOLATION of "every decision point is a Lean export" (by design, a physical boundary), single point of failure.** `allowed_operation`/`allowed_operator_operation` (transport.rs:308-618) is the only place that decides who may invoke ops such as 42 `FN_NAMESPACE_PLAN` ("Op42 obtains all selectors from pinned operator settings… No caller field enters its plan", :554-556), 64, 32/33 (share-issue plan and assembly) and 117-120 (sponsor-custodied self-enrollment). The Lean `dispatchSession` receives only `(operation, payload)` (Host/Main.lean:2006-2011) and cannot refuse a stranger who reaches an operator op. The registry gate (`scripts/host-operations.py check`) is the counterpart. It checks that Rust selectors match JSON `routes`, but the JSON is itself hand-written. Blast radius if wrong: any operator-only op becomes publicly invocable, and only the op's own signatures stand behind it. Lean counterpart: none. Q8.10 asks which of the 69 operator-only ops are safe against an unauthenticated caller on Lean evidence alone.

2. **Per-operation body bounds: POLICY-IN-RUST, hand-written beside `Kernel.Bounds`.** These limits are not emitted by `Kernel/Bounds.lean`:
   - `AUTHOR_BODY_MAX` = 258 + 4 MiB for op 7 (transport.rs:39-44);
   - `SIGNATURES_BODY_MAX` = 16 KiB for op 9 (:47);
   - `NO_BODY_OPS` [0, 6] (:49);
   - 121/181/182 ≤4096-byte JSON objects (:315-316); 183 ≤2048 (:319); 184 ≤4096 with plan ≤3072 (:320-322); 185/186 ≤4096 (:323);
   - 30/31 ≤256 KiB JSON object (:370-375); 91 source ≤4 MiB JSON object (:378-386); 144 ≤1024 (:448-453); 187 ≤4096 (:442-443); 214/219 ≤64 KiB (:500-509);
   - 16 ≤1,516,384 (:341); 19 metadata ≤4096, request ≤1 MiB, response ≤8 MiB (:350-367);
   - operator side: 40/41 ≤8192 (:542), 60-63 ≤16,384 (:545), 64 ≤128 (:548), 43 plan ≤8192 (:559-565), 32 ≤256 KiB (:598).

   The comment at :34-38 records why op 7 was cut: a 12 MB array cost the Host 11 s and 775 MB. Where Lean would accept, Rust refuses first, so a false refusal is decided in Rust. Where Lean would refuse, this is a mirror. Lean counterpart: `Kernel.Bounds` (only `frameBytesMax`/`lookupFrameBytesMax` are emitted into bounds.rs). Blast radius: availability and UX only. These bounds are not authority, but they are 20-odd hand-maintained constants that drift independently of the Lean decoders (law 13). Q8.6.

3. **The "pure op" Host-time budget is a false semantic claim: POLICY-IN-RUST.** `host_budget` (transport.rs:63-68) gives ops `0 | 6..=11` 120 s because they "read no Store and commit nothing" (:54-55). Lean op 0 calls `sessionOpened` (Host/Main.lean:2016). Op 8 `object-audience` and `object-audience-roster` call `sessionWalked` (:2050-2054, :2066), which walks the Store session. If a large-world audience walk exceeds 120 s, the Host is killed and restarted (transport.rs:1787-1795). That is read-only, so no state is lost, but it costs a restart, and every queued caller pays the reopen time. The test asserting op 130 is a "state" op (:2920) shows the classification is hand-curated. Lean counterpart: none. A per-op purity or cost class would have to be emitted from the registry or Lean.

4. **Reply-tag acceptance: MIRROR.** `response_operation_matches` (transport.rs:1089-1098) mirrors Host/Main.lean:2326-2366 exactly.

5. **Drain poll classification and advancement: MIRROR/POLICY-IN-RUST.**
   - `classify_poll_route` (drain.rs:724-798) and `validate_skip_decision` (main.rs:2644-2690) decide whether the worker may advance: idle, skip, or publication. The skip distance must be 1..=16 and `to ≤ u32::MAX` (drain.rs:769-772; main.rs:2677-2684). Field counts must be 4 or 5 (main.rs:2659-2661). "Short page" means continue or stop (drain.rs:776).
   - These are the worker's scheduling rules. Lean still admits the resulting call and ACK. Wrong Rust here means a stall or a hold (fail closed), never a semantic grant.

6. **ACK retry semantics: POLICY-IN-RUST, conservative.** At most one exact ACK retry, fenced by `ackRetryStarted` (drain.rs:943-953). Covered → hold (:921-925). Refused → hold (:926-931). This is Rust deciding retry policy for an external side effect (an fn cursor ACK) that the Host performs. It is safe only if Lean op 13/15 is idempotent for the same txn (Q8.4). Blast radius if Lean is not idempotent: one duplicate ACK at most.

7. **"Recoverable refusal" classification: VIOLATION (small).** `resume_held_ack_route` permits a recovery ACK only if the prior ACK reply is a complete 255 frame (drain.rs:1127-1133) whose decoded `phase` equals the hex string `"666e2d73657373696f6e"` = "fn-session" (drain.rs:1144-1147). Rust decides which Lean refusals mean "no effect happened, safe to retry once" from a free-text phase label. Lean counterpart: should be an explicit retryable/no-effect bit in the outcome codec (`NativeHostCodec.Outcome`). Blast radius: a second ACK attempt after a refusal that did have an effect. Q8.15.

8. **Receipt identity across Host upgrades: POLICY-IN-RUST.** `upgrade_host` decides that a retained call's receipt is "the same" under a new Host image because all four canonical fields match between the operator's known outcome and the new Host's lookup (drain.rs:558-570; `confirmed_fields` :35-52). Lean authors the fields and Rust compares them. This is Rust adjudicating continuity of identity across images. It is acceptable for operator tooling but has no Lean declaration.

9. **fn POST reply interpretation: external-service policy in Rust.** `classify_post_reply` (worker.rs:501-516) maps exact human-readable NNTP texts to `AlreadyStored`/`Conflict`/`ExplicitUncertain`. The publishers (not this shard) decide retry from that. A wording change in the fn server silently reclassifies to `Refused` or `TransportUncertain`, which is fail closed.

10. **Transport-level dedup by ticket: physical, conservative.** `scheduled_transport::Journal::admit` (:352-386), `AsyncDispatch` (async_dispatch.rs:146-206) and `pq_mailbox::claim` (:157-178) decide "same request" by a client-chosen 16-byte ticket plus exact bytes. A dispatch marker without a reply is permanently Uncertain and never redispatched. This stays inside the transport layer and correctly defers semantic dedup to Lean.

11. **Membership and slot authority in the privacy stacks: VIOLATION in the sense of the law, admitted by the docs.**
    - The cohort roster JSON decides who may send in each slot: `parse_roster`/`roster_entry` (cohort_tcp.rs:472-539), with signatures verified in Rust (`signer::verify`, :740).
    - The registrar decides admitted sets (`manifest`, pq_mailbox.rs:381-427).
    - The channel lease file decides slot admission (relay.rs:617). Lean `assemble` also receives the lease records (relay.rs:1077), so slot-holder filtering is partly re-checked in Lean (Q8.11).
    - COHORT-TCP.md says "enrollment slots are not Mini sender authority", and README "Honest state" says "honest registrar". Blast radius: privacy and availability of the research cohort only. No Mini authority, because the mailbox still forwards native signed calls through `public_envelope`.

12. **Sealed content policy: POLICY-IN-RUST with a duplicated grammar.** `content_privacy::actions` refuses sealing `link/unlink/mark/unmark` (content_privacy.rs:148-150) and fixes the closed action list and exact fields. That list duplicates `contentAction` (Host/Json.lean:899-960). For sealed (private) documents the Host cannot see plaintext, so the policy on what may be exposed in clear (`Exposure::Structure`) is necessarily client-side, which is legitimate. The duplicated grammar is a twin that will drift. Lean counterpart: Host/Json.lean `contentAction`. The Rust grammar should be emitted from it.

13. **View verification: client-side verification (legitimate), implemented as a re-implementation.** `hiding::verify_view` decides "view refused" (hiding.rs:486-490, 514-525) by re-implementing StoreCodec hashing and codecs (hiding.rs:117-245). It is vector-pinned against Lean (:538-550, 610-622). The client correctly verifies what the Host serves. The twin risk is drift of `frame`/leaf encoding (Q8.12).

14. **Correct deferrals worth recording:**
    - The traffic, mix and proxy layers never synthesize Host outcomes: scheduled_transport.rs:690-692; async_dispatch.rs:20-27; public_proxy.rs:361-374.
    - The drain worker never infers success from transport errors: drain.rs:1390-1394, 1437-1438.
    - Transport reports "uncertain" and never retries: transport.rs:869-870.
    - The relay's channel semantics (header, assemble, fanout, tick root, seal, open, topic, payload cap, envelope placement) are Lean exports called in-process (relay.rs:10-24). This is the most law-compliant code in the shard. Only the fill PRF and the AEAD sealing are Rust (by design, relay.rs:424-426; channel.rs:23-31).

---

## 4. Flaws noticed

Severity: **H** (affects the demo path or makes a second operation possible), **M**, **L**.

### 4.1 Lost-reply and retry hazards

- **H, scheduled_transport.rs:667-678 + 702-737: an orphaned request is dispatched after restart.** The local facade persists `<ticket>.request` before `sender.try_send`. If `try_send` fails ("traffic admission queue full before transmission", :678), `work()` returns an error, the connection closes without a frame (the caller reports "uncertain"), and `handed_off` stays false. The `.request` file stays on disk. On the next `traffic --action client` start, `recover_local` re-queues every `.request` without a `.reply` and transmits it. The caller was told nothing certain and may by then have authored and submitted a different call for the same intent (for example after a stale-root replan or a manual retry with a fresh plan). Both execute unless Lean dedups by intent rather than by call. The doc's claim "Restart queues the same ticket and exact envelope; fresh session keys/sequence do not authorize a fresh effect" (TRAFFIC-PRIVACY.md) holds for the ticket, not for the caller's fresh call.
- **M, scheduled_transport.rs:473-475 and async_dispatch.rs:302-303: an oversized reply becomes "uncertain" after the effect.** A backend reply longer than `max_body` (default 65,536, :822) is recorded as kind 1 "uncertain" even though the Host completed. TRAFFIC-PRIVACY.md itself notes that observed narrowed proofs are about 65 KB. Every such call is a lost reply by construction, and recovery needs a native lookup, which may itself exceed the bound.
- **M, drain.rs:1303-1310: wedge after a crash during the first state write.** The check accepts only directory entries named `state-*.tmp` as leftovers. `mini_sdk::durable::stage_file` names staging files `.{name}.durable-{pid}-{n}-{nanos}` (native/mini-sdk/src/durable.rs:118). A SIGKILL during the first `save_state` leaves `.state.json.durable-…`, `only_state_temps` is false, and every subsequent wake returns "pending worker slot lacks durable state; operator review required". The stale convention never matches a real leftover, so the recovery branch is dead code for crash leftovers. It does handle the empty-directory case, because `all()` is vacuously true.
- **M, a lost poll reply turns into Held (availability, not a second operation).** In `Polling`, if `consumer_poll` fails before `reply.frame` is written, the phase stays Polling with an incremented serial (drain.rs:1326-1336). If the Host durably recorded a "proposed-fresh" decision, the next poll may return a historical/repeated decision with an empty intent, which `classify_poll_route` rejects. The worker then holds (:1338-1341). Whether this happens depends on whether poll is pure (Q8.3). If it is not pure, every lost poll reply needs manual repair, and there is no tool for it (`consumer-resume-ack` handles only held ACKs, :1103-1105).
- **M, Lean answers "refused" when a handler throws after committing.** `serveFrame` answers any exception with 255 `refused operationRejected` (Host/Main.lean:2652-2663), and `answer_refused` proves the answer is always a refusal (Host/RequestRefusal.lean:91-99). Rust callers take 255 as a definitive refusal. Drain holds on "refused" (drain.rs:1383-1389) and does not retry, which is safe for drain. A naive client would conclude "not done" for a committed operation. Q8.1.
- **L, transport.rs:1166-1173: the post-failed-write sniff.** After a failed write the client waits up to 1 s and accepts any frame starting with 254 as certain. The service only ever sends 254 for unforwarded requests, so this is correct. It relies on the invariant that no Host reply begins with 254 (Q8.9).
- **L, relay.rs:742-791: an uncertain epoch-record append is lost.** `append_loop` runs `mini workspace propose` and `submit` once per epoch. An error is logged to `appends.csv` as `refused`/`error` and never recovered, not even with a lookup. The workspace attempt directory exists (`attempts/<id>`), but the relay never retries it.

### 4.2 Availability and DoS (stranger or member)

- **H, a single Host thread with long budgets lets one member monopolize the Host.** Public state ops get a 600 s Host budget (transport.rs:53, 63-68), and the queue residence is 60 s (:1550). One member sending heavy requests in a row (op 131-137 NOCK dry runs, 150 law-sat, 7 author up to 4 MiB, 19 with an 8 MiB response, 16 with a 1.5 MB carrier) keeps the single Host busy. Everyone else gets `254 busy: queue residence deadline` after 60 s. On the ssh proxy deployment all members share one uid (deploy/shell/mini-socket-proxy runs as the proxy account), so fair queueing degenerates to FIFO (serve_queue.rs:10-14) and one member can fill the 32-slot queue alone.
- **H, split topology: the public relay starves the operator control plane.** `public_proxy` requires upstream peer uid == its own euid (public_proxy.rs:358, 502). On the operator socket, relayed strangers and the operator's own lifecycle and drain clients are therefore one `serve_queue` peer, sharing `max_connections` 64 and `host_queue` 32 (transport.rs:1548-1549, 1719). The relay allows 64 concurrent upstream connections (public_proxy.rs:68), which exactly fills the operator socket's 64-connection limit. Lifecycle calls (ops 22-85, 206-209) then get `busy: connection limit`. Displacement cannot help, because displacement needs distinct peers (serve_queue.rs:86-87).
- **M, transport.rs:1838-1843: the connection-limit refusal blocks the accept thread.** The refusal is written synchronously on the accept thread with a 1 s write timeout. A burst of connections beyond 64 that do not read can stall acceptance for up to 1 s each, delaying honest clients and stop detection.
- **M, transport.rs:1155: no connect deadline.** `exchange_unix` uses a blocking `UnixStream::connect` with no deadline. On Linux a full AF_UNIX backlog blocks the connect. This matters during the accept-thread stall above, and `socket-proxy` (proxy.rs:70) and the scheduled, async and mailbox backends all use `exchange_unix`. The deadline variant (:980-1084) exists only for `invoke_pinned_deadline`.
- **M, proxy.rs:38: idle ssh sessions are unbounded.** `relay` reads frames from ssh stdin with no deadline. An idle member session holds a `mini socket-proxy` process indefinitely. Only sshd settings bound the count (not in this shard).
- **M, public_proxy.rs:437 and :454: errors kill the whole relay.** A failure to set nonblocking or to spawn a thread is returned with `?` from `run` and ends the entire relay (fail closed). Under memory pressure caused by a stranger flood, a thread spawn failure takes public ingress down. The service runs without `Restart=` guidance in PUBLIC-INGRESS.md.
- **M, relay.rs:865-886: unbounded threads per connection.** Unbounded `thread::spawn` per accepted Unix or TCP connection. `handshake` sets a 5 s read timeout per read (:599), so a peer trickling one byte every 4 s holds a thread for about 7 minutes per handshake. There is no connection cap. Any host reaching `--tcp` can exhaust threads and memory.
- **M, relay.rs:861 + 656-664: no rate limit on a leased member.** The arrivals channel is unbounded, and `serve_member` pushes every C-byte cell the member sends with no rate limit. A leased member can grow relay memory without bound between ticks. `pending` also accumulates (:1047-1049).
- **M, relay.rs:1351-1366: `relay-witness` allocates from wire lengths.** It allocates `vec![0u8; rlen]` and `vec![0u8; olen]` from u32 lengths read off its socket (up to 4 GiB each), which aborts on OOM. The socket is bound with umask permissions (no chmod, :1336-1337), and the witness accepts exactly one connection (:1341). A local user who connects first hijacks the witness role.
- **M, cohort_tcp.rs:724-791: cheap connections cost an ML-KEM keygen each.** For every accepted TCP connection, `answer_enrollment` runs `HybridSecret::generate()` (an ML-KEM-768 keygen) and writes a 1,252-byte challenge before any authentication (:731-735). The listener is single-threaded with a 3 s handshake bound (:433, 777). A continuous stream of stalling strangers can keep the legitimate sender from reaching the listener before `p.when(start)`, after which the link is lost: "public enrolled connection deadline exhausted" (:766-768). The regression test covers only two strangers (:1605-1650).
- **M, scheduled_transport.rs:846-854: one session at a time, and fatal accept errors.** `traffic --action server` serves one session at a time. An unauthenticated TCP peer holds the server for up to `tick*2+5 s` per read (`network`, :548-556) before the first cell fails AEAD, and can reconnect indefinitely, keeping the resident client out. An accept error (`stream.map_err(...)?`, :847) ends the server.
- **M, scheduled_transport.rs:651-667, 868-881 and :365-367: a finite-lifetime device.** Retention is monotone: `.request` files are never garbage-collected and the counters never decrease. After `retained` requests (default 4096; application quota 2048, `retained_quotas` :86-88) the client refuses forever ("traffic retention full"), and the server journal refuses "retained class capacity exhausted". Documented ("deliberately does not implement GC"), but fatal for any deployment.
- **L, async_dispatch.rs:262-268 and scheduled_transport.rs:501: directory scans per operation.** `run_next` reads and sorts the whole custody directory per job, which is O(n²) over a lifetime of up to 1e6 records. `dispatch_once` re-opens the `Journal`, scanning the directory, per call.
- **L, worker.rs:757 and :771: a transient NNTP error ends the worker.** `group_hint(&cfg)?` inside the drain loop ends the long-running worker on any transient NNTP failure, whereas the idle path tolerates it (:746-752).

### 4.3 Panics and unchecked parsing on untrusted bytes

- transport.rs: every `try_into().unwrap()` on payload slices is behind a length check:
  - `split_envelope` :177/180;
  - `carried_lookup_request` :291-294;
  - `[19]` :350-361 (`payload.len() >= metadata_length + 9` guarantees `request_prefix+4 ≤ len`);
  - `[65]`/`[43]`/`[33]`/`[37]` arms :550-614.

  `exact_pair` uses `checked_sub` (:517-524). No panic path found on the service or proxy side.
- **L, transport.rs:1133-1136: implicit non-empty assumption.** `invoke_inner` indexes `reply[0]` without an emptiness check. It relies on `read_frame` refusing a zero length (:645) and `mini_sdk::operator::read_frame` refusing `size == 0` (native/mini-sdk/src/operator.rs:379). Correct today but implicit; the deadline variant checks it explicitly (:961).
- **L, channel.rs:509 and :536: underflow on `epoch == 0`.** `head.epoch - 1` when `head.tick == 0`, `k > 0` and `epoch == 0` (a signed frame from a misbehaving relay) panics in debug and wraps in release.
- **L, relay.rs:637, 648, 665 (and others): poisoned-mutex panics.** `log.lock().unwrap()` and `shared.slots.lock().unwrap()` panic on a poisoned mutex.
- **L, channel.rs:526-527: unbounded partial messages.** The `partial` reassembly map grows without bound if a roster member never sends a final fragment.
- hiding.rs: `check_declaration` indexes `entry[1..]` only for entries whose first byte is 4..=6 (partition at :512), so they are non-empty. `nat_prefix` handles terminators (:325-335). No panic found.
- pq_mailbox.rs, cohort_tcp.rs, scheduled_transport.rs: slices follow exact-length checks (`unbatch` :132-141, `verify_manifest` :439-447, `open` cohort_tcp.rs:225-230, `Codec::open` :197-217).

### 4.4 Blocking I/O on async paths

There is no async runtime in this shard (no tokio, no futures). Everything is threads with blocking or poll-based I/O, so "blocking on an async path" does not apply. The comparable hazards are synchronous fsyncs on clocked paths, which COHORT-TCP.md records as measured refutations, and blocking connects without deadlines (4.2).

### 4.5 Key handling

- **L, worker.rs:291-304 and 423-438: password not zeroized.** The NNTP password is read into a plain `Vec<u8>` and not zeroized.
- **L, relay.rs:480-499: secret copied out of `Zeroizing`.** `secret_file` returns `*seed` (a plain `[u8; 32]`) for the relay secret, the relay frame key and member keys.
- **L, scheduled_transport.rs:110-113: PSK not zeroized.** `key()` returns the PSK as a plain array.
- **L, channel.rs:583-587: random padding fragment header.** Padding uses random frag bytes `f` that could look like a valid fragment header. They are encrypted to a discarded key, so harmless.
- No keys in argv, environment or logs were found. The relay logs record subjects and slots, not keys (relay.rs:654).

### 4.6 Fail-open and error swallowing

- **M, scheduled_transport.rs:463-465 and 478-483: silent backend death.** The backend thread `break`s silently on a persistence or poisoned-lock error. Every later offer becomes "uncertain" through `Disconnected` → `Err` → `outcome(1, UNCERTAIN)` (:590). That is fail closed, but with no log line, the service looks alive while answering everything "uncertain".
- **M, async_dispatch.rs:131-134: the same pattern.** The worker exits on any error, and later offers report "worker stopped" only when the wake channel is disconnected.
- **L, pq_mailbox.rs:319-332: refusals masked as uncertain.** All `dispatch_once` errors, including a ticket/body conflict that is a definite refusal, are mapped to `1 "native dispatch uncertain"`.
- **L, relay.rs:732: record publication failure ignored.** `publish_record` ignores failure (`let _ =`), so members then count the record as missing.
- **L, relay.rs:863 and 1336: unconditional removal.** `fs::remove_file(&unix_path)` runs before bind with no stale-socket proof. It deletes whatever is at that path, unlike `transport::clear_stale_socket`.

### 4.7 TOCTOU

- transport.rs pins and execs sealed images on Linux. Elsewhere the documented path race remains (:1311-1318, 1416-1424).
- public_proxy.rs:339: `check_upstream` per request is TOCTOU against the subsequent connect. It is mitigated by the peer-uid recheck (:358).
- drain.rs `upgrade_host` re-checks all inputs after the read-only lookups (:571-578) and re-checks the pin before replacing it (:609-611). Good.

### 4.8 Documentation contradicting code

- native/resource-client/README.md:195-198 says every socket request is v2; three call sites still send v1 (see 1.2).
- native/resource-client/README.md:211-213 says "a host reply to 600 seconds"; the code uses per-op 120/600 s (transport.rs:53-68).
- hybrid_kem.rs:3-15 says "Every key exchange in `native/` goes through here… There is no pure-X25519 … path"; channel.rs:201-208 does raw X25519 Diffie–Hellman for every cell.
- README "Honest state" (README.md:91) lists traffic privacy as "one host". docs/evidence/traffic-v13/v13-two-host/native-delayed/public-run-summary.json records a two-host run: 64/64 valid broadcasts for every client, 16 exactly-once native submissions, `topology: two-host`.
- COHORT-TCP.md ends with "pending one targeted check/release and renewed 64-epoch paired receiving". It is an appended diary, contrary to the owner's "rewrite whole, never append" rule, and is superseded by that evidence.
- operator_drain.rs:1 calls itself "Local transport lifecycle control". The name `drain.rs` (the fn consumer) collides with it conceptually.

---

## 5. Unwired / undone

### 5.1 Reachability per module

| Module | Entry | Unit / journey / evidence | Demo path? |
| --- | --- | --- | --- |
| transport.rs `serve` | `mini serve` (main.rs:3281) | deploy/candidate/run.sh:157 (and :261 unit template), deploy/grain-host/install-operator-stack:133 | **Yes, deployed** |
| transport.rs `serve_operator` | `mini serve-operator` (main.rs:3307) | native/resource-client/platform-provision.py:58; journey.d/jpay-e4.sh:147, jpay-v2.sh:151, jpay-bootstrap-budget.py:66 | Platform plan, not the candidate |
| proxy.rs | `mini socket-proxy` (main.rs:3204) | deploy/shell/mini-socket-proxy; journey row `sshe2e` (scripts/pipeline/journey-rows:316-332) | Shell proxy mode; README says the public node has "no proxy mode" (README.md:79) |
| public_proxy.rs | `mini serve-public-proxy` (main.rs:3324) | platform-provision.py:59; jpay journeys; public-ingress-process.py | Platform plan |
| operator_drain.rs | `operator-status`, `drain-operator` (main.rs:3337) | platform-service-cut.py:233-235; latency-same-store.py:57; public-ingress-process.py:184-216 | Platform plan |
| serve_queue.rs | through transport | — | Yes |
| drain.rs, worker.rs (consumer part) | `consumer-drain-once`, `consumer-worker`, `consumer-resume-ack`, `consumer-host-upgrade` (main.rs:3512-3624) | No unit, no journey row. Evidence from lane builds: docs/evidence/2026-09-26-host-session/ack-crash-recovery, 2026-09-26-mini-a-worker | No |
| worker.rs (fn POST part) | publisher.rs:295/391, selected_publisher.rs:403/472 | — (shard A) | No |
| scheduled_transport.rs | `mini traffic` (main.rs:3250) | No unit, no journey; TRAFFIC-PRIVACY.md cites private hbox evidence not in the repo | No |
| async_dispatch.rs | `mix --action mailbox` live path, `mix-live mailbox` | via cohort | No |
| pq_mailbox.rs | `mini mix` (main.rs:3252) | `qualification/pq-native-pipeline.py` is cited and **not in this repo** | No |
| cohort_tcp.rs | `mini mix-live` (main.rs:3254) | cohort-native-tcp.py, cohort-two-host/*.sh; evidence docs/evidence/traffic-v13 (two-host PASS, 2026-10-08) | No |
| relay.rs, channel.rs | `mini relay*`, `mini channel` (main.rs:3240-3248) | journey.sh hooks KCHR/KCHC (journey.sh:23-25) → journey.d/jchan-relay.sh, jchan-client.sh; need the hand-built channel library; **no evidence directory records a run** | No |
| hiding.rs | `verify_query_presentation` (main.rs:2228-2250); `mini key --action export-blinding/cell-blinding/derive-salt` (main.rs:3229-3233, 3736-3800) | journey.d/jhide.sh | Yes, read path (view-resource queries) |
| content_privacy.rs | workspace content proposals (workspace.rs:2726) | document journeys J0-J8 | Yes |

### 5.2 Dead or vestigial items

- `crypto-transit-main.patch` (8 lines) is already applied: main.rs:90-92 carries exactly `#[cfg(unix)] #[path = "../../crypto_transit.rs"] mod crypto_transit;`. Delete it.
- `CRYPTO-TRANSIT-CONSTRUCTION.txt`, `CRYPTO-TRANSIT-RESTORATION.txt`, `TRAFFIC-AUTH-CACHE-QUALIFICATION.txt`, `TRAFFIC-ENROLLMENT-CONSTRUCTION.txt`, `TRAFFIC-MAILBOX-GROUPED-CONSTRUCTION.txt` and `TRAFFIC-READY-ALIAS-CONSTRUCTION.txt` (28 lines total) are lane intake notes with hashes and statuses ("UNCOMPILED", "PENDING") that are now stale. One even says "Current suite is pure ML-KEM768/XChaCha … no classical hybrid", which the hybrid code has superseded.
- `check-traffic-crypto-alias.sh` names nextest filter `test(unauthenticated_garbage_and_replayed_startup_cannot_consume_enrolled_link)`, which no longer exists. The test is now `registrar_enrollment_admits_only_roster_member_signature_under_fresh_challenge` (cohort_tcp.rs:1539-1540), so the filter silently matches nothing. All five `check-*` scripts write logs and `artifacts/` into the caller-supplied source root, use GNU-only `df -B1 --output`, and are referenced from nowhere.
- `native/resource-client/scripts/cohort-native-tcp.py` (185 lines) is an older single-host copy of `cohort-native-tcp.py` (503 lines). Delete the older one.
- `cohort-two-host/env.sh` hard-codes rented boxes' public IPs (`162.43.189.7`, `67.213.124.13`) and lane paths `/srv/lanes/W15-TRAFFIC-V13` in a public repository (also in the evidence JSON).
- The `--peer-uid` option of `serve-operator` (main.rs:3314-3322; transport.rs:1190-1222) has no caller in deploy, scripts or journeys. Because the operator socket directory must be 0700 (transport.rs:1240), a foreign uid cannot traverse it anyway (the two-uid test demonstrates EACCES, :2101). It is dead and dangerous: anyone who opens the directory mode gets the full operator union.
- bounds.rs: 10 of 12 constants are unused in this crate (`#![allow(dead_code)]`, bounds.rs:4).
- transport.rs:593-597: stale TAIL-BOUND operator arms at 130-133 (see 2.2).
- drain.rs:1303-1310: the stale `state-*.tmp` leftover convention (see 4.1).
- The v1 envelope is still accepted by the service (transport.rs:177) and still emitted by three callers. Either finish the v2 migration or keep v1 knowingly.
- Version-refusal scar tissue kept only to refuse old formats by name:
  - MCE2/MCE3 challenges (cohort_tcp.rs:691-696);
  - roster v1/v2 (:498-503);
  - bare 32-byte native keys (:444-446, 477-479);
  - `MPB1`/`MPM1`/v1 sizes (pq_mailbox.rs:21-23, 30, 63-65, 82-84, 129-131, 435-437);
  - v1 KEM secrets (`V1_KEM_SECRET`, cohort_tcp.rs:415-417);
  - legacy journal refusals (pq_mailbox.rs:898-905, 1025-1032).

### 5.3 Tests that do not test the subject

- transport.rs:2073-2123 (`#[ignore]`, needs `sudo -n setpriv`) and proxy.rs:275-299 (`#[ignore]`, driven by ssh-e2e.sh) run only in special environments.
- trace.rs:49-56 asserts nothing when `MINI_TRACE` is set; when it is unset it only checks that `enabled()` is false.
- drain.rs:1475-1570 admits that "the stub supplies fixed receipt bytes only … does not establish native receipt semantics" (:1477-1478). That is honest, but it is a fixture test.
- relay.rs tests (:1381-1490) check byte layouts and PRF determinism without loading the Lean library. No test exercises `Lean::load`, `assemble` or `seal`. channel.rs tests (:829-898) exercise the AEAD round trip "without the Lean placement" (:864).
- transport.rs's allowlist tests (:3005-3724) test the hand-written filter against hand-written expectations. The registry consistency check (`scripts/host-operations.py`) is the real oracle, and my comparison (2.2) confirms agreement.

### 5.4 Twins (law: delete the twin)

| Twin A | Twin B | Which is reachable | Action |
| --- | --- | --- | --- |
| `transport::connect_unix_deadline` (transport.rs:980-1084) | `public_proxy::connect` (public_proxy.rs:159-231), also used by operator_drain.rs:221 | Both | Keep one (transport's handles EAGAIN with a 2 ms sleep and a computed `sun_len`; public_proxy's adds the stop flag) |
| `DeadlinePipe`/`DeadlinePipeWrite` (transport.rs:793-867) | `BoundedStream` + `wait_fd` (public_proxy.rs:77-157) | Both | Merge (B adds a stop flag) |
| `SocketGuard` (transport.rs:1254-1265, a local struct) | `SocketGuard` (public_proxy.rs:471-482), `SocketGuard` (operator_drain.rs:200-211) | All three | One shared type |
| hand-declared `poll`/`fcntl` FFI (transport.rs:676-693, :776-791 with hard-coded `O_NONBLOCK`) | `libc::poll`/`libc::fcntl` in the same file (:1006, 1047) | Both | Delete the FFI copies |
| `hybrid_kem::random` (hybrid_kem.rs:64-70) | `mini_sdk::random` ("the one reader of /dev/urandom", fsio.rs:71), and ring `SystemRandom` (operator_drain.rs:21) | All | One randomness source |
| `relay::secret_file` (relay.rs:480-499) | `fsio::read_seed` (fsio.rs:135-137) | Both | relay wraps the same `mini_sdk::secret`; dedupe the create-on-first-use path |
| `mini_sdk::operator` frame/envelope codec (native/mini-sdk/src/operator.rs:360-387) | `transport::invoke_inner`/`read_frame` (transport.rs:625-662, 1100-1150) | Both (ssh remote vs Unix) | One codec; note the different bounds (`HOST_MAX_FRAME + 1` vs `MAX_FRAME`) |
| `content_privacy.rs` grammar | Host/Json.lean:899-960 `contentAction` | Both | Emit the Rust grammar from Lean |
| `hiding.rs` StoreCodec/KMAC re-implementation | `Compiler/StoreCodec.lean`, `Compiler/Sp800185Kmac256.lean` | Both (client verify vs Host) | Acceptable as an independent client verifier only if vector-pinned for every encoding branch; currently KMAC + ratchet only (hiding.rs:540-622), no root-of-frame vector |
| Traffic stack 1: relay.rs + channel.rs (CH-RELAY: lease file, Ed25519 hello, X25519 sealing, Lean via dlopen) | Stack 2: pq_mailbox.rs + cohort_tcp.rs (+ async_dispatch, crypto_transit; roster v3, hybrid KEM/ML-DSA); Stack 3: scheduled_transport.rs (PSK fixed cells) | All three by CLI only | README lists one traffic-privacy line (roster enrollment `d7b2f19b` = stack 2). Pick at most one; stack 1 also contradicts the "no pure-X25519" claim |
| `cohort-native-tcp.py` (503) | `native/resource-client/scripts/cohort-native-tcp.py` (185) | The first (cohort-two-host/run-*.sh) | Delete the second |
| `drain.rs` (fn consumer) | `operator_drain.rs` (transport drain) | — | Not twins in function; rename `drain.rs` → e.g. `fn_consumer.rs` |
| Dedup journals: `scheduled_transport::Journal` | `pq_mailbox::claim` (:157-178) and the live admission records (:892-939, 1023-1049), plus cohort `exact`/`adopt` | — | Three immutable-file journals with different file grammars |

---

## 6. Size and shape

### 6.1 Lines per file

| File | Total | Test region | Tests (`#[test]`) | Non-test | Demo-critical? |
| --- | ---: | ---: | ---: | ---: | --- |
| transport.rs | 3,975 | 1,978 (1998-3975, two modules) | 57 | 1,997 | yes |
| relay.rs | 1,500 | 120 | 7 | 1,380 | no |
| channel.rs | 898 | 70 | 4 | 828 | no |
| cohort_tcp.rs | 2,314 | 907 | 22 | 1,407 | no |
| pq_mailbox.rs | 2,074 | 775 (1300-2074) | 16 | 1,299 | no |
| scheduled_transport.rs | 1,245 | 308 | 9 | 937 | no |
| proxy.rs | 300 | 201 | 6 | 99 | yes (shell proxy mode) |
| public_proxy.rs | 808 | 267 | 8 | 541 | platform plan |
| serve_queue.rs | 246 | 83 | 6 | 163 | yes |
| worker.rs | 908 | 122 | 5 | 786 (fn POST ≈ 400; consumer ≈ 386) | POST part via publishers only |
| async_dispatch.rs | 480 | 168 | 3 | 312 | no |
| bounds.rs | 29 | 0 | 0 | 29 | yes |
| fsio.rs | 211 | 47 | 3 | 164 | yes |
| trace.rs | 57 | 11 | 1 | 46 | optional |
| content_privacy.rs | 203 | 49 | 3 | 154 | yes |
| hiding.rs | 648 | 116 | 7 | 532 | yes (read path) |
| drain.rs | 2,136 | 667 (1470-2136) + ~20 of `cfg(test)` helpers | 13 | ~1,450 | no |
| operator_drain.rs | 392 | 76 | 3 | 316 | platform plan |
| **Shard total** | **18,424** | **~5,965** | **173** | **~12,459** | |
| context: hybrid_kem.rs | 471 | — | — | — | yes (private rooms) |
| context: crypto_transit.rs | 380 | — | — | — | no (pq/cohort only) |

Non-Rust shard material:
- docs: TRAFFIC-PRIVACY.md 264, PQ-MAILBOX.md 221, COHORT-TCP.md 223, PUBLIC-INGRESS.md 163;
- `*.txt` 28, `.patch` 8;
- channel-lib 131 (build.sh 42, closure.lean 27, shim.c 40, initbench.c 22);
- cohort-two-host 84;
- scripts/check-*.sh 65 + check-traffic-crypto-alias.sh 14;
- cohort-native-tcp.py 503 + scripts copy 185;
- public-ingress-process.py 247.

### 6.2 A minimal version that keeps only the demo-critical path

**Keep:** transport.rs, serve_queue.rs, proxy.rs, fsio.rs, bounds.rs, trace.rs, hiding.rs, content_privacy.rs, and the fn POST half of worker.rs (moved next to the publishers). Optionally keep public_proxy.rs and operator_drain.rs if the split public/operator topology is in the demo plan.

**Drop (non-demo, CLI-only, no units):**

| Dropped | Lines |
| --- | ---: |
| relay.rs | 1,500 |
| channel.rs | 898 |
| cohort_tcp.rs | 2,314 |
| pq_mailbox.rs | 2,074 |
| scheduled_transport.rs | 1,245 |
| async_dispatch.rs | 480 |
| crypto_transit.rs (only pq/cohort use it; grep shows cohort_tcp.rs and pq_mailbox.rs are its only users) | 380 |
| **Subtotal: traffic-privacy research** | **8,891** |
| drain.rs + consumer half of worker.rs (if fn consumption is not in the demo) | 2,136 + ~480 = ~2,616 |
| public_proxy.rs + operator_drain.rs (if the demo stays monolithic `mini serve`) | 1,200 |
| **Maximum Rust removed** | **~12,707** of 19,275 (66%) |
| Non-Rust drops: channel-lib, cohort-two-host, check scripts, both cohort-native-tcp.py copies, the six txt files, the patch, TRAFFIC-PRIVACY.md, PQ-MAILBOX.md, COHORT-TCP.md | ~1,970 |

The surviving demo core would be about 6,600 lines including tests, about 3,500 without. Within transport.rs a further cut is possible: delete the stale arms, the twin FFI and the v1 envelope (if callers migrate), and unify the deadline I/O with public_proxy.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box (demo path)

- **Binaries:** `mini` and `minidregg-host`, plus the Host's pinned helpers (storage binary and signature verifier, per deploy/grain-host/install-operator-stack:100-107), all hash-pinned.
- **A service user** that owns the Store, a `0700` socket directory (transport.rs:1240), and the files `mini.sock` (0600), `mini.lock`, `mini.config`, `mini.mode`.
- **Linux kernel features:** `memfd_create` with sealing (transport.rs:1368-1393), `/proc/self/fd` exec, `SO_PEERCRED`. Present on any modern kernel. macOS-only paths are irrelevant on the VM.
- **Unit:** `mini serve --host --config --socket` as a `Type=simple` unit with `UMask=0077`, `KillMode=control-group` (deploy/candidate/run.sh:249-271). Readiness is the log line `mini: host process N` (run.sh:187 greps for it; transport.rs:1474). That is a log-scraping readiness protocol.
- **For ssh proxy mode:** a dedicated account whose `authorized_keys` entries use `restrict,command="…/mini-socket-proxy ABS_MINI ABS_PUBLIC_SOCKET"` (deploy/shell/mini-socket-proxy). The proxy account must be able to reach the socket, so it must be the service uid or a member of `--socket-gid` via `serve-public-proxy`.
- **No TCP listener** in this shard is needed for the demo. The research stacks (traffic, mix-live, relay) all open TCP listeners and must stay off the VM.

### 7.2 What the operator configures

- The Host config JSON (≤64 KiB, pinned byte for byte in every envelope; transport.rs:19, 184-186). `fnReplyCatalog` toggles ops 16/18 on the public socket (`catalog_enabled`, :241-246).
- The socket path. The Host path is given as an absolute path; the image hash is computed at start, and v2 clients must present it.
- Keys are not in this shard's runtime path for `serve`. The service holds no signing keys; signatures arrive inside requests.
- For the consumer worker (not in the demo): the wake config, NNTP password file and pinned certificate (worker.rs:187-288).

### 7.3 Dangerous to expose

- **The operator socket (`serve-operator`).** Its union allowlist includes 69 operator-only ops whose only gate is routing (section 3.1). It must never be reachable by a non-owner uid. Do not use `--peer-uid`. Do not loosen the 0700 directory.
- **Any TCP listener from relay, traffic or mix-live.** Strangers can exhaust threads (relay.rs:867-886), burn CPU on ML-KEM keygens (cohort_tcp.rs:731-735), hog the single traffic session (scheduled_transport.rs:846-854), and trigger allocations from wire lengths (relay-witness, relay.rs:1361-1366).
- **`MINI_TRACE`** pointed at a world-readable path would log op numbers and sizes (no payloads; trace.rs:32-33).

### 7.4 What a stranger on the internet can exercise

On the demo topology, nothing in this shard listens on the network: the Host socket is Unix-only, and ssh is the only ingress. A stranger without an authorized ssh key reaches nothing here. With proxy mode enabled, a key-holder is a member, not a stranger.

### 7.5 What a malicious enrolled member can exercise (ssh proxy mode or shell)

- **All 115 public ops** with bodies up to the per-op bounds. This includes:
  - fn poll/ACK 12-15. If the fn service is configured, a member can trigger Host-side fn polling, and possibly ACK confirmed transactions. Q8.2 asks whether the ACK is caller-authorized. If not, a member can pre-ACK and push the operator's consumer worker into `Held` via the "covered" path (drain.rs:921-925).
  - Heavy pure ops: NOCK dry runs (131-137), law-sat (150), author (7, 4 MiB).
  - Op 19 (8 MiB response bound) and op 16 (1.5 MB) when the catalog is enabled.
- **Monopolizing the single Host thread** for up to 600 s per state op, and filling the shared FIFO queue (one uid for all proxy members). Everyone else gets 254 busy (4.2). This is the most practical griefing vector for a small public demo, and it needs no protocol bug.
- **Many idle ssh sessions**, each holding a `mini socket-proxy` process (proxy.rs:38), bounded only by sshd settings.
- **No way to reach operator ops:** `public_envelope` runs on every frame in `socket-proxy` (proxy.rs:69), and `mini serve` (public mode) runs `allowed_operation` itself (transport.rs:1910).

### 7.6 Demo recommendations from this shard (evidence-backed, not prescriptions)

1. Lower `HOST_STATE_OP_BUDGET` or make it per-op, and give public members per-uid accounts (split tenancy) so `serve_queue` fairness actually applies. With one shared uid it does not (serve_queue.rs:10-14).
2. If the split topology is used, give the public relay its own operator-socket connection budget, or a separate fairness peer. Today it can starve lifecycle calls (4.2).
3. Fix `drain.rs:1303-1310` before deploying any consumer worker.
4. Keep relay, traffic and mix-live off the VM, or delete them (6.2).

---

## 8. Questions for the Lean side

Each is phrased so a Lean reader can answer by pointing at a declaration.

1. **Throw after commit.** In `serveFrame` (Host/Main.lean:2616-2666), can any handler reached through `dispatchSession` or `fnDispatch` throw after a durable Store append but before `writeSessionFrame`? If so, the request is answered `255 refused operationRejected` (`RequestRefusal.answer_refused`, Host/RequestRefusal.lean:91-99) although it committed. Which declaration rules this out, or does session invalidation (`state` set to `none`, :2659-2662) cover every post-commit failure?
2. **ACK authorization.** Op 13 `FN_ACK` and op 15 `FN_REPLY_ACK` are routed `public` (protocol/host-operations.json). What in `runFnAckSession` / `runFnReplyAckSession` (dispatch at Host/Main.lean:6697, 6703-6709) authorizes the caller beyond the canonical decimal txn id? Can a public caller ACK a confirmed Mini transaction, or make the operator worker's later exact ACK return `covered-by-durable-frontier`?
3. **Poll purity.** Is op 12 / op 14 poll (`runFnPollSession`, `runFnReplyPollSession`, `runFnReplyCatalogPollSession`) free of durable writes? After a lost poll reply, does a second poll return the same `proposed-fresh` decision and `intentHex`, or a `repeated`/historical decision with an empty intent? drain.rs:1338-1341 holds on the latter.
4. **ACK idempotence.** Is an exact repeat of op 13 for the same txn guaranteed to return `durable-accepted` with unchanged frontiers (the assumption at drain.rs:943-946)? Name the theorem or the code path.
5. **Replay key.** What key does replay detection for op 2 (submit) / op 3 (lookup) use: the full signed call bytes, (signer, nonce), or the intent? Two different signed calls for the same intent (for example after a client re-authors following an uncertain timeout) will both admit unless the key is intent-level. Point to the declaration.
6. **Per-op bounds.** Does Lean bound op bodies per operation beyond `Kernel.Bounds.frameBytesMax`? Rust hard-codes: op 7 ≤ 258 + 4 MiB; op 9 ≤ 16 KiB; 121/181/182 ≤ 4096 (JSON object); 183 ≤ 2048; 184 ≤ 4096 (plan ≤ 3072, sig 64); 30/31 ≤ 256 KiB; 91 source ≤ 4 MiB; 144 ≤ 1024; 187 ≤ 4096; 214/219 ≤ 64 KiB; 16 ≤ 1,516,384; 19 metadata ≤ 4096 / request ≤ 1 MiB / response ≤ 8 MiB; 40/41 ≤ 8192; 43 plan ≤ 8192; 60-63 ≤ 16,384; 64 ≤ 128; 32 ≤ 256 KiB (transport.rs:39-49, 308-618). Should `Kernel.Bounds` emit these, so Rust stops hand-writing them?
7. **Op 8 read-only.** Op 8 `object-audience` / `object-audience-roster` call `sessionWalked` (Host/Main.lean:2050-2054, 2066). Confirm they are read-only, and give a worst-case cost bound. Rust budgets op 8 at 120 s as a "pure" op and kills the Host on overrun (transport.rs:54-68).
8. **Op 0 side effects.** Op 0 describe calls `sessionOpened` (Host/Main.lean:2016). Does opening a session write anything (checkpoint, MAC, journal), or is it read-only?
9. **254 never emitted.** Is there a declaration guaranteeing the Host never emits response operation 254? Rust treats 254 as "never forwarded, certain" (transport.rs:1136-1141, 1166-1173).
10. **Routing-only ops.** For each of the 69 operator-only ops (22-23, 26-27, 32-85 except 28-31, 117-120, 152, 154, 164, 206-209), is there a Lean-side check that refuses an unauthenticated or non-operator caller independently of socket routing? Op 42 ("obtains all selectors from pinned operator settings", transport.rs:554-556), 64, 32/33, 36/37 and 117-120 look as if they rely on routing alone.
11. **Channel assemble.** For `minidregg_channel_assemble` (`Schedule.assembleTagged`, called at relay.rs:1077 with lease records and `holder ‖ cell` arrivals): does it drop cells whose holder is not the lease holder of that slot for the epoch? What does it do with two cells from the same holder in one tick? `serve_member` forwards every cell the member sends (relay.rs:656-664).
12. **Hiding root.** Is `hiding::verify_view`'s root, `ROOT/v2 = cSHAKE256(frame ‖ leaf_1 ‖ … ‖ leaf_n)` with `leaf = cSHAKE256(LEAF/v1, bytesStream(salt) ‖ entry)` (hiding.rs:317-321, 462-480), exactly the `Compiler/StoreCodec.lean` hiding root, including how `frame` is encoded? Which test vector pins the root, as opposed to KMAC and the ratchet only (hiding.rs:538-622)?
13. **Op 153 header.** Does the op 153 decoder (`RetainedSegmentInspection.serveLookup`, Host/Main.lean:6722-6730) require the JSON header `algorithm == "minidregg-carried-call-lookup-v1"` with an `originIdentity` object, a header length of 1..1024 and a raw call ≤ HOST_MAX_FRAME − 1, as Rust filters (transport.rs:290-306)?
14. **Op 17 shapes.** Does the op 17 provider-continuity decoder (`runProviderContinuitySession`, Host/Main.lean:6717-6722) accept exactly the shapes Rust admits (transport.rs:258-287)? Those are: a legacy receipt pair; V2 = reserve pair plus an optional fence pair; V3 = V2 receipts plus a (count, root) pair of canonical naturals ≤ 80 digits with count ≠ 0, and outcome ≤ 1024 bytes. Any mismatch is a Rust false refusal.
15. **"fn-session" phase.** Is the refusal phase `"fn-session"` (hex `666e2d73657373696f6e`) a stable Lean classification meaning the ACK had no effect? drain.rs:1144-1147 uses it to authorize one recovery ACK. Can that be an explicit field in `NativeHostCodec.Outcome` instead?
16. **Ops without call-identity dedup.** Which public ops are not deduplicated by call identity, so that a re-delivery is a second effect? Candidates: 12-15 (fn), 16/18 (origin outbox), 19 (provider usage quote), 131-137 (dry runs), 150. The scheduled-transport and async custody journals can re-deliver if their state directory is lost or replaced (scheduled_transport.rs:352-386; async_dispatch.rs:146-206).

---

## Appendix A. Every registry operation against the two Rust allowlists

Generated from `protocol/host-operations.json` and a hand transcription of `allowed_operation` (transport.rs:308-512) and `allowed_operator_operation` (transport.rs:526-618). The script is `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-B/appendix.py`. "public + operator" means the op is admitted by `allowed_operation`, so it passes on both sockets and through every relay that calls `public_envelope`. "operator only" means only `allowed_operator_operation` admits it. On the operator socket the rule shown is the first matching arm of the union. Ops 130-133 also match stale operator arms (transport.rs:593-597; see section 2.2). Only 24, 25, 191 and 192 have socket "none", and the registry marks them stdio-only or reserved.

| Code | Symbol | Registry routes | Receiver | Rust socket | Rust shape rule | transport.rs line |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | `DESCRIBE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 1 | `AUTHORIZED_PREPARE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 2 | `SUBMIT` | public,operator | fnDispatch (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 3 | `LOOKUP` | public,operator | fnDispatch (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 4 | `OBSERVATION_CHALLENGE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 5 | `AUTHORIZED_QUERY` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 6 | `PROFILE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 7 | `AUTHOR` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 8 | `INSPECT` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 9 | `SIGNATURES` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 10 | `OBSERVATION_ASSEMBLE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 11 | `CALL_ASSEMBLE` | public,operator | dispatchSession (active) | public + operator | any (op 0/6: empty, op 7 <= AUTHOR_BODY_MAX, op 9 <= 16 KiB via operation_body_refusal) | 326, 73-86 |
| 12 | `FN_POLL` | public,operator | fnDispatch (active) | public + operator | empty payload only | 334 |
| 13 | `FN_ACK` | public,operator | fnDispatch (active) | public + operator | canonical decimal 1..80 digits | 335-340 |
| 14 | `FN_REPLY_POLL` | public,operator | fnDispatch (active) | public + operator | empty payload only | 334 |
| 15 | `FN_REPLY_ACK` | public,operator | fnDispatch (active) | public + operator | canonical decimal 1..80 digits | 335-340 |
| 16 | `FN_ORIGIN_OUTBOX` | public,operator | fnDispatch (active) | public + operator | catalog enabled, carrier 1..1,516,384 B | 341 |
| 17 | `PROVIDER_CONTINUITY` | public,operator | fnDispatch (active) | public + operator | provider_continuity_request (legacy/V2/V3 pairs) | 342, 258-287 |
| 18 | `FN_ORIGIN_OUTBOX_EXPORT` | public,operator | fnDispatch (active) | public + operator | catalog enabled, canonical decimal 1..80 | 343-349 |
| 19 | `PROVIDER_USAGE_QUOTE` | public,operator | fnDispatch (active) | public + operator | metadata 1..4096 | request 1..1 MiB | response <= 8 MiB | 350-367 |
| 20 | `SELECTED_RELEASE_SUBMIT` | public,operator | dispatchSession (active) | public + operator | non-empty, < HOST_MAX_FRAME | 368 |
| 21 | `SELECTED_RELEASE_LOOKUP` | public,operator | dispatchSession (active) | public + operator | non-empty, < HOST_MAX_FRAME | 368 |
| 22 | `APPLICATION_LIFECYCLE_BEGIN_SUBMIT` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 23 | `APPLICATION_LIFECYCLE_BEGIN_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 24 | `SELECTED_SOURCE_PUBLISH_SUBMIT` | (stdio only) | dispatchSession (active) | none | not admitted | - |
| 25 | `SELECTED_SOURCE_PUBLISH_LOOKUP` | (stdio only) | dispatchSession (active) | none | not admitted | - |
| 26 | `APPLICATION_LIFECYCLE_CLAIM_SUBMIT` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 27 | `APPLICATION_LIFECYCLE_CLAIM_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 28 | `APPLICATION_SHARE_ISSUE_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 369 |
| 29 | `APPLICATION_SHARE_ISSUE_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 369 |
| 30 | `APPLICATION_CURRENT_BIRTH` | public,operator | fnDispatch (active) | public + operator | JSON object, <= 256 KiB | 370-375 |
| 31 | `APPLICATION_SESSION_CURRENT_BIRTH` | public,operator | fnDispatch (active) | public + operator | JSON object, <= 256 KiB | 370-375 |
| 32 | `APPLICATION_SHARE_ISSUE_PLAN` | operator | fnDispatch (active) | operator only | non-empty, <= 256 KiB | 598 |
| 33 | `APPLICATION_SHARE_ISSUE_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 599-602 |
| 34 | `APPLICATION_DISPATCH_SUBMIT` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 35 | `APPLICATION_DISPATCH_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 36 | `APPLICATION_DISPATCH_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 605 |
| 37 | `APPLICATION_DISPATCH_ASSEMBLE` | operator | dispatchSession (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 606-609 |
| 38 | `APPLICATION_LIFECYCLE_COMPLETION_SUBMIT` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 39 | `APPLICATION_LIFECYCLE_COMPLETION_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 40 | `FN_NAMESPACE_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, <= 8192 B | 542 |
| 41 | `FN_NAMESPACE_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, <= 8192 B | 542 |
| 42 | `FN_NAMESPACE_PLAN` | operator | fnDispatch (active) | operator only | empty only | 556 |
| 43 | `FN_NAMESPACE_ASSEMBLE` | operator | fnDispatch (active) | operator only | plan 1..8192 then exactly 64-byte signature | 559-565 |
| 44 | `APPLICATION_LIFECYCLE_COMPLETION_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 45 | `APPLICATION_LIFECYCLE_COMPLETION_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 46 | `AGENT_PAID_DISPATCH_SUBMIT` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 47 | `AGENT_PAID_DISPATCH_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 48 | `AGENT_PAID_DISPATCH_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 49 | `AGENT_PAID_DISPATCH_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 50 | `APPLICATION_LIFECYCLE_BEGIN_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 51 | `APPLICATION_LIFECYCLE_BEGIN_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 52 | `APPLICATION_LIFECYCLE_CLAIM_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 53 | `APPLICATION_LIFECYCLE_CLAIM_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 54 | `GRAIN_SHARE_ISSUE_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 55 | `GRAIN_SHARE_ISSUE_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 56 | `GRAIN_SHARE_ISSUE_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 57 | `GRAIN_SHARE_ISSUE_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 58 | `AGENT_RESERVE_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 59 | `AGENT_RESERVE_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 60 | `FN_SELECTED_COVERAGE_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, <= 16,384 B | 545 |
| 61 | `FN_SELECTED_COVERAGE_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, <= 16,384 B | 545 |
| 62 | `FN_EMPTY_PROGRESS_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, <= 16,384 B | 545 |
| 63 | `FN_EMPTY_PROGRESS_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, <= 16,384 B | 545 |
| 64 | `FN_FRONTIER_PLAN` | operator | fnDispatch (active) | operator only | non-empty, <= 128 B | 548 |
| 65 | `FN_FRONTIER_ASSEMBLE` | operator | fnDispatch (active) | operator only | plan_len > 0, then exactly 64-byte signature | 550-553 |
| 66 | `APPLICATION_LAUNCH_BEGIN_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 67 | `APPLICATION_LAUNCH_BEGIN_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 68 | `APPLICATION_LAUNCH_CLAIM_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 69 | `APPLICATION_LAUNCH_CLAIM_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 70 | `APPLICATION_LAUNCH_COMPLETION_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 71 | `APPLICATION_LAUNCH_COMPLETION_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 72 | `AGENT_LIFETIME_GRANT_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 73 | `AGENT_LIFETIME_GRANT_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 74 | `AGENT_LIFETIME_GRANT_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 75 | `AGENT_LIFETIME_GRANT_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 76 | `AGENT_LIFETIME_DISPATCH_SUBMIT` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 77 | `AGENT_LIFETIME_DISPATCH_LOOKUP` | operator | dispatchSession (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 78 | `AGENT_LIFETIME_DISPATCH_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 79 | `AGENT_LIFETIME_DISPATCH_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 80 | `AGENT_LIFETIME_RESERVE_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 81 | `AGENT_LIFETIME_RESERVE_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 82 | `APPLICATION_SESSION_ENROLLMENT_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 83 | `APPLICATION_SESSION_ENROLLMENT_ASSEMBLE` | operator | fnDispatch (active) | operator only | u32 plan_len, 0 < plan_len < len-4 | 610-615 |
| 84 | `APPLICATION_SESSION_ENROLLMENT_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 85 | `APPLICATION_SESSION_ENROLLMENT_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 86 | `PARTICIPANT_KEY_ENROLLMENT_PLAN` | public,operator | fnDispatch (active) | public + operator | exact_pair | 387 |
| 87 | `PARTICIPANT_KEY_ENROLLMENT_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, exact_pair(sponsor 64, rest 64|160)) | 388-394 |
| 88 | `PARTICIPANT_KEY_ENROLLMENT_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 395 |
| 89 | `PARTICIPANT_KEY_ENROLLMENT_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 395 |
| 91 | `CURRENT_RESOURCE_BIRTH` | public,operator | fnDispatch (active) | public + operator | exact_pair(observation, JSON-object source <= 4 MiB) | 378-386 |
| 92 | `PARTICIPANT_PROVISIONING_PLAN` | public,operator | fnDispatch (active) | public + operator | exact_pair | 398 |
| 93 | `PARTICIPANT_PROVISIONING_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 399-400 |
| 94 | `PARTICIPANT_PROVISIONING_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 401 |
| 95 | `PARTICIPANT_PROVISIONING_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 401 |
| 96 | `FLEET_TURN_PLAN` | public,operator | fnDispatch (active) | public + operator | exact_pair | 406 |
| 97 | `FLEET_TURN_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 407-409 |
| 98 | `FLEET_TURN_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 410 |
| 99 | `FLEET_TURN_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 410 |
| 100 | `FLEET_TOPIC_POLL` | public,operator | fnDispatch (active) | public + operator | exact_pair | 406 |
| 101 | `FLEET_HEAD` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 410 |
| 102 | `FLEET_RECEIPT` | public,operator | fnDispatch (active) | public + operator | canonical decimal 1..80 | 454-459 |
| 103 | `PAY_COMMAND_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 470 |
| 104 | `PAY_COMMAND_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 471-473 |
| 105 | `PAY_COMMAND_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 474-476 |
| 106 | `PAY_COMMAND_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 474-476 |
| 107 | `PAY_VIEW` | public,operator | fnDispatch (active) | public + operator | empty only | 477 |
| 108 | `PAY_OBSERVATION_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 470 |
| 109 | `PAY_OBSERVATION_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 471-473 |
| 110 | `PAY_OBSERVATION_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 474-476 |
| 111 | `PAY_OBSERVATION_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 474-476 |
| 112 | `PAY_ENROLLMENT_VIEW` | public,operator | fnDispatch (active) | public + operator | empty only | 477 |
| 113 | `PAY_REFILL_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 479 |
| 114 | `PAY_REFILL_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 480-482 |
| 115 | `PAY_REFILL_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 479 |
| 116 | `PAY_REFILL_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 479 |
| 117 | `PAY_SELF_ENROLLMENT_PLAN` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 585 |
| 118 | `PAY_SELF_ENROLLMENT_ASSEMBLE` | operator | fnDispatch (active) | operator only | exact_pair(plan, sig 64) | 586-587 |
| 119 | `PAY_SELF_ENROLLMENT_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 585 |
| 120 | `PAY_SELF_ENROLLMENT_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 585 |
| 121 | `PAY_ENROLLMENT_QUOTE` | public,operator | fnDispatch (active) | public + operator | non-empty JSON object, <= 4096 B | 315-316 |
| 123 | `REALM_WELL_PLAN` | public,operator | fnDispatch (active) | public + operator | at least one payload byte, frame-bounded | 328 |
| 124 | `REALM_WELL_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | at least one payload byte, frame-bounded | 328 |
| 125 | `REALM_WELL_SUBMIT` | public,operator | fnDispatch (active) | public + operator | at least one payload byte, frame-bounded | 328 |
| 126 | `CLOCK_TICK_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 461 |
| 127 | `CLOCK_TICK_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 462-463 |
| 128 | `CLOCK_TICK_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 461 |
| 129 | `CLOCK_VIEW` | public,operator | fnDispatch (active) | public + operator | empty only | 464 |
| 130 | `AFFORDANCE_DRY_RUN` | public,operator | dispatchSession (active) | public + operator | exact_pair | 413 |
| 131 | `NOCK_PROGRAM_CHECK` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 132 | `NOCK_PROGRAM_SHOW` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 133 | `NOCK_SAMPLE` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 134 | `NOCK_DRY_RUN` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 135 | `NOCK_APP_POKE_DRY_RUN` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 136 | `NOCK_APP_PEEK` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 137 | `NOCK_APP_STATE` | public,operator | fnDispatch (active) | public + operator | any, frame-bounded | 333 |
| 140 | `KEY_ROTATION_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 436 |
| 141 | `KEY_ROTATION_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 437-439 |
| 142 | `KEY_ROTATION_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 436 |
| 143 | `KEY_ROTATION_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 436 |
| 144 | `KEY_ROTATION_STATUS` | public,operator | fnDispatch (active) | public + operator | JSON object <= 1024 B | 448-453 |
| 150 | `LAW_SAT` | public,operator | dispatchSession (active) | public + operator | non-empty, < HOST_MAX_FRAME | 432 |
| 151 | `RECEIPT_CONTINUITY` | public,operator | fnDispatch (active) | public + operator | continuity_request: JSON object 1..64 KiB | 324, 250-253 |
| 152 | `APPLICATION_STREAM_RENEW` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 536 |
| 153 | `CARRY_RECEIPT_LOOKUP` | public,operator | fnDispatch (active) | public + operator | carried_lookup_request: JSON header 1..1024 (algorithm, originIdentity) + raw call | 325, 290-306 |
| 154 | `APPLICATION_ROUTE_INSPECT` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 536 |
| 160 | `JOB_MONEY_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 485 |
| 161 | `JOB_MONEY_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 486-488 |
| 162 | `JOB_MONEY_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 485 |
| 163 | `JOB_MONEY_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 485 |
| 164 | `APPLICATION_ROUTE_BOUND_DISPATCH` | operator | serveFrame (active) | operator only | non-empty, < HOST_MAX_FRAME | 538-541 |
| 170 | `CERTIFY_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 490 |
| 171 | `CERTIFY_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 491-492 |
| 172 | `CERTIFY_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 490 |
| 173 | `CERTIFY_VIEW` | public,operator | fnDispatch (active) | public + operator | empty only | 493 |
| 180 | `FLEET_INCOMING_LEDGER` | public,operator | fnDispatch (active) | public + operator | exact_pair | 406 |
| 181 | `PAY_CLAIM_VIEW` | public,operator | fnDispatch (active) | public + operator | non-empty JSON object, <= 4096 B | 315-316 |
| 182 | `PAY_CLAIM_QUOTE` | public,operator | fnDispatch (active) | public + operator | non-empty JSON object, <= 4096 B | 315-316 |
| 183 | `PAY_CLAIM_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, <= 2048 B | 319 |
| 184 | `PAY_CLAIM_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan 1..3072, sig 64), <= 4096 B | 320-322 |
| 185 | `PAY_CLAIM_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, <= 4096 B | 323 |
| 186 | `PAY_CLAIM_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, <= 4096 B | 323 |
| 187 | `NEXT_KEY_ADOPTION_PLAN` | public,operator | fnDispatch (active) | public + operator | JSON object <= 4096 B | 442-443 |
| 188 | `NEXT_KEY_ADOPTION_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, exact_pair(current 64, next 64)) | 444-446 |
| 189 | `NEXT_KEY_ADOPTION_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 447 |
| 190 | `NEXT_KEY_ADOPTION_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 447 |
| 191 | `CARRY_PAY_CLAIM_LOOKUP` | public,operator | - (reserved) | none | not admitted | - |
| 192 | `LAW_DIAGNOSTIC` | public,operator | - (reserved) | none | not admitted | - |
| 193 | `APPLICATION_DISPATCH_READY` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan non-empty, signatures non-empty) | 416-417 |
| 194 | `APPLICATION_DISPATCH_AUTHENTICATED_PLAN` | public,operator | fnDispatch (active) | public + operator | exact_pair(request, exact_pair(sig 64, five reads)) | 420-430 |
| 201 | `RESERVE_RESOURCE_BIRTH_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 312 |
| 202 | `RESERVE_RESOURCE_BIRTH_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 312 |
| 206 | `APPLICATION_FAILED_START_RECOVERY_PREPARE` | operator | fnDispatch (active) | operator only | exact_pair, < HOST_MAX_FRAME | 531 |
| 207 | `APPLICATION_FAILED_START_RECOVERY_ASSEMBLE` | operator | fnDispatch (active) | operator only | exact_pair, < HOST_MAX_FRAME | 531 |
| 208 | `APPLICATION_FAILED_START_RECOVERY_SUBMIT` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 532 |
| 209 | `APPLICATION_FAILED_START_RECOVERY_LOOKUP` | operator | fnDispatch (active) | operator only | non-empty, < HOST_MAX_FRAME | 532 |
| 210 | `ACTIVITY_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 497 |
| 211 | `ACTIVITY_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 498-499 |
| 212 | `ACTIVITY_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 497 |
| 213 | `ACTIVITY_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 497 |
| 214 | `ACTIVITY_VIEW` | public,operator | fnDispatch (active) | public + operator | empty or JSON object <= 64 KiB | 500-501 |
| 215 | `SEAT_PLAN` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 505 |
| 216 | `SEAT_ASSEMBLE` | public,operator | fnDispatch (active) | public + operator | exact_pair(plan, sig 64) | 506-507 |
| 217 | `SEAT_SUBMIT` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 505 |
| 218 | `SEAT_LOOKUP` | public,operator | fnDispatch (active) | public + operator | non-empty, < HOST_MAX_FRAME | 505 |
| 219 | `SEAT_VIEW` | public,operator | fnDispatch (active) | public + operator | empty or JSON object <= 64 KiB | 508-509 |

## Appendix B. Lost-reply matrix: every failure point on the demo wire

| # | Failure point | What the client sees | Certain? | Could the request have executed? | Who decides the next step | Code |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | Client cannot connect | `cannot connect to …` | certain (nothing sent) | no | caller | transport.rs:1155-1156 |
| 2 | Client write fails; service had already refused (busy) | `socket rejected request: busy …` (the 254 read within 1 s) | certain | no | caller | transport.rs:1160-1172 |
| 3 | Client write fails, no 254 readable | `uncertain host request write` | uncertain | possible only if the whole envelope was delivered | caller → `mini retry --mode lookup` | transport.rs:1174 |
| 4 | Envelope invalid, pins mismatch, or op not allowed | `socket rejected request: <reason>` | certain | no | caller | transport.rs:1882-1913 |
| 5 | Queue full or displaced | `busy: host queue full` / `busy: host queue share displaced` | certain | no | caller | transport.rs:1926, 1612-1627 |
| 6 | Queued longer than 60 s | `busy: queue residence deadline` | certain | no (judged immediately before the Host write) | caller | transport.rs:1570-1578, 1773-1776 |
| 7 | Caller hung up while queued | (caller gone) | — | no | — | transport.rs:1571-1572, 1583-1608 |
| 8 | Host write stalls more than 30 s or the Host dies mid-request | EOF: `uncertain host response: connection closed` | uncertain | possible | caller → lookup; the service restarts the Host | transport.rs:1495-1509, 1787-1796 |
| 9 | Host reply exceeds 120/600 s | EOF (as 8) | uncertain | possible (pure ops 0/6-11: no write, but op 8 may walk the Store) | caller | transport.rs:53-68, 1504-1508 |
| 10 | Host reply larger than HOST_MAX_FRAME | EOF (as 8) | uncertain | possible | caller | transport.rs:1510-1512 |
| 11 | Service fails to write the reply to the client | read error or EOF: `uncertain host response read` | uncertain | yes (the Host answered) | caller | transport.rs:1931-1934 |
| 12 | Host handler throws before replying | `255` refused operationRejected | Lean says definitive | Q8.1 (after commit?) | Lean outcome; drain holds | Host/Main.lean:2652-2663 |
| 13 | ssh proxy: frame refused by the proxy filter | `254 proxy: <reason>`, session closed | certain | no | caller | proxy.rs:43-48 |
| 14 | ssh proxy: upstream exchange fails | the ssh session ends; client `Failure::Uncertain` | uncertain | possible | caller | proxy.rs:49, 91-98 |
| 15 | public relay: failure before upstream write | `254 public ingress upstream unavailable` (or other reason) | certain | no | caller | public_proxy.rs:325-360 |
| 16 | public relay: failure after the upstream write starts | connection closed, no frame | uncertain | possible | caller | public_proxy.rs:361-390 |
| 17 | traffic facade: local queue full after persisting | connection closed (the error text is never sent) | uncertain | **later, after a restart** (recover_local) | nobody: the orphan dispatch happens automatically | scheduled_transport.rs:667-678, 702-737 |
| 18 | traffic backend reply larger than max_body | facade closes (kind 1) | uncertain | yes | caller → lookup | scheduled_transport.rs:473-475 |
| 19 | drain: submit uncertain | phase stays `Sending`; the next wake looks up; absent → resubmit the exact bytes | — | Lean dedups the exact bytes | Lean lookup outcome | drain.rs:1376-1395, 1407-1439 |
| 20 | drain: ACK uncertain | one exact retry, fenced; then Held | — | Lean op 13 idempotence (Q8.4) | Rust policy plus operator | drain.rs:912-981 |

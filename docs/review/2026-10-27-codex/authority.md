# Authority boundary review — 27 October

Reviewed commit `54feb532e05039054640fef04b417e62110e4341` in an isolated worktree. These are source-derived traces, not live exploit demonstrations. No servers or builds were started. Current work on the lifetime-grant repair is outside this review.

## P1: publication hand-off can copy an unchecked root-readable file to the public member

`native/mini-web-spawn/src/main.rs:328–359` runs in the root helper. A hosted member controls their `workspace/proposals` tree. The collector checks the reference path with `symlink_metadata`, reads and validates a JSON reference naming the public subject, then opens the same pathname a second time and copies those new bytes to a file owned by the public member. Between the validated read and the second read, the member can replace the file with a symlink to a root-readable file. The second read follows it, and those bytes are copied into the public member's inbox. Parent path components also follow symlinks. This is a root-to-lower-privilege file-copy boundary failure; its scheduling was not measured in the live helper. Public `import_inbox` (`native/resource-client/src/web/body.rs:516–550`) parses a capability before import, and `workspace.rs:824–840` requires an addressed, confirmed reference. Arbitrary copied bytes may not pass those checks. No remote website retrieval or exfiltration is established.

Open the member-owned tree through checked directory descriptors without following links, open the reference once with `O_NOFOLLOW`, check its ownership/type/size, and parse and copy the same bounded captured bytes. Create the destination with protected directory descriptors and exclusive temporary files; do not follow public-member-controlled links.

## P1: an already-open terminal is not fenced at browser session revocation

`native/mini-web/src/main.rs:251–253,328–380` checks the session at WebSocket upgrade and then forwards terminal frames without another check. On a successful revoke, `Terminals::end` removes the registry entry and sends SIGHUP (`native/mini-web/src/term.rs:135–143`), but the already-upgraded handler and pump hold `Arc<Terminal>` references and retain the pty. If the shell or its surviving process ignores SIGHUP, that connection can continue sending commands after its session has been revoked. The helper separately sends SIGHUP to its recorded PID (`native/mini-web-spawn/src/main.rs:276–283`); this is not an acknowledgement that the whole terminal has stopped. Session expiry is checked at the next request and the helper's periodic sweep, not on each existing WebSocket frame.

Fence the terminal and its active socket under a shared revocation state before reporting success; close the actual pty and connection, stop the exact owned process unit, and handle expiration through the same boundary. Test a connected terminal with a SIGHUP-resistant process and assert that neither input nor output crosses after revoke completes.

## P1/P2: a failed session-record deletion is reported as a successful revoke

`native/mini-web-spawn/src/store.rs:167–169` discards the `remove_file` result. `native/mini-web-spawn/src/main.rs:212–230,276–286` then returns success for logout and revocation. A persistent read-only directory would already make the initial `touch` fail, so it does not demonstrate this path. If the initial touch succeeds but the subsequent unlink fails (an unlink-specific or transient error), `end` reports success with the record still present; once storage permits writes again, `touch` (`store.rs:136–144`) accepts a copied cookie, including for a new shell. The UI redirects as though revocation succeeded. This is a source-confirmed failure branch, not an induced filesystem failure.

Make deletion or a durable revocation marker a checked, crash-durable operation; propagate failure or uncertainty rather than reporting completion. Fence existing terminals as part of the same operation.

## P2: persisted process IDs can signal an unrelated process after helper restart

On startup `native/mini-web-spawn/src/main.rs:237–253` clears body records but keeps persisted shell PIDs. The helper's current child set starts empty (`:90–93`). A shell can exit while the helper is down; if the OS reuses its PID, a later revoke or expiry calls `kill` on the stored integer as root (`:276–283`), without checking the process identity. That may signal a different process. Similarly, gateway `Terminals::close/end` sends a retained PID even after process exit. This is a source-derived restart/reuse trace, not a PID-reuse experiment.

Track the exact unit and process birth identity, or retain an OS process handle; stop only verified owned units and treat stale records as stale, never as authority to signal an arbitrary PID.

## Scope and unresolved leads

Inspected `native/mini-web/{src/main.rs,src/session.rs,src/term.rs}`, `native/mini-web-spawn/{src/main.rs,src/store.rs,src/spawn.rs}`, `native/resource-client/src/{shell.rs,web_admission.rs,workspace/web_author.rs}`, and the capability-revocation/credential Lean controller and receiver references. The browser-session failures above sit outside the Lean capability-revocation receiver: no claim is made that they bypass its current grant checks. I did not complete an end-to-end signed shell/HTTP receiver or retry-after-capability-revocation trace, so this review does not certify those paths. Existing review material was checked for context; the findings above are stated against the pinned source, not inferred from older review reports.

## Follow-up reproduction and current-main check

As of the follow-up, main was `65ed4da9609292b18ac142a408f7ca5562640a6f`; the reviewed collector, session store and terminal files had no later commits. Disposable-file probes reproduced the collector's two filesystem operations: replacing a checked regular JSON reference with a symlink before the second read returned a test-private marker, and a pre-existing `doc.42.tmp` symlink was followed by create/truncate/write, changing its target before the symlink was renamed into the inbox. In the actual collector the latter open occurs as root and the subsequent `fchown` affects the opened target; reaching this write requires control of the public member's inbox. These are deterministic filesystem probes, not live collector or privilege-boundary tests. Use an exclusive non-following temporary file in an owned directory and publish via directory-relative operations.

A separate disposable-pty probe started one child that ignored SIGHUP, signalled only that recorded child, then wrote a line to the still-open master; the child returned `EXECUTED:run-after-revoke`. This confirms the OS behavior supporting the terminal trace, not the complete live session revocation path. The child was reaped. The unlink-specific failure remains source-inferred; no injected failure was run.

The reproducible disposable OS probes are [repro-primitives.py](repro-primitives.py). Run `python3 -B docs/review/2026-10-27-codex/repro-primitives.py`; the measured markers were `source_swap: TEST-PRIVATE-CONTENT`, `destination_symlink_target: REFERENCE`, `renamed_destination_is_symlink: True`, and `EXECUTED:run-after-revoke`. These prove the underlying filesystem and pty operations, not scheduling, privilege change or a live network exploit. Destination overwrite requires control of the public UID or its inbox; a regular hosted member's ability to replace their own source reference is a separate prerequisite.

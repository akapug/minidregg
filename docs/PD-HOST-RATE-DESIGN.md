# Per-subject request rate in the Host: statement and integration plan (2026-10-27)

The "better" fix for gap 2 of dregg-infra `edge/demo/ABUSE-LIMITS.md` (a thousand `can` dry-runs or
reads from one member queue every other member's reads at the shared Store). The law is stated
and proved in `Kernel/SubjectRate.lean`. This document is the integration plan, and it waits on
two decisions before any Host code changes (§3).

## 1. The law, as stated

`check` (read-only, on the subject the request **claims**, before Store work) and `charge`
(after the receiver **verified** the signature for that subject). The proved poles:

| pole | theorem |
|---|---|
| satisfiable: first `limit` requests in a window admitted | `check_fresh`, `check_below_limit`, `witness_run` |
| teeth: the next one inside the window refused with the time left, `> 0` | `check_at_limit`, `limit_charges_refuse`, `witness_run` |
| after the window admitted, window restarts | `check_after_window`, `charge_after_window` |
| the refusal's retry promise holds | `check_retry_admits` |
| non-interference; a forgery cannot fill a victim's window | `charge_other`, `check_forgery_free` |
| operator subjects exempt (decided: by verified subject; the Host does not know the listener) | `check_exempt`, `charge_exempt` |

Planted fault, run on the Mac against the core-only copy: `s.count < p.limit` → `≤` in `check`
turns `check_at_limit`, `check_retry_admits` and `witness_run` red (`decide` proves the run's
proposition false).

**Time, not height.** The window runs on the Host's monotonic milliseconds and the refusal names
the milliseconds until it reopens. The brief asked for "the height it may retry"; a height window
never reopens for a reader in a quiet world, because reads and dry-runs do not move the height.

## 2. Why the Host and not `mini serve`

`mini serve` feeds one Host process (`transport.rs` `serve_host_observed`). It is fair per kernel
peer uid (`serve_queue.rs`). Public members can arrive through the public ingress relay as one
uid, so a peer is not a member. Only the Host knows the subject, and only after it verifies the
signature. Hence the law's claim-checked, verify-charged shape.

## 3. Decisions needed before integration (the STOP)

1. **The refusal's name on the wire.** A by-name refusal is a new `Compiler.RefusalReason`
   constructor, `rateLimited`, at tag 16, with name `rate-limited`. That moves the outcome frame
   from v6 to v7, and `NativeHostCodec.v6_outcome_refused` follows the v5 precedent. The persisted
   codec census row moves too, which moves the derived StoreEpoch. So it is a **re-genesis**, and it
   rides the flag-day cut. The exhaustive sites are those of the `overBound` precedent
   (`1a8712528`): `Compiler/RefusalReason.lean` (`name`, `describe`, `all`, `stream`, and
   `stream_unknown_tag` → 17), `Compiler/NativeHostCodec.lean`, `Compiler/NativeProtocolFrames`,
   the `PersistedCodecTags` census row, the frame spellings in `native/spk-host/src/*.rs`,
   `journey-stranger.py`, `journey.sh` (hex), `journey.d/j12x.sh` and `jserve.sh`, and
   `native/grain-runtime/src/provider.rs:958` (the reason map).
   `native/resource-client/src/replan.rs:503` is the never-retry list. `rate-limited` must stay
   **off** that list: the client waits `retryAfterMs` and offers the retry.
   The no-wire alternative is `Outcome.unavailable "rate-limited retry-after-ms N"` under NO_RECORD.
   It needs no epoch move, but it is prose, not a name, and it would be an interim twin of the
   constructor. It is not recommended.
2. **Defaults** (ASSUMED until `jtour` counts signed frames per verb): `limit` 300 signed requests,
   `windowMs` 60000, per subject. That is 5 a second sustained, above the measured ~1 write a
   second per client stream. The exempt set is the genesis operator subject and the sponsor. All
   three are `NativeHost.Config` fields read from genesis-params, so they are published on the laws
   page with the rest of the configuration.

## 4. Integration file list (for the closure build slot, once §3 is decided)

- `Kernel/SubjectRate.lean`: the law (this lane; imported from `Kernel.lean`).
- `Kernel/NativeHost.lean` `Config`: `rate : SubjectRate.Policy`, `rateExempt : List Nat`, and
  their genesis-params parse.
- `Host/Main.lean`: one `IO.Ref SubjectRate.Table` beside the session `state`. `serveFrame` calls
  `check` on the claimed subject of a **signed** operation before dispatch. A limited request is
  answered `refused rateLimited (op N) "retry-after-ms R"` under NO_RECORD, with no Store work.
  After dispatch, the receiver's verified subject is charged.
- The claimed and verified subject per signed operation family. These are the read-flood families
  first: op 1 prepare (`NativeHost.prepareAuthorizedLoaded`), op 5 query
  (`NativeObservationOpeningCache.queryWireLoaded` and each batch member), and op 130 dry-run
  (`Host/DryRun`). Then the submits: op 2 through `fnDispatch`, and ops 46, 76 and 26. Each arm
  returns the subject it verified. A batch charges once per member observation.
- Unsigned operations are **not** rated, stated: 0 describe, 4 challenge, 6 profile, 7–11 pure
  codec and 150 law-sat. They are Store-free or cache-only and bounded by the transport's
  per-operation body bounds. The law cannot charge them, because nothing verifies a subject there.
- `Host/RequestRefusal.lean`: `rateLimited retryAfterMs` as a third `IO.Error` marker beside
  `malformed` and `overBound`, with `answer_rateLimited`.
- Client rendering: `native/resource-client/src/replan.rs` (retryable after the wait) and the
  shell and web refusal renderers. "Rate limited: retry in N s" is rendered from the reason and
  the detail number.
- The test that can go red: one journey-row step that sends `limit + 1` signed queries inside a
  window as one subject and expects `rate-limited` on the last. It also checks that a second
  subject is admitted at the same moment. A Lean `#guard`/`decide` already pins the pure run.

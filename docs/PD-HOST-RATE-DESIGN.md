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

## 3. Decided (coordinator, 2026-10-27) and built

- **The name:** `Compiler.RefusalReason.rateLimited`, tag 16, name `rate-limited`. The outcome
  frame is now v7 (`NativeHostCodec.v6_outcome_refused`), spelled v7 at every site of the
  `overBound` precedent. The StoreEpoch moves, so this is a re-genesis (accepted: flag days are not
  held).
- **Defaults:** `SubjectRate.hostDefault` is 300 signed requests per subject per 60 s. It applies
  when the Host config carries no `requestRate`. The operator's own subject and the sponsor's are
  exempt by verified subject. They are named in the Host config
  `"requestRate": {"limit": 300, "windowMs": 60000, "exempt": [OPERATOR, SPONSOR]}`, which the
  deployment writes (infra). Absent, no subject is exempt.

## 4. What is built (lane/pd-host-rate)

- `Kernel/SubjectRate.lean`: the law, `hostDefault`, `Policy.make` (a zero limit or window
  refuses the config), and `exemptOf`.
- `Compiler/RefusalReason.lean`: `rateLimited` (doc names its disclosure: it is told on the
  claimed subject before verification, so it reveals only that the claimed subject's window is
  full).
- `Host/RequestRefusal.lean`:
  - `rateLimitedAnswer` / `rateLimitedFrame` (`rateLimitedFrame_decodes`; `rateLimitedAnswer_noRecord`:
    a no-record refusal).
  - `preVerification` and `chargeable` (`chargeable_badSignature`: a forgery charges nobody;
    `chargeable_lawDenied`: a verified holder refused by the law is charged).
- `Host/Main.lean`:
  - `RequestRateSettings` and `Settings.requestRate`.
  - `RateGate`, created once per Host process by `Settings.rateGate`.
  - `ratedClaims`: the claimed subjects of ops 1, 5 (each batch member) and 130, from the signed
    observation's intent.
  - In `serveFrame`, `RateGate.check` runs before dispatch. A full window is answered
    `rateLimitedFrame` under NO_RECORD with no receiver or Store work. `RateGate.charge` runs after
    the reply. It charges every member on the operation's own reply, and only the first member on
    a post-verification refusal (a batch stops at its first refusal; every member before it
    verified).
- `Host/ClientConsentCore.lean`, `Host/SourceAgreementReader.lean`: the strict config readers
  admit the `requestRate` key.
- Client:
  - `native/resource-client/src/main.rs` `refusal_line` renders "refused: rate-limited: this
    subject has used its request rate for now; retry in N s".
  - `replan.rs` never re-plans it automatically: the member retries. `grain-runtime` `provider.rs`
    maps the name.

**Not rated, stated:**
- The unsigned operations: 0, 4, 6, 7–11 and 150.
- The submit families: 2 through `fnDispatch`, and 46, 76 and 26. Their receivers verify inside
  the fn and application dispatchers, which return no subject to `serveFrame`. Rating them is the
  next step: each dispatcher returns the subject it verified.
- Writes are paid from the member's funding. A refused write is free and is the remaining flood
  shape there.

**Owed:**
- `scripts/codec-shapes-regen.py` must re-emit `Compiler/PersistedCodecShapes.lean` for the v7
  frame. The fingerprint needs the census build, a closure.
- A journey row: a world with `requestRate.limit` 3 sends 4 signed queries as one subject. It
  expects `rate-limited` on the 4th, and a second subject admitted at the same moment.
- The laws page publishing the rate. It lives in Settings, not in `NativeHost.Config`, so op 0's
  description does not carry it yet.

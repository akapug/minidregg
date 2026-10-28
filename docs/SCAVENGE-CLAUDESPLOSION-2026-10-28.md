# Scavenge of claudesplosion, 2026-10-28

`~/dev/claudesplosion` holds about 93,000 lines of unreviewed model synthesis written between
2026-09-29 and 2026-10-03. It contains surveys of ember's repositories, designs under
`planning/`, lane reports under `product/` and `planning/*/`, and PR drafts for breadstuffs.
Every file was triaged against `origin/main` at 6bc302387. Raw scraped specs
(`planning/prove/raw-*`) were not read.

Most of it is history. The designs that mattered (PAY, CHANNELS, PRIVACY, PLACE, DATAMODEL,
COMPUTE, NOCK, EVAL, SURPASS, MUD, docuverse) were built in the month since, and the lane reports
describe work that has landed. The `prs/` and `fixes/` material concerns breadstuffs. What is
left is listed below.

"Verified" means the defect or gap was confirmed in the current tree at the cited line.
"Unverified" items stay pointers; nothing from claudesplosion enters these docs as authority
until it is checked.

## Brought in

- `docs/PAY.md`: the payment rail and self-enrollment as shipped, with the Lean modules as the
  authority. It keeps the section numbers the code cites. 82 `PAY §N` comments in 40 files now
  cite `docs/PAY.md §N`. Commit 256c2e9d5.

## Ranked findings

1. **About 230 code comments still cite outside design docs.** Verified by count. The
   comment-only fix is the same as PAY's: a present-state doc per design, or a rewritten
   comment.

   | doc | lines | files |
   |---|---|---|
   | PLACE | 45 | 37 |
   | MUD | 40 | 30 |
   | DATAMODEL | 26 | 16 |
   | COMPUTE | 25 | 15 |
   | CHANNELS | 21 | 9 |
   | NOCK | 21 | 11 |
   | EVAL | 18 | 9 |
   | PRIVACY | 15 | 11 |
   | DEOS | 9 | 7 |
   | SURPASS | 6 | 5 |
   | SPK-HOSTING | 2 | 2 |

   Found by `grep -E '\bNAME(\.md)? ?(§|row|item)'` outside `docs/`. `AUDIT-ROOMS`, cited in
   `native/resource-client/src/chat.rs:1913`, `main.rs:483` and `workspace.rs:2846` and `:6445`,
   is the same problem. The `docs/ZK.md` adaptation is the precedent. Owner: a docs lane,
   CHANNELS and PRIVACY first, since their designs are the most fully realized
   (`Theory/Channel/*`, `Kernel/DomainEpoch*`, `native/resource-client/src/{roomkey,private}.rs`).

2. **The enrollment receiving key is on the demo box.** Verified, security. In
   `deploy/door/infra/mini-enrol-keygen`, the Solana spending key for the published enrollment
   address lives at `/var/lib/mini-core/secret/enrol.key` (mini-core 0600). The design kept every
   receiving key offline and put no Solana key on the box. Anyone with root or `mini-core` on
   `dregg-demo` can move what strangers pay, and nothing sweeps the address. Mainnet
   pay-to-enrol is in the opening contract (`docs/DEMO-PREFIX-2026-10-26.md` §1). This needs a
   sweep policy or an offline key before money flows (`docs/PAY.md` §4). Owner: ember decides;
   qualification lead.

3. **SPK package signature uses non-strict ed25519.** Verified, security hygiene.
   `native/spk-package-stream/src/lib.rs:329-332` calls `VerifyingKey::verify`, which accepts
   small-order keys. `spk-host/src/grain_export.rs:141` and `mini-keys/src/server/member.rs:74`
   already use `verify_strict`. Fix: `verify_strict` plus `is_weak()` refusal. Owner: app-market
   or SPK lane. Source: `20-hosting-confinement.md` F7, `99-SYNTHESIS.md`.

4. **The frame bound is hand-copied in 39 files.** Verified. `Kernel/Bounds.lean:76`
   `frameBytesMax := 12102760` is repeated as a literal in Rust, Python and scripts, for example
   `native/mini-sdk/src/operator.rs:50` and `native/spk-host/src/dispatch_native.rs:23`. Generate
   one Rust constant from Lean the way `scripts/host-operations.py` generates op bytes, and gate
   the literal. Owner: perf-rake / one-wire. Source: `planning/surpass/a3-twin-census.md` §2.

5. **The `MultiCellHyperedge` joint apex is an identity carrier.** Verified, statement gap.
   `Kernel/MultiCellHyperedge.lean:556` and `:577` set `jointApex := declaration.header.apex`,
   and `agree` is `rfl` at `:592-594`. So `Hyperedge.legs_agree` says nothing about deployed
   turns. This needs a statement with teeth or a retraction note. Owner: Lean lane, adversarial
   statement audit. Source: `mini-1-kernel.md` F5.

6. **K-BOOK-SLOTS: payment and the write it buys are not one transaction.** Verified absent in
   Lean. It is named as future only in `native/resource-client/templates/hermes/README.md:68-69`
   and `templates/mud/sheet/README.md:46`. `native/grain-runtime/src/concierge.rs` grants windows
   from its own journal. This is the helm-substrate gap: a receipted post whose payment is in
   law. Owner: L4d (Hermes). Source: `product/p-credit.md:203,342`.

7. **Delete the durable twin to shrink the Lean closure.** Unverified by me; the reader checked
   the imports. `Kernel/DurableCommitProtocol`, `DurableReceiver`, `DurableWalHandler`,
   `FramedWalRefinement` and `GuardedDurableCommit` (about 2,800 lines) duplicate the
   `World.step` path that `HostRefinesWorldCore` proves. Four Kernel/Assurance modules still
   import `DurableCommitProtocol`. Rescue, repair, delete; measure the closure change. Owner:
   perf-rake. Source: `planning/SURPASS.md` §5.1 T11.

8. **Small verified defects:**
   - `Pred/Core.lean:339-341`: `writeOnce` accepts any rewrite of a slot that holds 0, so 0 cannot
     be a written value. Source: `mini-2-compiler-theory.md` F11.
   - `scripts/local-check.sh:499,686`: `find -perm +222` is BSD syntax. On GNU find the error
     yields empty output, so the "seed is writable" check passes. Source:
     `mini-5-prover-scripts-gates.md` F11.
   - `Assurance/SelvageV0Manifest.lean:1238`: `[LC-fs-adaptive] CLOSED` overstates
     `lightClientGrinding_sound`. Challenges and queries are fixed before the coins
     (`Selvage/LightClientGrinding.lean:435-480`), so an adaptive prover is not covered. Source:
     `mini-3-selvage-assurance-host.md` F4.
   - `Compiler/PredCompile.lean:621`: `Pred.witnessed` still lowers to constant false. ZK.md D1
     recommended deleting it, which fits "delete the twin". Source: `planning/ZK.md:670`.
   - `native/resource-client/journey.d/jdocuverse.sh:349`: the docuverse cold audit is a
     hard-coded `"state":"not-run"` stub.
   - `prover/src/sumcheck.rs:235-256`: the verifiers take their challenges from the proof. They
     are unwired, and `docs/review/2026-10-26-native-crates/prover.md` already covers this.
     Delete them rather than keep them.

9. **Friend-issued grain shares may be blocked at dispatch admission.** Unverified end to end.
   `Kernel/ApplicationDispatchAdmission.lean:624` requires
   `spec.issuer = ingress.appManagementSubject`, while
   `Kernel/ApplicationShareIssueSource.lean:48` allows an owner-delegated issuer. Check whether a
   non-operator member's `mini apps share` admits. Owner: app-market. Source:
   `planning/SPK-HOSTING.md` row 3.

10. **Hermes limits that are documented but unbuilt.** HERMES.
    - The out-of-budget notice is "the one unmetered write" (`deploy/hermes/README.md:60-66`).
    - Overflow refusals stay in controller custody and are not published to the room
      (`native/grain-runtime/RESIDENT-REQUESTS.md`).

    Owner: L4d. Source: `product/p-hermes-room.md:488-497`.

Further unbuilt ideas, verified absent and not demo-path:
- proven Nock jets and the SKA read-mask theorem (`planning/NOCK.md` §6 N14, `EVAL.md` §5);
- the job-market voucher, cosign and Hermes job tools (`COMPUTE.md` §8);
- a `mini verify` light-client verb over one certified root (`SURPASS.md` L1-L3);
- cover-traffic duty cells (`CHANNELS.md` §5);
- the powerbox (`SPK-HOSTING.md` rows 4 and 17; `native/spk-rpc/src/bridge_config.rs:77`);
- the per-request dispatch fee (`SPK-HOSTING.md` §3).

## Open decisions for ember

Each was left by claudesplosion and is still open in the tree. None is on the current owner
list (`docs/BACKLOG-2026-10-27.md` E1-E7).

1. Custody of the enrollment receiving key and a sweep policy (finding 2).
2. Whether to delete `Pred.witnessed` (ZK D1), and whether to delete the hyperdocument event-log
   family (`Kernel/HyperdocumentEventLog`, `HyperdocumentVersionEffects`) as a twin of
   DocumentHistory (EMBER-INBOX #7).
3. Whether the job market (`Kernel/Job`, `JobMoney`, `Run`, `TailBound`, all built and
   journey-tested) is product, and so owes web verbs under the web-parity ruling, or stays
   research.
4. Channels: ten taste forks plus the absent-mask audience (`planning/CHANNELS.md:1180-1228`).
   The code took the defaults: operator and witness mask at `Kernel/DomainEpoch.lean:273`, no
   relay process. They matter only if a live channel is wanted.
5. Who births and pays for a traveller's guest cell on a foreign node (K-PORTAL;
   `docs/APP-MARKET-2026-10-27.md:266`).
6. A free tier: whether an unpaid key gets a starter allowance, comps or free rooms. A comp mint
   is not built (`docs/PAY.md` §2.8).
7. Whether the age recipient for `mini-backup` was supplied. The repo does not say.
8. Product-direction lines from `planning/DREGGNET-CLOUD.md` that no current doc carries:
   - members get Mini's shell, never Unix accounts;
   - credits are service allowances with no redemption or bridge (state it on the join page);
   - a variable population with join, leave and rejoin as a gate parameter;
   - model-aware fair inference placement on the homelab.

## Not worth taking

- The 01-23 repo surveys: breadstuffs defects, already folded into ATLAS §3-§5.
- `prs/`, `fixes/` and `bakeoff/`: breadstuffs and old-box history.
- `product/deploy-*`: old workhorse operations.
- `planning/final/braid-*` and `integration-*`: merge logs.
- `tools/cv-improvements*`: cv features that now exist.
- The handoffs, SESSION-STATE and OVERNIGHT: superseded coordination.
- The `planning/prove/` dossiers and sims: literature behind CHANNELS, read only if channels
  resume.

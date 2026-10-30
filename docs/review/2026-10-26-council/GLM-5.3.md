All reading done; spot-checks confirm the load-bearing cites (`Host/ProviderUsage.lean:267-268` does throw on non-200 for metered routes; `Host/Main.lean:2616` is `serveFrame`; dregg-infra's `mini-reenroll` is a root shell script with no visible call into `session_reenroll.rs`).

---

# Council review: `docs/DEMO-PREFIX-2026-10-26.md` (seat minidregg-glm-2)

**What I read:** the plan whole; `HANDOFF.md` whole; `HBOX-CANDIDATE-a0db11f8.md` whole; the assigned sections of HISTORY, HCLOUD-GAP, SYNTHESIS (B, C.1, F, G), both triages, WEB-SPK-PUBLIC (§2, §7, §8), AFFORDANCES (§6, §7); ATLAS §6–§7. **What I did not read:** AFFORDANCES §5 (so the "room create 262 s" figure is taken from the plan's own citation, source unread), LEAN-TRIAGE §2, SYNTHESIS C.2–E and H, WEB-SPK §3–§6, HCLOUD-GAP §1–§6, HISTORY §1–§7. LOC claims are not re-measured.

## A. Coherence

The prefix is finite: phases bounded, deletions named with sources, §6 disclaims that anything has run. Internally it has five real faults:

1. **The gate contradicts itself.** Rule 4 (plan §4, `DEMO-PREFIX:146`): "Ship on the day planned even if rows are red; the gate hardens as surfaces turn on." Phase 2 step 1 (`:110`): "jdeploy3 on it (**every phase must be green** now that every surface is on: documents, apps, connector, residents, restart, rooms, churn)." These cannot both hold. WEB-SPK §4.1 (`WEB-SPK-PUBLIC.md:867`) sizes greening that gate **L / open-ended**, and HISTORY §8.2 (`HISTORY.md:559`) names exactly this — "shipping stopped when it was batched behind a composed gate that could not go green" — as what killed DEPLOY-3. The composed phases have *never executed* (HBOX-CANDIDATE `:280-282`: the v1/v2 manifest break meant "neither confirmed nor refuted"). Phase 2.1's parenthetical re-arms the trap rule 4 exists to disarm.
2. **R11's default contradicts the schedule.** R11 (`:175`): replace permit-all defaults with a Lean-emitted default **before strangers enrol** — default yes. The emit itself sits in C4, Phase 3, "weeks 2–4" (`:132`); the door opens and strangers enrol in Phase 2 step 3 (`:116-118`). Under permit-all, repair rank 17 (`RUST-TRIAGE.md:251`) is blunt: any holder of a factory observe grant may birth; a typo changes who may write every demo document. Either the default is wrong or the phase placement is.
3. **Arithmetic that doesn't close.** §1 says "six to eight parallel lanes, with four long poles (§3)" (`:33`); §3 has **ten** lanes and names no long poles. Phase 1 is days 2–9, Phase 2 days 7–12 (`:86,106`) — overlapping, though "phases are serial" (`:69`) and the candidate pins the post-Phase-1 tip (WEB-SPK `:790-792`: phase 1 must be merged first). And §2 claims "Rust ≈ 290K" (`:63`) where HISTORY §0.3 measured **422K native Rust** (`HISTORY.md:21`) — a 45% discrepancy on the number the whole ≤10%-LOC story leans on; neither the plan nor the history re-measured.
4. **The bar is met at a record count the demo outgrows by design.** The floor is p99 ≤ 5 s *at 1000 records* (`:30`); the clock ticks per minute (ruling taken, `:157`), a week of ticks alone is ~10k records (HCLOUD-GAP `#5/#7`, `HCLOUD-GAP.md:253,255`), `lifetime` is being raised specifically to survive the week (`:82`), and nothing past 1000 is measured. The 10k soak is parked in C8 (`:136`) as "coherence" — it is not coherence, it is the demo's own envelope, and it is unowned in Phases 1–2.
5. **WEB-SPK's honest schedule is absorbed but its risks aren't.** WEB-SPK's Phase 1 is six lanes, 3–5 days, and it still concludes "roughly two weeks, not one," naming #4 (gate), W7 (M6 on Debian 13 unproven), H1, and the rooms red (0/88 at `4795b657`) as the solo week-1 slippers (`WEB-SPK-PUBLIC.md:870-881`). The plan stacks WEB-SPK's six lanes *plus* L1/L2/L3/L4/L6/L9/L11 into the same window.

Cross-lane deletion/rescue conflicts: I checked the obvious ones and found none hard — traffic stacks 1+3 (3,774) match RUST-TRIAGE rows 6–7; Studio's ~1,233 matches row 14 under an already-taken ruling; the Lean 3,967 matches LEAN-TRIAGE §6 #1. L2's deletion of `session_reenroll.rs` with the re-point "a re-enrol must come from a Lean lifecycle command" (row 10) names a replacement **no lane owns**, but I verified `mini-reenroll` (dregg-infra `edge/mini/mini-reenroll`) is a root shell script that does not call it, so the door is not obviously broken; unverified beyond that grep.

## B. The fifteen rulings

- **R1** (demo runs minidregg). Genuinely ember's — product identity; HISTORY §8.572 demands this one sentence be agreed with her. Default is coherent (README Oct 23 + Oct 19 words; §0's reading of the Oct 22 nano program as being about nano's program is sound). **Rule: yes.**
- **R2** (DelveTalk commit on main or side branch). Engineering/repo hygiene on another project's code. **Rule: side branch; not her time.**
- **R3** (push dregg-infra now). Ops sequencing on our own mirror/anchor. **Rule: push, fetch-first, fast-forward; just do it.**
- **R4** (Hermes pool vs BYOK). Engineering already decided by the L1(c) dependency; matches SYNTHESIS G8 (`SYNTHESIS.md:366`). **Rule: BYOK rows live day one; pool only from a candidate carrying L1(c); the spend limit in 0.3 bounds the money.**
- **R5** (private-backend → degg-research). Repo organization; degg-research exists for this (HANDOFF `:26-29`). **Rule: yes, Phase 3, boundary scripts green.**
- **R6** (Selvage → zkml-research). Same. **Rule: yes, Phase 3.**
- **R7** (agent API v2/v3). Engineering; default matches SYNTHESIS G1 and RUST-TRIAGE rows 11/18 (the broken v3 paid arm is deleted either way). **Rule: as default.**
- **R8** (keep lifecycle v4 retry). Borderline, but the corpus itself says keep (LEAN-TRIAGE §3.2 `:323`), and with re-genesis every few days a failed CREATE is recovered by a new birth anyway. **Rule: keep; C3's one-stratum consolidation decides its fate, with the v4-decode fix (repair rank 18) as the only demo-relevant piece.**
- **R9** (traffic stack 2). Research-line custody — mildly ember-flavored, low stakes. Default coherent, though note the asymmetry: 5.2K of research stays in-tree while 110K leaves. **Rule: keep stack 2, and let it leave with the next research move.**
- **R10** (bend pair; runtime.c). Engineering — H-confidence triage (row 2); runtime.c's retirement should be contingent on the fast machine being the *reference*, not on a promise. **Rule: delete the pair now; retire runtime.c when C8's item lands.**
- **R11** (permit-all defaults). Mis-posed: the plan contradicts itself (A.2), so "default yes" is incoherent with the schedule as written. **Rule: pull a minimal Lean-emitted account/room default into L1/L7 — the emitter pattern already exists (job law, `Kernel/Job.lean` → `gen-joblaw.py`, SYNTHESIS B#6) — or put the hazard sentence on the join page as a stated condition of opening the door. The only ember-shaped residue is Q3 below.**
- **R12** (grain prices → Lean). Sequencing; default coherent with C6 and SYNTHESIS E.2. **Rule: as default; label the operator policy loudly meanwhile.**
- **R13** (workspace member-or-exclude, gated). Pure hygiene — and it should be **day 1**, not one lane among ten: three crates are unbuildable with silently-stopped tests (`:98`), which poisons every other lane's "green" (ATLAS law 8: distinguish ran-from-passed). **Rule: yes, first.**
- **R14** (README honest-state rewrite). Hygiene with no live alternative; L10 owns it. **Rule: yes.**
- **R15** (oracle appliance in the demo). Genuinely ember's — a scope addition coordinated with a live codex session editing the same `broker.rs`/`materialize.rs`/`spk-ingest` files as L3 (`:92`). Default coherent: §1 already lists it (`:27`). **Rule: yes, conditional on it passing the same m6/grain gate as any grain; if it slips, it misses a redeploy cycle, not the date.**

**Questions that actually need ember (4):**

1. R1, as one sentence: the public demo runs minidregg (repaired in place) — yes/no?
2. Strangers enrol in week 1 under permit-all defaults (every hosted signer can already read the whole Store, D8): accept with the hazard on the join page, or hold the door until a Lean-emitted default lands? (short choice)
3. R15: does the veri7vn oracle ship in the demo as an SPK grain, yes/no?
4. Money: mainnet pay-to-enrol plus one real mainnet payment from your wallet, with the capped OpenRouter key — yes, or devnet-only for week 1?

## C. Ordering and long poles

The Phase 1 lane *content* is right — it is essentially SYNTHESIS §F Tier 1 plus WEB-SPK's lanes, and the citations spot-check clean. The ordering and loading are wrong:

- **L9 goes first.** Gating the workspace (S) converts silently-stopped tests into visible red before any lane claims green. Buried as lane nine of ten, it is a mirror held up after the haircut.
- **Two cheap measurements gate the whole schedule and aren't sequenced.** The quiet-box G run (buried as L11's first clause, `:99`) decides whether L11 is an S or an L; the **cold Lean rebuild** — explicitly unmeasured (HBOX-CANDIDATE `:30-33`, open item 1; HCLOUD-GAP #3 notes 18.5 GiB of modules) — decides whether "one Host rebuild at the end" (`:86`) is 454 s or a day. Both belong on day 1–2, with the go/no-go written down.
- **Two never-run-on-the-demo-shape items sit late in a serial Phase 2.** Split tenancy (HISTORY §8.562: "the one structural blocker before inviting anyone") and M6-on-Debian-13 (WEB-SPK `:874-881` names W7 unproven as a week-1 slipper) are both scratch-runnable in parallel during Phase 1 once the hcloud project exists (0.3). As scheduled, either failing stalls the serial chain at day 9.
- **Cut from week 1:** L2's full fifteen-machine custody migration — "M then S×n" is unbounded serial work; the demo needs the 255-classification sites, the fleet-sign `uncertain` fix, and record-less money-rerun refusal (repair ranks 4/12/13), full `flow::Client` unification is Phase 3 coherence. Demote L1(f) (the 33 vacuous `∨ Collision` rewrites) to Phase 3: real repair, cheap later since the `RowsCollision` fix shape is in-tree (LEAN-TRIAGE §4.1), and nothing on the demo path turns on it.
- **Is ~2 weeks credible?** For *every surface reachable and a re-genesis cadence started*: yes, with those cuts — the warm build is 35 min fetch-to-candidate and the journey 904 s (HBOX-CANDIDATE `:28,55`), and DelveTalk proved the redeploy cadence. For *every surface on AND a green composed gate*: no. The composed phases have never executed once, G is red at every level even at 10 records on a loaded box (`:275`), and WEB-SPK's smaller six-lane version of the same plan already said "two weeks, not one." Rule 4 is the credible plan; Phase 2.1 should say so.

## D. What the plan gets wrong or misses

1. **The 1000-record bar vs the 10k-record week** (A.4) — the demo's own success criterion exceeds every measured envelope, and the soak that would close it is mislabeled as Phase-3 coherence. Cheapest mitigations if day-1 G is marginal: the 5-minute clock WEB-SPK 0.4 already proposed.
2. **R11 vs C4** (A.2) — strangers under permit-all in week 1 with the fix scheduled after the demo.
3. **Rule 4 vs Phase 2.1** (A.1) — the composed-gate trap, re-armed against the plan's own history lesson.
4. **The 290K-vs-422K Rust count** (A.3) — nobody re-measured; if 422K is right, Rust alone exceeds the whole founding budget and the plan's framing sentence is false.
5. **Ten parallel lanes on one tree** is ATLAS law 16's hazard in miniature, and §1's "four long poles" are never named — so no one is accountable for a pole slipping.

## E. The three changes I would make first

1. **Make the gate coherent, in rule 4's favor.** Rewrite Phase 2.1 to "jdeploy3 run, reds named, ship on the day"; make Phase 0.5's re-run (which finally exercises the composed phases for the first time in the system's history) an explicit Phase 1 exit deliverable: the red list it produces *is* the week-1 gate.
2. **Front-load the three cheap facts and the two scratch runs.** Day 1: L9 gating, quiet-box G, cold-rebuild measurement. Phase 1 gains a dregg-infra lane running `jsplit-tenancy.sh` and an M6 grain on a scratch cx43/Debian 13 — so the two never-run items stop sitting at the end of a serial chain.
3. **Cut L2 to the refusal-semantics core, demote L1(f), and resolve the permit-all contradiction** by pulling the minimal Lean-emitted default forward or writing the hazard onto the join page as a condition of opening the door — decided this week, not in weeks 2–4.

The plan's spine — repair-in-place, ship early, redeploy often, deletions named before lanes start — is the right one and matches what actually shipped in October. Its failure mode is inherited, not invented: it grows the gate and the lane count in the same breath. Fix those two and it holds. ( ⌐■_■ )


You are an independent reviewer on a council of models. The repository at /Users/ember/dev/minidregg ("Mini", minidregg) is a Lean-4-owned semantic computer with a Rust physical boundary; its owner, ember, wants a finite prefix of repair-and-consolidation work and then a temporary public demo on a Hetzner VM with EVERY surface on (ssh hosted shell, web docuverse, one SPK grain, Hermes residents, PAY, Discord, fleet, fn transport, the veri7vn oracle appliance). Today's orchestrating session wrote a plan and put fifteen "rulings" with defaults to ember. Ember's reply: "I feel like you delegated bullshit to me though :) ... Only after you've done multimodel synthesis should you put any rulings to me. The defaults you previously had may not be coherent." You are that synthesis. Be concrete, cite file paths and line numbers you actually read, and say plainly where you could not verify.

Read, in this order (use Read with offset/limit on long files; do not read the whole corpus):
1. docs/DEMO-PREFIX-2026-10-26.md (the plan; all of it, ~250 lines)
2. HANDOFF.md
3. docs/review/2026-10-26-history/HISTORY.md: sections "0. Five findings" and "8. Recommendations"
4. docs/review/2026-10-26-deploy/HCLOUD-GAP.md: sections 7 and 8
5. docs/review/2026-10-26-native-crates/SYNTHESIS.md: sections B, C.1, F, G
6. docs/review/2026-10-26-triage/RUST-TRIAGE.md: sections 1, 2.1 (skim), 4, 6
7. docs/review/2026-10-26-triage/LEAN-TRIAGE.md: sections 3, 4, 6
8. docs/review/2026-10-26-deploy/WEB-SPK-PUBLIC.md: sections 2, 7, 8
9. docs/review/2026-10-26-deploy/AFFORDANCES.md: sections 6 and 7
10. docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md (the candidate build + gate result from today)
11. ATLAS.md section 6 (the sixteen design laws) and section 7 (the carve)
Optionally spot-check any source file a claim points at.

Then write a Markdown review to stdout, at most 2,500 words, with exactly these sections:
A. Coherence: is the plan finite and internally coherent? Name every place two parts contradict each other or a report (e.g. a lane's deletion that another lane's rescue needs; a phase ordering that cannot work; a number that does not add up).
B. The fifteen rulings R1–R15 in the plan's §5: for each, (i) is it genuinely the owner's call, or an engineering decision the plan should just make; (ii) is the stated default coherent with the rest of the plan and with the ATLAS laws; (iii) what would you rule and why, in one or two sentences. End with the SHORTEST list of questions that truly need ember (aim for ≤ 5), each phrased so a yes/no or a short choice answers it.
C. Ordering and long poles: is Phase 1's lane set right? What is missing from the critical path (the Lean rebuild, the write-latency bar, the dregg-infra manifest fix, split tenancy, the deploy gate)? What would you cut from week 1 and what would you add? Is "every surface on in ~2 weeks" credible given the evidence in HBOX-CANDIDATE and HCLOUD-GAP?
D. What the plan gets wrong or misses: at least three concrete items with the evidence.
E. The three changes you would make to the plan first.
Do not flatter; do not pad; prefer a verified sentence to a plausible paragraph.

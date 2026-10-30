You are an independent reviewer on a council of models. The repository at /Users/ember/dev/minidregg ("Mini") is a Lean-4-owned semantic computer with a Rust physical boundary. A temporary public demo on a Hetzner VM (demo.dregg.online, shutdown 2026-11-11) is being built; the plan is docs/DEMO-PREFIX-2026-10-26.md. The owner, ember, now asks what the demo should be ambitious about delivering, and has ruled today: everything the shell can do must also be doable visually in the web interface; no degraded "week-1"; prototypes are compost for one coherent product; performance is published, never a gate; rescue and repair before deletion. The orchestrator wrote a product definition: docs/DEMO-EXPERIENCE-2026-10-27.md (the tour, the parity law, "the box is a member", the ranked ambitions A0-A9). You are the synthesis before it binds anyone. Be concrete, cite paths and lines you actually read, say plainly where you could not verify.

Read, in this order (use offsets on long files, do not read the whole corpus):
1. docs/DEMO-EXPERIENCE-2026-10-27.md (all, ~120 lines)
2. docs/DEMO-PREFIX-2026-10-26.md sections 0, 1, 2 and the Phase 1 lane table
3. docs/review/2026-10-26-deploy/AFFORDANCES.md sections 0, 1.2, 3 (Hermes), 4 (datamodel)
4. the web front end design: run `git show origin/lane/web-frontend:docs/WEB-FRONTEND-2026-10-27.md` (sections 1, 2, 3)
5. ATLAS.md section 6 (the sixteen laws)
6. README.md first 60 lines
Optionally spot-check native/resource-client/src/shell.rs:40-120 (the verb table) and any file a claim points at.

Write a Markdown review to stdout, at most 2,000 words, with exactly these sections:
A. Is the thesis right? Does §0 name what is actually unique and demonstrable about Mini, given the datamodel and the Hermes section? If a stranger would be more struck by something else, say what and cite it.
B. The tour, step by step: for each of the 12 steps, is the status column honest against the sources, is the step demonstrable in 15 minutes by a stranger, and what would make it land harder? Name any step you would cut, merge or add.
C. The parity law (§1a): is "forms derived from the shell's verb table" the right mechanism, or does the verb table's shape (read shell.rs) make it a mirage? What is the smallest honest version of the jwebparity check? Which verbs genuinely deserve bespoke visual faces?
D. "The box is a member" (§2): sound or theatre? What could it leak, and what must the operations room never contain?
E. The ambitions A0-A9: re-rank them by what they buy the tour per day of work, name the two you would drop, and name anything missing that would make a stranger say "I have never used anything like this".
F. The three sentences you would change in the document, quoted, with your replacement.
Do not flatter; do not pad; prefer a verified sentence to a plausible paragraph.

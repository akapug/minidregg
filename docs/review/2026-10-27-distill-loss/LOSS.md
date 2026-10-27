# How lossy were today's `cv distill` hand-offs

Root session `698fc87d` distilled lanes nine times on 2026-10-27 (14 predecessor → successor
pairs across seven lanes). Everything below is measured from the transcripts under
`~/.claude/projects/-Users-ember-dev-minidregg/698fc87d-…/subagents/`; the scripts were
throwaway Python over the raw JSONL. A successor's pack is its first record; its "tail" is the
records whose tool calls exist in the predecessor; its own work starts at the first call that
does not. Token figures for packs use cv's 2.3 bytes/token; for tool outputs, 4 bytes/token.
Scope: the 14 pairs listed in the table. Each was the first distill of its kind except where
the generation column says otherwise.

## The three largest loss classes

1. **Generational nesting (the bulk, and why the infra ratios collapsed).** A successor opens
   on its predecessor's pack, and the next distill kept that whole prompt as "1. Brief
   (verbatim)". Every generation's ledger, facts and timeline nested inside the next. The
   fourth infra pack was 521 KB, of which 442 KB (85%) was nested predecessors; across the seven
   second- and third-generation packs, 1.46 MB of nested briefs (~635k tokens) were loaded.
   The ratio falls with depth: infra 6.1× → 2.1× → 1.6×; L13 → 3.1× at generation 3. Hot-path's
   8.8× is a first-generation pack with a 3 KB brief and few notes.
2. **Commit messages kept as notes.** Lanes commit with `git commit -q -F <scratch>/msg.txt`,
   and each message file was kept verbatim as a note: 36 messages = 101 KB of the first infra
   pack's 227 KB timeline; 365 KB across the 14 packs; every note in five packs. The same
   `-q` style made the facts index blind to the commits themselves: the infra packs said
   "Commits made: none seen" (`0 commits`) for lanes that committed 86 and 17 times.
3. **Re-orientation the pack did not prevent.** In their first 40 calls the 14 successors made
   180 state probes (git status/log/fetch, PID files, job logs; 48k tokens) and 122 re-reads
   of files the predecessor had touched (106k tokens, ~26 min of call wall time), against 111
   calls of new work. Probes are partly right (the preamble asks for them), but the live state
   the predecessor last saw was not where a reader looks: the last message and newest heads
   sat at the end of a 100-500 KB pack, and the web pack's only repository head was stale.

## Per lane

Pack = the successor's first record (preamble + head). Brief = how much of that is the brief
(nested packs in generations ≥ 2). Notes = commit-message notes / all notes in the timeline.
First 40 = the successor's first 40 own calls: probes / re-reads / new reads / work (tokens of
output in brackets).

| lane | pair | gen | ratio | pack | brief | timeline | ledger | notes (commit/all) | first 40: probe / reread / new / work |
|---|---|---|---|---|---|---|---|---|---|
| web | ab1094b4→a4ac34a3 | 1 | 11.7× | 118 KB | 9 KB | 55 KB | 43 KB | 0 / 26 KB | 12 (6k) / 8 (8k) / 3 / 17 |
| web | a4ac34a3→a48135e7 | 2 | — | 168 KB | 118 KB | 19 KB | 21 KB | 0 / 0 | 20 (2k) / 13 (5k) / 2 / 5 |
| infra | aa1562a2→a8850c5b | 1 | 6.1× | 307 KB | 7 KB | 226 KB | 62 KB | 101 / 109 KB | 15 (5k) / 8 (6k) / 8 / 9 |
| infra | a8850c5b→a221a2ea | 2 | 2.1× | 442 KB | 307 KB | 100 KB | 27 KB | 64 / 64 KB | 13 (5k) / 10 (13k) / 9 / 8 |
| infra | a221a2ea→ae649955 | 3 | 1.6× | 521 KB | 442 KB | 57 KB | 15 KB | 25 / 29 KB | 8 (1k) / 2 (4k) / 0 / 0 (10 calls) |
| L4 | aa09ceb2→a6d30cc8 | 1 | — | 144 KB | 7 KB | 93 KB | 35 KB | 6 / 12 KB | 14 (7k) / 3 (2k) / 9 / 14 |
| L13 | abc0f69b→a2c38c67 | 1 | — | 160 KB | 8 KB | 90 KB | 51 KB | 36 / 55 KB | 15 (3k) / 9 (5k) / 0 / 3 (27 calls) |
| L13 | a2c38c67→af628c40 | 2 | — | 167 KB | 160 KB | 0.5 KB | 2 KB | 0 / 0 | 10 (3k) / 12 (7k) / 9 / 9 |
| L13 | af628c40→a7b20155 | 3 | 3.1× | 231 KB | 167 KB | 32 KB | 24 KB | 20 / 20 KB | 7 (2k) / 7 (4k) / 22 / 4 |
| L1 | a8b5515a→a9e6b18d | 1 | — | 168 KB | 7 KB | 112 KB | 40 KB | 19 / 27 KB | 12 (2k) / 10 (4k) / 6 / 12 |
| L1 | a9e6b18d→a436f5b0 | 2 | 2.8× | 235 KB | 168 KB | 45 KB | 16 KB | 14 / 14 KB | 5 (1k) / 17 (30k) / 13 / 5 |
| L2 | afd2d900→a0d9dfa8 | 1 | — | 98 KB | 5 KB | 57 KB | 27 KB | 38 / 38 KB | 16 (6k) / 12 (9k) / 1 / 11 |
| L2 | a0d9dfa8→ac9c91cf | 2 | 4.3× | 205 KB | 98 KB | 55 KB | 41 KB | 31 / 35 KB | 7 (2k) / 7 (3k) / 16 / 10 |
| hot | ae0d1796→acf3cf50 | 1 | 8.8× | 57 KB | 3 KB | 26 KB | 20 KB | 11 / 11 KB | 26 (3k) / 4 (6k) / 6 / 4 |

Ratios are the distill's own report where the root kept it. The verbatim tails were 16-57 KB,
of which tool outputs were only 3-13 KB (largest single output 5.6 KB, under the 6 KB cap); the
rest is tool inputs (heredocs, Write contents). The tail is not where the bulk is.

## The five questions

**(a) What successors re-did.** No successor re-ran an identical predecessor command in its
first 40 calls. The re-work is re-reading (122 calls, 106k tokens; L1's third generation alone
re-read 30k tokens of `PlatformCell.lean`/`CanonicalCellRegistry.lean` its predecessor had
worked in) and probing (180 calls, 48k tokens). Files the predecessor wrote in its last 30
calls were re-read only 8 times in all, so carrying written files' contents would have saved
little; the re-reads are of code the predecessor edited earlier, which the pack elides by
design and the successor rightly reads live.

**(b) What the root re-sent.** Every resume message (1.8-3.1 KB) re-stated the quest, the tip
and the rules. Fact by fact (shas, paths, lane branches, IPs, step ids) every one was already
in the pack: 0 of 196 facts lost. The loss is salience, not content: the root could not trust
the successor to find them in a 100-500 KB pack, and in the web case it repeated the pack's
stale tip.

**(c) What successors got wrong because of the pack.** One concrete case: the web pack's only
repository head was `cab76d29`, and "Commits made: none seen". The predecessor had made and
pushed three more (`872e6679`, `63cc3494`, `3c90b001`); their `git log --oneline -1` lines
followed a build's output, which the head extractor (first output line only) and the commit
extractor (`[branch sha]` only, absent under `-q`) both missed. The successor found "the
worktree was at 3c90b001, not cab76d29" after its own probes; the root's resume message had
repeated `cab76d29`. In each successor's first five exchanges with the root, none asked something the pack answered.

**(d) Why infra compressed 1.6× and 2.1× and hot-path 8.8×.** Nesting (442 of 521 KB, then
307 of 442 KB), then commit-message notes (101 KB of the first infra timeline). The
117-entry timeline of the first infra pack is 226 KB: 109 KB notes (101 KB of them commit
messages), 80 KB of the lane's own words, 37 KB of messages delivered to it. Verbatim messages
are not the problem; neither is the 14-call tail (30-35 KB). Exact-duplicate timeline bodies:
0 bytes in every pack, so de-duplicating the timeline would save nothing.

**(e) Is the sidecar used?** No. Zero `cv cat` calls in all 14 successors (and in every other
lane of this session). Successors re-read live files instead, which is usually right: the
sidecar holds what the file was, not what it is. The pack also gives no way to address an
elided output: `cv cat` takes a tool_use id, and the ledger prints message indices only.

## What changed in cv (branch `distill-loss-2026-10-27`)

Seven commits, each with a test (filtered `cargo nextest run -E 'test(distill)'`, 21 + 9 pass;
clippy clean). Not installed, not released.

| change | measured loss it answers | test |
|---|---|---|
| A distilled lane's brief is unwrapped; a `## 1b. Earlier generations` section carries each generation's timeline, commits and tips, oldest first; old ledgers and other facts stay in their sources | nesting, class 1 | `distilling_a_distilled_lane_carries_generations_instead_of_nesting_packs` |
| Commit-message notes (a `git commit -F` file, or trailer-signed) keep 700 bytes | class 2 | `commit_message_notes_are_cut_to_their_head_and_other_notes_stay_whole` |
| `git commit -q` + `git log --oneline` counts as commits made; a head is read past a compound command's output | "none seen"; the stale web tip (c) | `quiet_commits_and_compound_git_log_heads_are_facts` |
| `## 0. Hand-off` first: the last message verbatim, newest 5 heads and tips, PID files named, recent directories | class 3, (b) | `handoff_opens_the_pack_with_the_last_message_and_live_state` |
| No `⚠ lossy` for lineage, or for a sub-agent's title (pack and meta carry them) | noise on every run | `distill_lossy_lines_skip_what_the_pack_and_meta_carry` |
| `cv show --agent <exact id>` works on distilled lanes (`.flat.jsonl` is not an agent) | all 13 distilled lanes unaddressable | forest test with a sidecar |

**Before/after on the infra lane `a221a2ea8cf1d4104`** (keep-last 14, scratch output deleted):
0.18.0 gives ~265k tokens, 1.6×; the branch gives ~149k, 2.8×. The pack went from 558 KB to
313 KB: hand-off 4 KB, brief 7 KB, carried generations 150 + 55 KB (68 commit messages cut),
its own timeline 39 KB, facts 5 KB, ledger 15 KB, tail 33 KB. The hand-off names `demo-vm` at
`8ed3d72`, the tip the root typed into its resume message by hand.

**Not done, on purpose or for later.** Timeline de-duplication (0 duplicate bytes measured). A
token-budgeted `--keep-last` (tails are 16-57 KB and outputs a small part of them). Carrying the
contents of recently written files (8 re-reads in all). The sidecar is still written though no
successor read it; making elided outputs addressable (ids in the ledger, or `cv cat` by message
index) or dropping the sidecar is a decision for ember. The carried first generation is now the
largest part of a third-generation pack (150 KB): its verbatim words are the pack's contract,
and cutting them further would need a ruling on what "verbatim" owes an old generation.

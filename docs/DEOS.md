# DEOS: the docuverse friends write in

This is the present-state description of the docuverse on Mini: documents friends write
together, quote across, mark, annotate and read at past heights, through `mini shell`, Hermes
and `mini web`. The Lean modules and the Rust client are the authority. Section and row
numbers are the ones the code cites (`DEOS §1.3`, `§2.2 item #4`, `§2.3`, `§8 J19–J24`,
`§9 row 6`), so those comments resolve here. Rooms, streams, laws and Hermes in general are in
`docs/PLACE.md`.

Each section is marked **shipped**, **changed** (shipped, the difference stated) or
**design** (not built).

## 0. Summary

A document is a content cell (`Kernel/ContentResource.lean`, `Command`). Its actions are
`createDocument`, `createAtom`, `editAtom`, `link`, `unlink`, `annotate`, `transclude`, `mark`,
`unmark`, `editElement` (splice, move, remove), `createContainer`, `createRun`, `insertRun` and
the rewrap actions. An edit carries the record it expects; a line that moved since is refused
`staleAtom`. The element tree gives each line and quote a place
(`Kernel/ContentElementTree.lean`). Links and backlinks are a fold over the accepted log
(`Kernel/LinkIndex.lean`). A past version is a signed `at` read; `doc diff` compares two
renderings (`Kernel/DocumentHistory.lean`). A transclusion is admitted only under the
transcluder's own observe grant on the source (`transclude_requires_source_coverage`), and a
snapshot shows the pinned bytes or says `moved` (`transclusion_pinned`). Covered scope: the
content cell's own actions; per-document event-log cells, branch and merge
(`Kernel/HyperdocumentEventLog.lean`, `Kernel/HyperdocumentMerge.lean`) have theorems but no
shell verb.

## 1.3 Every verb a checked turn: `can`. **Shipped.**

`can [NAME] [--all]` (`native/resource-client/src/can.rs`) reads the capability records behind
the reference's capabilities, and for each shell verb they cover builds the smallest
representative command and asks the Host to dry-run it (Host op 130): planned as a real
command, so a law refusal names its clause, then assembled and submitted over a Store writer
that never appends. Nothing is committed. A verb no grant covers is omitted, or printed
`noGrant` with `--all`. It is a client fold over kernel answers and grants no authority.
J12A is `affordances-journey.sh`.

## 2.2 Client items. **Shipped.**

Item #4, P-DOC-WRITE: `doc pull NAME` prints the document's live lines and retains the read as
`seen/NAME.json`; `doc push ID NAME @FILE` diffs the file against that read into the minimal
`createAtom` / `editAtom` / tombstone actions, as one proposal. A line another friend changed
since the pull is refused by line (`staleAtom`), and nothing of that push lands. J12W is
`journey.d/j12w.sh`.

Item #6, P-DOC-TEMPLATES, is §9 row 6.

## 2.3 Hermes in the docuverse. **Changed.**

Hermes's room tools (`native/grain-runtime/src/resource_tools.rs`, `room_tool_specs`) include
`mini_doc_show`, `mini_doc_append`, `mini_doc_link`, `mini_doc_context` and `mini_doc_review`,
each a line of the pinned client's shell under Hermes's own workspace. `mini_doc_quote` and
`mini_doc_history` are not offered (a unit test in the same file pins that). The design's law
forcing a librarian's digest to quote rather than copy is not built.

## 8. The journeys J19–J24. **Shipped.**

`journey.d/jdocuverse.sh` (row JDV in `journey.sh`) runs J19–J24 on one Store through
friends' own `mini shell` sessions:

- **J19, a quote that cannot rot.** A range of one document is transcluded into another, as a
  snapshot and live at a line. After the source is edited, the snapshot keeps the old line and
  the live one shows the new line marked `live, revised`. A reader without a grant on the
  source sees a placeholder and no byte of it. `doc backlinks` lists the link mark and the
  transclusions.
- **J20, the past, signed.** `doc show NAME --at H` equals what the friend's `doc show` printed
  at `H`, byte for byte; `doc history` lists the writes; `doc diff` names an inserted line; a
  reader at a height before its grant is refused `no-grant`.
- **J21, your own editor.** Pull, edit, push; a concurrent edit makes the second push refused,
  naming the line.
- **J22, marks and a place.** Heading, bold and link marks; an annotation; a line inserted at
  line 2; a reviewer whose grant is scoped to `fields = {annotations}` may mark and is refused
  an edit.
- **J23, `can`.** The owner's verbs are all admitted; the reviewer's `mark` is admitted and
  `edit` refused with the reason.
- **J24, a page.** `mini web` serves the document; the page equals `doc show --html` byte for
  byte (one renderer).

A golden file (`journey.d/jdocuverse.golden.txt`) pins the final rendering, and a cold audit
re-admits every record.

Changed from the design: in J19 a reader without the source's grant sees no quoted bytes
(the design let a reader of the host see them); J23's librarian rows moved to J14
(`docs/PLACE.md` §2.7).

## 9. Lanes

| row | lane | state | where |
|---|---|---|---|
| 4 | P-DOC-WRITE | shipped (§2.2) | `doc pull`, `doc push`; `journey.d/j12w.sh` |
| 5 | P-AFFORDANCES | shipped (§1.3) | `src/can.rs`; `affordances-journey.sh` |
| 6 | P-DOC-TEMPLATES | shipped | `room new NAME --template workroom\|social\|story` births a room with a map; templates are files of shell lines (`docs/PLACE.md` §4.9); `journey.d/jtemplates.sh` |
| 7 | P-HERMES-LIBRARIAN-DOCS | changed (§2.3) | doc tools without quote or history |
| 13 | K-INSPECT-VIEWS | shipped | `inspect caps\|law\|receipt\|turn` and `why`: Lean renderers (`Host/InspectRender.lean`) over bytes the client holds or reads with its own signed views; `src/inspect_views.rs`, `inspect-journey.sh` |
| 19 | K-PREROTATE | shipped | a subject enrolls with a committed next key; only that key can rotate it (`Theory/KeyPreRotation.lean`, `Assurance/KeyPreRotationAudit.lean`); `journey.d/jrot.sh` |

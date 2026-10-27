# Ordinary-operation semantic boundaries

Reviewed commit: `54feb532e05039054640fef04b417e62110e4341` on current `main`.
Review branch: `lane/codex-review-semantics`; isolated worktree:
`/Users/ember/dev/minidregg-lanes/codex-review-semantics`.

This review found three actionable mismatches between a member's selection or
stored value and what the native consumers present. They concern ordinary
content, scalar fields and history; none requires the Oracle path, the active
Objective activity rewrite, platform receiver work or checkpoint changes.
No production source was edited. No network request, server, Lean build or
whole Cargo build was run. These are source findings with small native helper
reproductions, not qualification of a deployed Store.

## R1 — Line-based transclusion can include unselected or removed text (P1)

**Sites:** `native/resource-client/src/web_actions.rs:91` and `:110`;
`native/resource-client/src/workspace.rs:2184`, `:1625` and `:1647`.

**Trigger:** A source has atoms A=11, B=22, C=33 and a published run `[11,22,33]`
(created by `doc range source 1 3`). Move B after C with `doc move source 2 3`.
The document now displays A,C,B, while its published run retains A,B,C. Request
`doc transclude destination source 1 2 snapshot`, or select source lines 1–2 in
the browser connection form. The visible selection is `[11,33]`; the request's
pins are `[11,22,33]`. Live mode has the same mismatch. An even simpler variant
uses `doc remove source 2`: the visible source is A,C, but quoting its two lines
still includes B because removal detaches the element and leaves its atom and
published-run membership intact (`workspace.rs:2227`).

**Trace:** The structured grammar identifies FROM/TO as line numbers
(`shell_grammar.rs:150`). `line_atoms` correctly reads the current element-tree
order (`workspace.rs:2167`). The shell then discards all selected identities
except the endpoints in `source_line_atoms`. The browser retains the list until
`web_actions::transclusion`, which also uses only first/last to select a run.
Both expand the interval between these endpoints in that run, without comparing
its live atom sequence with the selected line sequence. Both submit the expanded
pins along with an observe-only source target. The destination stores this
range opening, not the original line selection.

**Why Lean does not refuse this:** `Kernel/ContentResource.lean:2120`
`resolveRange` deliberately uses run order. `openingHolds` at `:2153` checks that
the request pins equal that run interval's current live pins; it has no current
line-selection argument. `slotLive` at `:2071` tests document identity and atom
retirement, not placement under the document root. `Kernel/ResourceTransaction.lean:1066`
checks source coverage and `openingHolds`; the expanded opening satisfies that
check when the ordinary authority/policy prerequisites hold. The tree-edit
proofs and opening checks can both be correct while the client quotes the wrong
selection. This is a missing correspondence obligation, not a refuted theorem.

**Consequence:** The saved quote has extra or differently ordered content that
the member did not select. After a remove, it can bring detached text into a new
quote without the member asking for history. This is not an authority bypass:
the source still requires the member's observe authority.

**Fix:** Preserve the entire selected atom list through both planners. Choose an
existing published range only if its resolved live atom list equals that list in
order. If none does, refuse with “publish this selected range first” or, when the
member can write the source, explicitly offer to publish a new range. Do not
silently expand or reorder a selection. Carry the exact selected revisions and
source read through planning so a concurrent edit cannot change that equality.
Add composition cases for reordering, removal, a different intervening atom and
multiple overlapping runs; assert the displayed selection equals the submitted
opening, then exercise the real receiving path.

**Reproduction:** The actual Rust `line_atoms` and browser `transclusion` helpers
print:

```text
R1 snapshot: selected=["11", "33"]; quoted=["11", "22", "33"]
R1 live: selected=["11", "33"]; quoted=["11", "22", "33"]
R1 detached middle atom: visible=["11", "33"]; quoted=3 atoms
```

The helper result was executed; the full signed turn was not. Admission of the
expanded opening is established here by reading its actual checks, subject to
the stated authority, policy and unchanged-source prerequisites.

## R2 — The web view silently drops valid large scalar fields (P2)

**Site:** `native/resource-client/src/web.rs:559`–`:565`.

**Trigger:** A member creates or writes field
`340282366920938463463374607431768211456` (`2^128`) in a declared scalar cell
whose declaration/grant/law permit it. This is a canonical 39-digit identifier;
`workspace::scalar_actions` accepts and preserves it at `workspace.rs:2701`.

**Trace:** The workspace lowers the field without narrowing it. The Host parser
uses Lean `Nat` (`Host/Json.lean:212`, `:684`), the declared receiver carries the
field as a digest-valued state key (`Kernel/DeclaredFields.lean:27`), and the
Host's current scalar projection emits its full decimal string
(`Host/Json.lean:4858`, `:4879`). The web object's Fields table and the board
renderer both pass entries through `parse::<u128>().ok()?` inside `filter_map`.
A value beyond `u128::MAX` vanishes. No error or omitted-entry count is shown;
with only this field, the page claims `data-fields="0"`.

**Consequence:** A field which the source representation can store and the
ordinary client can author is absent from its visual face. In board mode an
entire state/owner pair can disappear. The bounded scalar authoring parser does
not prevent the example: `2^128` is within its current decimal length bound.
This review did not submit the field to a live Store.

**Fix:** Keep canonical decimal strings for generic field identities and sort
with the existing decimal comparison helper. The generic Fields table must show
all source entries. Derive board coordinates with arbitrary-width decimal
arithmetic, or explicitly label unsupported board coordinates while retaining
their generic field rows. Test `u128::MAX`, `2^128`, a normal field and a valid
large state/owner pair, asserting input/output coverage rather than merely that
a page renders.

**Reproduction:** Actual scalar authoring and web rendering helpers print:

```text
R2 scalar field accepted=340282366920938463463374607431768211456; visible fields=0
```

## R3 — History/diff presents ciphertext and object bytes as line text (P2)

**Sites:** `Host/Json.lean:5326`–`:5335`;
`native/resource-client/src/render/history.rs:15`–`:29`;
`native/resource-client/src/workspace.rs:2569` and `:2602`.

**Trigger:** Read `doc history` / `doc diff`, or the same browser pages, for a
protected document with a changed sealed atom, or a content document containing
an inline object. Current `doc show` distinguishes text, private content and
objects. History does not preserve that distinction.

**Trace:** `Kernel/DocumentHistory.lean:218` builds semantic atom records for its
line diff. The Host's `lineValueJson` emits `record.bodyBytes` as `payload` with
`kind="atom"`, but omits the actual `AtomKind`. `Theory/Hyperdocument.lean:331`
explicitly defines `bodyBytes` of a sealed object as its ciphertext. The Rust
history renderer treats every atom payload as lossy UTF-8 and surrounds it with
quotes. `doc_history` and `doc_diff` pass raw historical views directly into the
Host's diff projection and then this renderer; they do not obtain historical
local plaintext openings. The web uses the same formatter (`web.rs:539`).
By comparison, ordinary document rendering uses typed entries and authenticated
local openings (`render/mod.rs:375`), otherwise showing a locked/object label.

**Consequence:** A protected history shows ciphertext as apparent old/new text,
even for a member whose ordinary document view opens correctly. Object bytes
also appear as text. Merely receiving a historical read is not evidence that the
client has opened its encrypted content. This finding does not claim plaintext
leakage or broken encryption; the error is the meaning of the displayed history.

**Fix:** Preserve atom kind/schema and revision in the historical projection.
Reuse the existing authenticated opening path for each historical side where
custody permits it, and show a typed locked/binary/object placeholder otherwise.
Do not guess an opening from current plaintext or ciphertext equality. Keep raw
signed history separate from the presentation copy, as ordinary rendering does.
Test a member with old epoch custody, a member without it, an inline object, a
binary body and a wrapping-only update.

**Reproduction:** The actual `render::history::change_line` formatter, given the
same shape the Host emits for atom body bytes, prints:

```text
R3 history body=+ 11 "ciphertext"
```

The controlled ASCII body makes the type confusion legible; actual ciphertext
need not be ASCII. The source definitions above establish that sealed bodies
reach this presentation as ciphertext. No real encrypted document was decrypted
or submitted during this review.

## Checks, coverage and unconfirmed leads

Run the included witness from this worktree using existing compatible local
Rust dependencies:

```sh
python3 -B docs/review/2026-10-27-codex/semantic-boundaries-repro.py \
  --deps /Users/ember/dev/minidregg/target/debug/deps
```

Result: exit 0, five output lines exactly as quoted above. The script extracts
the current production helper bodies, compiles only a small harness with
`rustc`, and reuses an existing `serde_json` library read-only. It records compiler
and executable PIDs and logs under this lane's `scratch/semantic-repro/`. It does
not invoke Cargo, Lean, a Host, a network or a server. Member/entry field access
and deterministic nonce generation are the only helper substitutes. These are
witnesses asserting current incorrect behavior, not proposed permanent CI tests.

Also traced the ordinary `doc show` → retained last-read view → `doc edit` path:
`workspace.rs:2432`, `:5414`, `:5471`; atom guards retain the source record.
Browser edit sessions retain a per-tab reference and reject rebinding
(`workspace/web_author.rs:80`). Its save path records work before submission and
distinguishes refused, failed and uncertain using the decoded Host decision
(`:238` onward). No additional actionable failure was established in those
paths. The shared-name resolver's duplicate handling and scoped name validation
were read; there is no confirmed identity-normalization finding here.

Unconfirmed lead: local `Host/Json.lean:5480` history inspection associates
supplied pages by height, without explicitly retaining a target identifier in
`pageOfView`. The ordinary signed query path supplies pages for the requested
reference. This review did not establish an ordinary member path that substitutes
another target's page, so this is not a fourth finding or a security claim.

Not covered: full app lifecycle, money settlement, live provider behavior,
restart/fault injection, browser interaction, current platform receiver changes,
and Objective activity/checkpoint work owned by other audits. No claim of
cross-surface or deployed-system completeness follows from these focused checks.

**BATCH FOR THE PARENT:** validate the range case with a real signed source and
destination on the current candidate; run the fixed display/selection cases
through shell and web; qualify protected historical openings against real epoch
custody. The source/helper witnesses are ready for integration review; no
production patch is included.

# r3 INSTALL completion refusal diagnosis

The retained GitWeb r3 Store has an accepted INSTALL BEGIN and claim through
count 29. Its first event25 submission returned a definitive refusal. A
receipt-only lookup of the exact original ingress returned `absent`; no
completion was accepted. The original ingress, outcome, send marker, and lookup
remain under the protected hbox directory
`/var/lib/minidregg/spk/install-ops/gitweb-r3-0002/completion-v2-author/`.
The original `completion-v2.bin` SHA-256 is
`694f24c0182c256cc4f2357f803719910c5b22e218d5ae1d61a0d`.

The first read-only source probe used a byte-verified private copy of that
count-29 Store, the exact ingress, and the cb55 source-qualified OLeans. Its
corrected [source](ProbeCompletionAdmission.lean) is retained beside this note,
SHA-256 `3df4bbc7a12792f2745b7a8f4c0d0d82d3c74d4a0c832aa106c026b744fd4bc9`.
Persvati user scope `run-p458798-i989909962.scope`, invocation
`935766b8c5d44e1c9347f8965759bc97`, ran
`timeout 600 lake env lean ProbeCompletionAdmission.lean`. The shell pipeline
returned 124 at the ten-minute bound. Its [retained log](probe-r3-timeout.log)
contains only the scope header, SHA-256
`ff40c659ad6089945011aaced563d6f2b96c60b22602738f4a15ac07f50eee82`.
The original invocation journal records 10 minutes of CPU and no Lean
diagnostic. This timeout is **not** an admission verdict. The probe did not
open the live Store and did not submit an operation.

The source change in `Host/Main.lean` adds an operator-local
`diagnose-completion INGRESS.bin RESULT.json` command. It bounded-reads and
strict-decodes the retained event25 ingress, opens a verified current image
under the pinned signature helper, calls the same
`NativeHostReplay.admitCompletionV2Verified` admission as op38, and writes only
`type`, `status`, bounded `detail`, and `acceptedCount`. It has no intent,
CAS, receipt, or physical handoff path. Main source SHA-256 is
`234514df1853e7109e7c18437ff0cc0edc20eebbe752622c14294ebead3ab24`.
The first direct Lean attempt [refused before elaboration](main-r1-environment-refusal.log)
because the copied file was outside Lean's inferred root. With the private
overlay passed explicitly as `-R`, the second direct Lean invocation exited
zero with no Lean messages ([retained log](main-r2-pass.log), SHA-256
`4ccf34fd47153dcc1daaa2b29a64b56f5b08d795cd4bd89086da2bdb055917ba`).
The resulting `Host/Main.olean` SHA-256 is
`8ea1757d17d4d6b23545ced5aba359fbccf2eb49b902a98c326ecc24f2a856a5`.
Both checks used a private copy of the exact committed 579c9bc lower closure;
neither opened the Store. The command still requires a source-matched linked
native Host before it can diagnose the original refusal. No second op38
submission is authorized by this evidence.

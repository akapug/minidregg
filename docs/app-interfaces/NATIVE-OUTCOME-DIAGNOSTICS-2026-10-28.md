# Native lifecycle and enrollment outcome diagnostics

A Datasette recovery STOP on candidate `b26630168b63024c9c46311745fa0b25fa09c13f`
returned marker 26 with a 98-byte frame. The caller reported “not the expected tag”.
The own world was subsequently removed successfully. Its native journals were
removed during that cleanup before the later request to archive the exact frame;
only the driver stderr remains. The particular reply's outcome is **unknown**.
This change does not diagnose that lost reply or requalify the stopped app.

The concrete source defect is independent of that lost evidence:
`Host/Main.lean::dispatchLifecycleClaimSubmitSession` returns `outcomeCodec`
under marker 26 for rejected, contention, unavailable, uncertain, and historical
replayed results. Only a fresh installed CAS winner returns the committed
projection. The v3 claim, v3 STOP claim and v4 claim callers now share one helper
that validates the transport frame, retains/inspects an Outcome with the pinned
Host's own decoder, and returns its named diagnostic. Every Outcome remains an
error at this boundary, including a confirmed historical receipt. Existing
request/active markers and exact `op26-frame.bin` retention remain in place.
There is no new retry or physical handoff and the error remains `InvalidData`.

Op82 is an append-free enrollment authoring request. Its exception path returns
NO_RECORD (253); its successful plan uses marker 82. The enrollment caller had
recognized only HOST_OUTCOME (255), mislabeling 253 as an invalid frame. The
existing authoring seam now decodes both envelopes through its pinned Host,
retains the body beside the already retained exact frame, and reports the
marker distinction. The same helper covers authoring assembly (83). Submission
and its existing no-reinvoke fence are unchanged. The two executables use
different transport-frame representations, so they share the source decoder
approach rather than a second Rust authority/Outcome codec.

## Evidence

On the existing warm runtime tree, the two new spk-host tests first failed with
unnamed tag errors, then passed. The two enrollment diagnostic tests first
failed with invalid-frame/generic refusal errors; all five enrollment tests
then passed, including `lost_submit_response_never_reinvokes_op84`. Tests cover
uncertain, refused and replayed outcomes, truncated/wrong-marker frames,
noncanonical Outcome decode failure, and unchanged committed-payload forwarding.
Their injected decoder checks the transport-to-decoder/classification boundary;
it does not independently implement the source codec.

Separately, the source-derived payload fixtures were passed to the retained
candidate's actual `minidregg-host CONFIG inspect outcome INPUT OUTPUT` on hbox,
after world removal, without creating or submitting any world operation. Host
SHA-256: `6036ed74d002296a47cc5a965fbdb4b74f2df049b2c36cbf577332b84b0c94c4`.
With the ASCII `DREGG/NATIVE-HOST/OUTCOME/v8` prefix, these tails decoded:

| Tail bytes (decimal; ASCII named separately) | Pinned decoder result |
| --- | --- |
| `1 1 1 1 1 4 255` + `tip!` | uncertain, effect undecided, detail `74697021` |
| `1 1 1 0 0` | contention, effect undecided |
| `1 1 0 9 5 255` + `claim` + `7 255` + `refused` + `0` | refused, operation-rejected, effect no-record |
| `0 1 0 11 255 12 255 13 255 14 255` | confirmed replayed, transaction11/event12/count13/root14 |
| `9` | rejected as noncanonical/wrong-family, exit2 |

These are source-derived classification fixtures, not recovered bytes of the
lost STOP response. No payload credentials are present in this document.

Future own-world teardown uses `app-interface/archive-world-evidence.sh` before
`world-down.sh`. It selects only `host/apps/APP/{custody,install,install-refused-N,gN}`
under the source-confirmed state root (`grain.rs`), without following links.
Package and app-volume siblings are never traversed. Nested cache/image/volume
names are pruned. Driver evidence uses `w/evidence` with those same exclusions;
`w/sock` contributes only top-level regular identity/PID/log files, never its
endpoint subdirectories or sockets. One aggregate limit covers both sources:
4096 files, 256 MiB source bytes, 96 MiB per file, 16384 traversed entries and
16 directory levels. Archive output is separately capped at 288 MiB, including
tar metadata. Files are identity-checked before and after reading. Archives
have private permissions and recorded hashes; COMPLETE exists only on success.

Four small local fixtures pass: a fake app volume containing `op26-frame.bin`
is excluded while the exact custody reply is preserved; cache/socket/link
entries are excluded; aggregate/file-count bounds refuse before tar output;
a symlinked custody root is refused; and a failing archive subprocess prevents
the following cleanup command. No hbox world or build was needed for these
archive checks.
The own runner refuses destructive cleanup if this archive step fails. Private
archives may contain custody material and are not committed.

# Oracle public data attachment: review

This records the contract, focused test results, and limits of the review. The
custody tests below passed; they do not establish a deployed Mini appliance.
The subsequent real mount audit and release build are recorded separately in
[`oracle-public-data-native-2026-10-27.json`](evidence/oracle-public-data-native-2026-10-27.json).

## Authority boundary

The signed SPK contains `minidregg-data.json`, an optional declaration of one public data inventory digest. `spk-package-stream` snapshots and hashes the raw SPK, verifies its signed archive, and indexes members of that verified archive. The package descriptor author includes the raw digest and checks that its image identity is `DREGG/SPK-IMAGE/v1` followed by those 32 bytes. The launch descriptor embeds the canonical package descriptor; resident launch rechecks the retained descriptor against the verified package. This binds a changed declaration to a changed package identity, subject to SHA-256 collision resistance and the receiving path reading the declaration from the same verified archive.

Lean admission does not parse the declaration, check the inventory, establish public visibility, or prove that fd 7 names the declared data. The native receiving and mount code must enforce those properties. The new mechanism is operator-published public data only; knowing a digest grants no access to private data. Changing that premise requires an actual authority and admission design, not a theorem equating a digest with permission.

## Adversarial contract

The decisive tests must run against the production receiving and mount paths, with an accepted positive control. A standalone checker that merely restates these rules is not evidence of those paths.

* An absent declaration gives no attachment. A malformed declaration, unknown field, wrong schema, uppercase or malformed digest, duplicate member, non-regular member, or changed signed declaration is refused. A different valid signed SPK cannot reuse the original package/launch identity.
* The inventory is read as exact bytes: changed whitespace with the old digest, a different valid revision, a missing inventory or missing data, incorrect schema or visibility, extra fields, malformed digest, unsorted or duplicate paths, wrong size or file digest all fail before spawn.
* Absolute paths, empty components, `.`/`..`, separators or embedded NUL, symlinks at every directory and file position, non-regular files, undeclared extra files, and directory substitutions must not escape or silently alter the published tree. Check both traversal and replacement after opening.
* The held data descriptor must correspond to the verified inventory and the exact declaration at the final launch boundary. Replacing the pathname or substituting an unrelated descriptor cannot change the mounted data. Concurrent writes and renames must either be impossible under the custody/ownership rules or be detected; a hash followed by a mutable tree is not a stable snapshot.
* Only the fixed read-only `/opt/oracle-data` mount is exposed. Test write refusal and the package-controlled destination's symlink ancestry. No package argument, environment, request, or cross-grain state can choose another host path or target. Test fd census inside the app and inherited-descriptor traversal.
* A restart reopens and revalidates the declared revision. Removal or mutation fails closed rather than falling back to another revision or an earlier descriptor. Two grains using the same public revision may share it, but one cannot select a different package's declaration or obtain its private state.

Test results, exact commands, and environment belong here when they exist. Hash checks establish the published bytes only under their explicit custody assumptions; they do not independently establish that an operator actually intended those bytes to be public.

## Focused Linux result

On hbox, an independent minimal snapshot included the production `native/spk-host/src/shared_data.rs` directly in `deploy/oracle/attachment-review/tests/contract.rs`. Source SHA-256 was `bc06b24ce889da909f309bf4580056d7edf77dea632a2e427ec9529a91016339`; test SHA-256 was `90b369904c418423fd7290d51af7ab69ca4bf6e6345934aa2fc205a6a587218e`. The offline `cargo test --test contract` run passed **7/7** in 0.45 seconds. Its log and hash receipt are on hbox in `/tank/dregg-build/attachment-review-20261027/test.log` and `receipt.sha256`.

These checks exercise publication and reopening, including positive publication, declaration mutation, wrong or absent revisions, a symlink source, bad inventory fields, changed inventory bytes, extra files, missing data, and replacement of a held data directory. They do not run the signed-package admission, actual bubblewrap mount, or cross-grain/restart journey. Removing or adding entries changes protected metadata as well as the tree; these tests establish refusal, not which individual detector caused it.

A later bounded hbox run tested custody source SHA-256 `32b2e7babf6fdd1e85f8eab208361c12313ab13ef1d0ae070bae82f263a60108`. Its three focused unit tests passed, then the explicitly selected 513 MiB sparse-source-to-independent-destination publication test passed in 115.78 seconds. `/usr/bin/time -v` reported a peak resident set of 22,012 KiB for the cargo invocation and children. Both runs used `SWARM_MEM_MAX=4G swarm-build cargo test -j2 --offline`; logs and hashes are in hbox `/tank/dregg-build/attachment-review-20261027/custody-units.log`, `custody-513m.log`, and `custody-new.sha256`. This fixture tests a single large file, not the real dataset or its mounted application.

## Namespace custody investigation

A resident user namespace maps the operator and app identities but not initial-namespace root. On hbox, root-owned and foreign-owned fixture directories both appeared under the same overflow UID. A namespace-side numeric overflow UID therefore cannot distinguish them. The existing bootstrap can distinguish prevalidated root objects by retained handles; that evidence has to reach the actual package and data custody checks.

A bounded real-namespace control used the production bwrap/newuidmap entry and retained-handle implementation. It accepted a prevalidated root directory after entry while rejecting foreign-owned, app-owned and symlink ancestors before entry, as well as foreign/app metadata, a symlink and an inode replacement after entry. This control passed, but it does not itself test the namespace fix in package verification or public-data opening. Its hbox log is `/tank/dregg-build/attachment-review-20261027/namespace-control.log`.

Separately, a held-publication control passed: after a publication directory is renamed, its already-open verified handle remains usable, while a new open refuses both the missing catalog path and a symlink substituted at that path. Restoring the directory permits a new open. The log is `namespace-held-control.log` in the same hbox directory; this control did not enter the user namespace.

The namespace-aware receiving control now runs the production public-data opener and audit inside that namespace. An operator-owned file with host GID 0 is correctly checked against its receipt after that group becomes unmapped; a root-owned directory with host GID 100001 also retains its captured UID/GID. An inode created after capture and the foreign and app owners are refused. Adding a separate catalog entry leaves an already-held publication usable. Renaming the held publication changes its pinned metadata and now fails closed; this is a deliberate restriction of the earlier held-rename behavior, not evidence that arbitrary catalog changes are transparent. Logs and exact source/test hashes are in hbox `/tank/dregg-build/attachment-review-20261027/namespace-receiving.log` and `namespace-receiving.sha256`.

The implementation retains a descriptor for each captured finalized public-data entry across revisions. Its nominal 131,072-handle bound is not a promise that a host can open that many: the process's file-descriptor limit can be lower, so a large valid inventory or accumulated revisions can refuse startup. The actual host limit and retained revision count must be sized and monitored, and reducing the required retained handles is future engineering work.

The final composed control also exercised the production package-stream receiver in the same real namespace. The old scratch check refused the unmapped root ancestor. The new callback accepted a genuine signed SPK, returned its exact raw SHA-256, and rejected a validly compressed archive whose signing key was changed. Foreign-owned, app-owned and symlink scratch ancestors were refused. The same run passed the public-data receipt/open/audit and provenance controls above. It used an independent snapshot with `SWARM_MEM_MAX=4G swarm-build cargo run -j2 --offline`; the exact source and harness hashes are in hbox `/tank/dregg-build/attachment-review-20261027/namespace-signed.sha256`, with output in `namespace-signed.log`. This is a small fixture, not the full resident lifecycle or a deployed acceptance result.

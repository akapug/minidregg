# Oracle public data attachment: review

This records the contract and the limits of the review while implementation is in progress. It is not evidence that the attachment has been deployed or that the checks below have passed.

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

# Public data beside an Oracle appliance

Oracle's executable SPK can stay small while its large databases live in a
separate, operator-published directory. Multiple grains can mount the same
read-only revision at `/opt/oracle-data`. Individual database files do not pass
through Cap'n Proto `Data`, so this route has no 512 MiB SPK-member limit.

This version is for **public application data only**. A digest is an identity,
not a grant to private data. There is no private-data registry, URL fetcher,
caller-selected host path, or new Rust authorization rule. Mini still admits the
signed package and lifecycle operation. The package's raw digest transitively
binds its exact signed attachment member.

## Signed attachment and inventory

The SPK contains one root member named `minidregg-data.json`, at most 4 KiB:

```json
{"schema":"minidregg-public-data-v1","inventory_sha256":"<64 lowercase hexadecimal characters>"}
```

The mount target is always `/opt/oracle-data`; the member cannot supply a target,
source path, URL, resource profile, or visibility override. Duplicate and unknown
JSON fields are refused.

The digest is SHA-256 of the **exact inventory file bytes**, including any
whitespace. The publisher retains these bytes without re-encoding them:

```json
{
  "schema": "minidregg-public-data-inventory-v1",
  "visibility": "public",
  "files": [
    {"path": "root/relstore/example.sqlite", "size": 123, "sha256": "<64 lowercase hexadecimal characters>"}
  ]
}
```

Entries must be sorted by path with no duplicates. Paths are relative ASCII;
components contain only letters, digits, underscore, hyphen, and dot. Empty
components, `.` and `..`, absolute paths, file/directory collisions, and symlinks
are refused. Current physical bounds are 1 MiB inventory, 4,096 files, 64 GiB
total content, 16 path components, 255 bytes per component, and 1,024 per path.
These are operator ingestion bounds, independent of Mini's semantic SPK limits.

## Operator publication

The native Rust binary follows the crate's existing automatic binary-discovery
pattern. Build `spk-data-publish` through the bounded independent Linux build
route, alongside the matching `spk-host`.

```sh
spk-data-publish publish \
  --store /protected/spk/public-data \
  --source /protected/oracle-appliance-source \
  --inventory /protected/data-inventory.json
```

The store's parent must already exist under protected root/operator-owned
ancestry. The publisher can create the `public-data` leaf. Source directories
are local filesystem inputs; source hardlinks are allowed because the publisher
makes independent destination files. It follows no source symlinks and checks
each opened file's type, length, SHA-256, and identity before and after copying.
Files not named by the inventory are not copied.

A successful command prints one JSON object with schema
`mini-spk-public-data-publication-v1`, `inventory_sha256`, `directory`,
`total_bytes`, `file_count`, and `reused`. The layout is:

```text
SPK_ROOT/public-data/
  .publish.lock
  sha256-INVENTORY_SHA256/
    inventory.json
    receipt.json
    data/
      root/relstore/example.sqlite
```

The receiver derives `SPK_ROOT` from its protected package-store identity. It
does not take the public-data store path from a request or signed attachment.

The publisher holds a nonblocking store publication lock, streams with a 64 KiB
buffer into exclusively created files, and syncs the copied files and directory
tree. Destination files are independent single-link files with mode 0444;
directories are 0555. Publication uses Linux `renameat2(RENAME_NOREPLACE)` and
syncs the store. An existing exact publication is checked and reused, even if
the original source is no longer available. Existing content is never silently
overwritten, repaired, or removed.

Available disk space is checked before copying for the expected content and
bounded metadata. This is a preflight, not a reservation against other writers
or filesystem quotas. If publication fails, its specifically named unpublished
stage is retained and named in the error. The tool does not retry, glob-delete
stages, collect old revisions, or delete source data.

## What the receipt establishes

`receipt.json` is protected operator metadata, not a signature or a new admission
artifact. It binds the exact inventory digest to the actual copied data root,
every implied directory, and every expected file. Its identities include device,
inode, size, owner/group, mode, link count, and nanosecond modification/change
times. It is written only after the publisher checks every copied file hash.

Opening a publication verifies metadata custody, the exact inventory hash, the
receipt binding, the complete expected tree, and all retained identities. Missing
or extra entries, symlinks, hardlinked destination files, writable files,
replacement inodes, changed sizes, and changed timestamps are refused. The
returned handle retains the data and publication directory descriptors. A final
`recheck()` can verify the same tree immediately before the descriptor enters
the sandbox. It reads metadata rather than rehashing 15 GiB on every start.

This has the existing SPK store's **trusted operator and filesystem custody**
assumption. Mode bits do not stop a privileged operator from changing data and
forging a replacement receipt. Metadata checks also do not detect silent
filesystem corruption that leaves recorded metadata unchanged. An explicit
operator audit reads and checks every file hash:

```sh
spk-data-publish audit \
  --store /protected/spk/public-data \
  --inventory-sha256 INVENTORY_SHA256
```

An audit never repairs or republishes content. Receipts contain local filesystem
identities, so copying a published tree to another filesystem is not a valid
migration; publish verified source bytes on the destination instead.

## Live revisions and checks

A different inventory digest creates a different publication. Existing handles
continue to refer to their original directory inode; no pointer named `current`
is consulted at mount time. Normal publication never removes old revisions.
Operators must keep live revisions available. Renaming a whole publication for
an isolated missing-data test and restoring it preserves its data-tree receipt;
replacing or mutating a member does not.

The focused tests cover closed attachment/inventory shapes, hardlinked sources
becoming independent verified copies, safe reuse, old revision retention, and
failed-copy preservation. An explicitly selected Linux test publishes a 513 MiB
file from sparse input to exercise a member larger than the SPK format permits.
The independent adversarial suite exercises the production module's custody and
mutation refusals. These tests establish the physical boundary; the end-to-end
Oracle fixture separately checks the current Mini install/start and read-only
mount path.

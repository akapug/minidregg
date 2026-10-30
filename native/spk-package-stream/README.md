# Bounded SPK reader

This crate verifies the real Sandstorm package format: the eight-byte magic,
one XZ stream, a Cap'n Proto signature message, and an archive message. It checks
the Ed25519 signature over the embedded SHA-512 digest and recomputes that digest
over the exact archive bytes. It hashes the exact compressed input with SHA-256.
The pinned Bread manifest decoder derives the app ID from the verified signing
key. Manifest and bridge configuration bytes are retained without re-encoding.

Input is copied into an anonymous temporary file before decoding, so changing the
source path cannot change the materialized package. liblzma decodes to another
anonymous file in 64 KiB increments, with a separate 128 MiB decoder-memory limit.
A temporary read-only mapping validates archive pointers and constructs an index;
file data is borrowed without copying. The mapping is dropped before returning.
Extraction uses 64 KiB positional reads. No compressed or decoded archive-sized
buffer is retained in memory.

| Profile | Compressed input | Decoded archive | Decoder memory |
| --- | ---: | ---: | ---: |
| `standard-v1` | 256 MiB | 768 MiB | 128 MiB |
| `market-large-v1` | 512 MiB | 2 GiB | 128 MiB |
| `operator-appliance-v1` | 8 GiB | 20 GiB | 128 MiB |

Only the trusted caller selects a profile. Limits also bound extracted bytes
(including aliased file pointers), 100,000 entries, 64 directory levels, a
per-profile Cap'n Proto segment bound (512 for `standard-v1`, 4,096 for the large
profiles), 4,096 bytes per path, and 16 MiB total retained path and
symlink bytes. Signed manifests are limited to 1 MiB and bridge configs to 64 KiB.
Unknown union tags, invalid names, duplicate names, escaping links, and reserved
mountpoint substitutions fail before publication. This reader accepts one archive
frame and rejects trailing compressed or archive data.

The caller must provide protected scratch storage and own publication. Host
qualification spools beside the protected input, installed-image verification
spools in its protected package store, and installation spools in the destination
store. Large profiles refuse Linux tmpfs/ramfs, whose pages consume the service's
memory budget. An available-space preflight requires compressed input plus the
decoded cap, or twice each for installation's extracted image and retained SPK.
This is a conservative workspace check, not a reservation against other writers
or filesystem quotas. I/O failures close the anonymous spools. A killed installer
can retain its named unpublished stage for operator inspection; it is never
glob-deleted or retried automatically. The host publishes a private staging directory
atomically without overwrite and stores the selected profile outside the package
root in protected `import-policy.json`. Legacy images without it use the standard
profile. A package member with the same name has no effect. These are physical
import limits: Mini's semantic admission rules remain independent, and its
existing 256 MiB package identity bound has not been raised by this crate.

The existing SPK schema stores each file as one Cap'n Proto `Data`, whose 29-bit
length limits a member to 536,870,911 bytes. Raising the total archive limit does
not allow multi-gigabyte individual members. Oracle's largest stores need chunked
packaging or a separately admitted immutable data volume; this crate implements
neither extension. There has not been a 15 GiB appliance installation test.

Tests use genuinely signed Bread fixtures, generated multi-segment Cap'n Proto,
corrupt/truncated packages, a validly compressed signature/hash forgery, independent
resource bounds, aliased data amplification, and an oversized sparse input. The
host's materializer test checks publication, retained bytes, wake verification,
profile custody, legacy fallback, and refusal to replace an existing image.

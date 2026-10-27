# Linux runtime for the Oracle appliance

This recipe supplies the Linux x86-64 runtime used by the Oracle package. It
contains Python and its dependencies, not Oracle's knowledge stores or Mini
host authority. The package stager adds the separately pinned Oracle source,
bridge, and large-data inventory.

The October 27 build uses the public Ubuntu 24.04 image
`ubuntu@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea`.
It adds **Python 3.12.3**, glibc **2.39**, SQLite **3.45.1**, and the eight exact
Python dependency versions required by `../check-runtime.py`. Five transitive
wheel dependencies are also pinned. It does not copy the build host's Python,
libc, home directory, or credentials.

## Inputs and acquisition

`inputs.lock.json` names every added Ubuntu package and wheel, its exact version,
primary distribution URL, and SHA-256. Ubuntu downloads additionally retain the
SHA-512 supplied by apt's signed package metadata. The lock records the pinned
base image identity, the retained Docker export's SHA-256, and the hashes of the
Ubuntu InRelease documents. `requirements.lock` is pip's hash-locked install
input. It installs only those local wheel bytes, with no dependency resolution
or network access during assembly.

The initial resolution used Ubuntu's signed `noble`, `noble-updates`, and
`noble-security` metadata, then downloaded the **explicit versions** in the lock.
PyPI resolution requested the eight exact direct versions and Linux CPython
3.12 wheels compatible with manylinux 2.28 or older. Its resulting URLs and
hashes were frozen before installation. No packages were installed on the host.
The metadata, downloads, base export and full resolver logs are retained on
hbox under `/othersys/lanes/oracle-rootfs-20261027/inputs` and `evidence`.

For a repeat build, obtain those exact locked files into this layout:

```text
inputs/
  ubuntu-base.tar
  requirements.lock
  debs/<locked .deb filenames>
  wheels/<locked .whl filenames>
```

Do not substitute a new `ubuntu:24.04` tag or resolve newer dependencies.
`ubuntu-base.tar` is the retained export of the digest-pinned image. Docker
export metadata can differ between Docker versions, so retain that export as an
input artifact; do not silently change the lock when its hash differs. A new
input selection needs a new lock and receipt.

## Assemble and check

Use Linux, `tar`, `dpkg-deb`, and an existing pip-capable Python. The current
build used pip 24.2 only as an installer; pip and its host environment are not
copied into the rootfs. `assemble.py` refuses an existing destination. It checks
all input hashes, extracts only into the new directory, adds the locked Debian
packages and wheels, and preserves their license and distribution metadata.

```sh
SWARM_MEM_MAX=4G swarm-build python3.12 deploy/oracle/rootfs/assemble.py \
  --inputs "$INPUTS" --lock deploy/oracle/rootfs/inputs.lock.json \
  --target "$NEW_ROOTFS" --pip-python "$PIP_PYTHON"
```

The assembly removes set-id bits, empties the image's `/var`, `/tmp`, `/proc`,
`/dev`, `/run`, `/sys`, and `/opt`, removes generated package CLI wrappers, and
replaces Docker instance host/DNS files with fixed local values. It removes
already-dangling base-image links, including `/etc/mtab` pointing into the
intentionally empty `/proc`. The measured build removed 50 such links; their
list is retained with its evidence. It does not remove package copyright or
license files. These edits affect only the newly constructed directory.

Run the actual imports inside the rootfs. The explicit environment keeps host
Python paths and thread settings out of the result:

```sh
sudo env -i LANG=C.UTF-8 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  PATH=/usr/sbin:/usr/bin:/bin /usr/sbin/chroot "$NEW_ROOTFS" \
  /usr/bin/python3.12 -B - < deploy/oracle/check-runtime.py
sudo env -i LANG=C.UTF-8 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  PATH=/usr/sbin:/usr/bin:/bin /usr/sbin/chroot "$NEW_ROOTFS" \
  /usr/bin/python3.12 -B - < deploy/oracle/rootfs/check-math.py
sudo python3.12 deploy/oracle/rootfs/check-elf.py \
  --rootfs "$NEW_ROOTFS" --bridge "$LINUX_BRIDGE" --out "$NEW_ELF_RECEIPT"
python3.12 -B deploy/oracle/stage.py inventory \
  --rootfs "$NEW_ROOTFS" --out "$NEW_ROOTFS_INVENTORY"
```

The ELF check lists dependencies for all 985 ELF files, including a temporary
copy of the bridge which it removes afterward. Wheel-private helper libraries
use their package's adjacent library directory for this check; their importing
extensions provide that search context at runtime. The math probe exercises
NumPy solving, SciPy's determinant, scikit-learn linear regression, and SymPy
factoring. These checks pass for the retained build. The bridge at SHA-256
`45ad0b6cb55f1bddc7a7c4296143b2f2a110d8ed7e2a7d6cafd1987e6528b4eb`
requires at most `GLIBC_2.34`, below the supplied 2.39.

With `/dev` deliberately empty for packaging, joblib reports that shared
semaphore support is unavailable and operates serially. This did not prevent
imports or the measured calculations. The actual grain's device mounts and
complete Oracle startup are checked by appliance acceptance; these rootfs
checks do not establish either.

## Transfer

After inventory, keep the rootfs unchanged. A tar archive preserves its file
modes and internal symlinks; bounded xz compression creates the transfer input:

```sh
tar -C "$NEW_ROOTFS" -cf - . | xz -T2 -6 > "$NEW_ARCHIVE"
sha256sum "$NEW_ARCHIVE" "$NEW_ROOTFS_INVENTORY"
```

Run this pipeline with `pipefail` and write to a new temporary output before
publishing it. The measured rootfs has 8,904 regular files totaling
369,380,718 bytes; its largest member is 25,409,073 bytes. Its transferable
tar.xz archive is **77,045,396 bytes** (about 73.5 MiB). The exact archive, input,
inventory and evidence hashes are in `receipt-2026-10-27.json`. Including the current
Oracle code and unstripped bridge leaves the decoded runtime below Mini's
768 MiB limit. The final signed SPK's exact compressed size and member inventory
remain the package lane's checks. No large knowledge store is embedded here.

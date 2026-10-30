#!/usr/bin/env bash
# scripts/burst/remote/root.sh -- the ROOT phase of burst-up, run ON the box as root (idempotent).
#
#   sudo bash root.sh --role gate|lane --user ember --pubkeys FILE [--srv /srv] [--slice-pct 85]
#                     [--lane-slot-mem 48] [--threads-per-slot 5] [--no-data-disk] [--thread-budget N]
#   bash root.sh --no-root --role lane --srv DIR [--thread-budget N] [--slice-pct P] [--threads-per-slot T]
#
# --no-root: a host that is not ours to administer (Ember's laptop): run as the LOGIN user, never sudo. Does only the
#   user-level half -- swarm-build and capnp 1.5.0 under $SRV/pipeline/bin, the user swarm.slice cap, slots sized from
#   --thread-budget, the $SRV layout -- and REPORTS the rest (packages, earlyoom, linger, data disk, the login user) in
#   $SRV/burst/NO-ROOT.txt, which burst-check reads. Implies --no-data-disk. --thread-budget caps the lane slots'
#   threads (default: nproc; a laptop keeps <= half its cores).
#
# Takes a fresh Ubuntu box (or re-runs on a built one and changes nothing that is already right) to:
#   - the second NVMe at $SRV (metal boxes; skipped when $SRV is already a mount or --no-data-disk)
#   - the package set every pipeline script assumes (incl. psmisc/lsof: `fuser` must exist, 10-07)
#   - earlyoom; the login user with sudo and linger; capnp 1.5.0 (sha256-pinned)
#   - /usr/local/bin/swarm-build (the repo's scripts/burst/swarm-build: named scopes)
#   - swarm.slice MemoryMax = --slice-pct of RAM (every swarm-build nests under it)
#   - BUILD SLOTS SIZED FROM THE BOX: lane slots = round(threads / --threads-per-slot), two small-check
#     slots, and on a gate box build-slot-1 + build-slot-mk reserved for the merge gate. Their list goes to
#     $SRV/SLOTS.txt and $SRV/burst/slots.env for the user phase's box-env (box.env is what scripts read).
#   - $SRV/{mini,mini-logs,lanes,warm-base,git,sccache,lake-cache,artifacts,journeys,pipeline,briefs,burst}
set -euo pipefail
role="" user=ember pubkeys="" SRV=/srv slice_pct=85 slot_mem=48 tps=5 data_disk=1 noroot=0 budget=""

while [ $# -gt 0 ]; do
  case "$1" in
    --role) role=$2; shift 2 ;; --user) user=$2; shift 2 ;; --pubkeys) pubkeys=$2; shift 2 ;;
    --srv) SRV=$2; shift 2 ;; --slice-pct) slice_pct=$2; shift 2 ;; --lane-slot-mem) slot_mem=$2; shift 2 ;;
    --threads-per-slot) tps=$2; shift 2 ;; --no-data-disk) data_disk=0; shift ;;
    --no-root) noroot=1; data_disk=0; shift ;; --thread-budget) budget=$2; shift 2 ;;
    *) echo "root.sh: unknown $1" >&2; exit 64 ;;
  esac
done
case "$role" in gate|lane) ;; *) echo "root.sh: --role gate|lane" >&2; exit 64 ;; esac
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ "$noroot" = 1 ]; then
  [ "$(id -u)" != 0 ] || { echo "root.sh: --no-root runs as the login user, not root" >&2; exit 64; }
  user=$(id -un); mkdir -p "$SRV/burst" "$SRV/pipeline/bin"; LOG=$SRV/burst/root-phase.log
else
  [ -f "$pubkeys" ] || { echo "root.sh: --pubkeys FILE (the login user's authorized_keys)" >&2; exit 64; }
  [ "$(id -u)" = 0 ] || { echo "root.sh: run as root" >&2; exit 64; }
  LOG=/var/log/burst-up.log
fi
exec > >(tee -a "$LOG") 2>&1
echo "== root phase $(date -Is) role=$role srv=$SRV$( [ "$noroot" = 1 ] && echo ' (--no-root: user-level half only)')"
NR=$SRV/burst/NO-ROOT.txt; [ "$noroot" = 1 ] && printf '# %s: NOT INSTALLED on this host for lack of root (burst-up --no-root, %s). burst-check reads this.\n' "$(hostname)" "$(date -Is)" > "$NR"
noroot_missing() { echo "NOT INSTALLED (no root): $*"; printf '%s\n' "$*" >> "$NR"; }
export DEBIAN_FRONTEND=noninteractive

# --- data disk -> $SRV (metal; instant deploy forbids RAID) ---
if [ "$data_disk" = 1 ] && ! mountpoint -q "$SRV"; then
  rootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
  data=""
  for d in $(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'); do
    [ "$d" = "$rootdisk" ] && continue
    [ -z "$(lsblk -no MOUNTPOINT /dev/$d | tr -d '[:space:]')" ] && [ "$(lsblk -no NAME /dev/$d | wc -l)" = 1 ] && { data=$d; break; }
  done
  if [ -n "$data" ]; then
    echo "data disk: /dev/$data (root on $rootdisk) -> $SRV"
    blkid -L srv >/dev/null 2>&1 || mkfs.ext4 -q -F -L srv "/dev/$data"
    mkdir -p "$SRV"; grep -q " $SRV " /etc/fstab || echo "LABEL=srv $SRV ext4 defaults,noatime 0 2" >> /etc/fstab
    mount "$SRV"
  else echo "no blank data disk: $SRV stays on the root filesystem"; fi
fi
mkdir -p "$SRV"

# --- packages ---
pkgs=(build-essential git curl python3 python3-venv python3-nacl cmake pkg-config libssl-dev unzip zstd jq rsync
      earlyoom clang lld htop tmux libpam-systemd dbus-user-session file sqlite3 age time psmisc lsof bc ripgrep
      bubblewrap bsdextrautils xxd)
missing=(); for p in "${pkgs[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ "$noroot" = 1 ]; then
  for p in "${missing[@]}"; do noroot_missing "pkg $p"; done
  systemctl is-active -q earlyoom || noroot_missing "earlyoom (inactive)"
  loginctl show-user "$user" -p Linger 2>/dev/null | grep -q yes || noroot_missing "linger for $user (user units stop at logout)"
else
if [ ${#missing[@]} -gt 0 ]; then apt-get update -q; apt-get install -y -q "${missing[@]}"; fi
systemctl enable --now earlyoom >/dev/null 2>&1 || true

# --- login user ---
id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
install -d -m 700 -o "$user" -g "$user" "/home/$user/.ssh"
touch "/home/$user/.ssh/authorized_keys"; chmod 600 "/home/$user/.ssh/authorized_keys"; chown "$user:$user" "/home/$user/.ssh/authorized_keys"
while read -r k; do [ -n "$k" ] && ! grep -qxF "$k" "/home/$user/.ssh/authorized_keys" && echo "$k" >> "/home/$user/.ssh/authorized_keys"; done < "$pubkeys"
echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$user; chmod 440 /etc/sudoers.d/90-$user
loginctl enable-linger "$user"
fi

# --- capnp 1.5.0 from source, sha256 pinned (a no-root host: under $SRV/pipeline/capnp, linked into $SRV/pipeline/bin) ---
CAPNP=capnp; [ "$noroot" = 1 ] && [ -x "$SRV/pipeline/bin/capnp" ] && CAPNP=$SRV/pipeline/bin/capnp
if ! command -v "$CAPNP" >/dev/null || [ "$("$CAPNP" --version)" != "Cap'n Proto version 1.5.0" ]; then
  prefix=/usr/local jobs=$(nproc) nicer=""; [ "$noroot" = 1 ] && { prefix=$SRV/pipeline/capnp; jobs=${budget:-$(nproc)}; nicer="nice -n 15"; }
  t=$(mktemp -d); ( cd "$t"
  curl -fsSL -o capnp.tar.gz https://github.com/capnproto/capnproto/archive/refs/tags/v1.5.0.tar.gz
  echo "d5ebdf858e9885c33d4b3f765006d68bd66e9b002bf4d607ff4317ef9c1aac6a  capnp.tar.gz" | sha256sum -c -
  tar xzf capnp.tar.gz; cd capnproto-1.5.0/c++
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$prefix" >/dev/null
  $nicer cmake --build build -j"$jobs" >/dev/null; cmake --install build >/dev/null; [ "$noroot" = 1 ] || ldconfig ); rm -rf "$t"
  [ "$noroot" = 1 ] && for b in "$prefix"/bin/*; do ln -sfn "$b" "$SRV/pipeline/bin/$(basename "$b")"; done
  [ "$noroot" = 1 ] && CAPNP=$SRV/pipeline/bin/capnp
fi
echo "capnp: $("$CAPNP" --version) ($(command -v "$CAPNP"))"

# --- swarm-build (one source: the repo's) + the slice cap ---
swarm_dir=/usr/local/bin; [ "$noroot" = 1 ] && swarm_dir=$SRV/pipeline/bin
install -m 755 "$here/../swarm-build" "$swarm_dir/.swarm-build.new" && mv -f "$swarm_dir/.swarm-build.new" "$swarm_dir/swarm-build"
ram_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
slice=$(( ram_gb * slice_pct / 100 ))
uhome=$(getent passwd "$user" | cut -d: -f6); d=$uhome/.config/systemd/user/swarm.slice.d
if [ "$noroot" = 1 ]; then mkdir -p "$d"; else install -d -o "$user" -g "$user" "$uhome/.config" "$uhome/.config/systemd" "$uhome/.config/systemd/user" "$d"; fi
printf '[Slice]\nMemoryMax=%sG\nMemorySwapMax=0\n' "$slice" > "$d/50-memcap.conf"; [ "$noroot" = 1 ] || chown "$user:$user" "$d/50-memcap.conf"
[ "$noroot" = 1 ] && systemctl --user daemon-reload
# --- build slots sized from the box ---
threads=${budget:-$(nproc)}
n_lane=$(( (threads + tps/2) / tps )); [ "$n_lane" -ge 1 ] || n_lane=1
if [ "$role" = gate ]; then first=2; else first=1; fi      # a gate box keeps build-slot-1 for the keeper's own checks
lane_slots=""; for i in $(seq "$first" $((first + n_lane - 1))); do lane_slots="$lane_slots $SRV/build-slot-$i"; done
small_slots="$SRV/build-slot-small-1 $SRV/build-slot-small-2"
gate_slots=""; [ "$role" = gate ] && gate_slots="$SRV/build-slot-mk $SRV/build-slot-1"
mkdir -p "$SRV"; for s in $lane_slots $small_slots $gate_slots; do [ -e "$s" ] || install -m 666 /dev/null "$s"; chmod 666 "$s"; done
lean_threads=$(( (threads + n_lane - 1) / n_lane )); [ "$lean_threads" -le 8 ] || lean_threads=8
mkdir -p "$SRV/burst"
cat > "$SRV/burst/slots.env" <<S
# Written by burst-up root.sh $(date -Is): $threads threads, ${ram_gb}G RAM, role $role. Input to box-env.
BURST_ROLE=$role
BURST_LANE_SLOTS="${lane_slots# }"
BURST_SMALL_SLOTS="$small_slots"
BURST_GATE_SLOTS="$gate_slots"
BURST_LEAN_THREADS=$lean_threads
BURST_SLICE_GB=$slice
BURST_SLICE_PCT=$slice_pct
BURST_THREAD_BUDGET=$threads
BURST_NO_ROOT=$noroot
BURST_SWARM_BUILD=$swarm_dir/swarm-build
S
cat > "$SRV/SLOTS.txt" <<S
$(hostname) ($threads threads, ${ram_gb}G RAM, swarm.slice ${slice}G; burst-up $(date -u +%FT%TZ), role $role)
LANES = ${lane_slots# } at LEAN_NUM_THREADS=$lean_threads (swarm-build cap ${slot_mem}G per build; the swarm.slice ${slice}G is the box guard): take one ONLY with $SRV/pipeline/scripts/slot.sh CMD
        or build-anywhere TARGET... (a free slot on either box). Never a hand-typed flock chain.
SMALL CHECKS = $small_slots at 2 threads (lean-ask --reload, lane-check route there automatically).
$( [ -n "$gate_slots" ] && echo "GATE = $gate_slots (merge keeper only: slot-mk.sh; never a lane's, never reclaimed)." )
Who holds what: $SRV/pipeline/scripts/slots   (holders, waiters, IDLE; --free; --peer). All of this is in $SRV/pipeline/box.env.
S

# --- layout ---
if [ "$noroot" = 1 ]; then for d in mini mini-logs lanes warm-base git sccache lake-cache artifacts journeys pipeline/spk pipeline/bin briefs burst; do mkdir -p "$SRV/$d"; done
else
for d in mini mini-logs lanes warm-base git sccache lake-cache artifacts journeys pipeline briefs burst; do install -d -o "$user" -g "$user" "$SRV/$d"; done
install -d -o "$user" -g "$user" "$SRV/pipeline/spk" "$SRV/pipeline/bin"
fi
[ "$noroot" = 1 ] && echo "NO-ROOT.txt: $(grep -vc '^#' "$NR") items not installed ($NR)"
echo "== root phase DONE $(date -Is): $n_lane lane slots x ${lean_threads} threads, slice ${slice}G"

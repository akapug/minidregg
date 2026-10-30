#!/usr/bin/env bash
# scripts/burst/remote/user.sh -- the USER phase of burst-up, run ON the box as the login user (idempotent).
#
#   bash user.sh --tip SHA --stage /tmp/burst-up [--srv /srv] [--origin U@H] [--mirrors 'U@H ...'] [--peer ALIAS]
#                [--fetch-from ALIAS] [--spk FILE] [--sccache-port N] [--role gate|lane] [--journeys] [--set 'K=V ...']
#
# --set: further box.env exports (box-env --set), so a re-run of this phase keeps them (fn images, SWARM_NICE, ...).
# A --no-root host (root.sh --no-root wrote BURST_NO_ROOT=1 to slots.env) is not ours to administer: this phase
# writes nothing outside $SRV but the user units and the swarm.slice drop-in -- no ~/.profile, ~/.bashrc or global
# git config edits, no toolchain installers (a missing toolchain is reported in $SRV/burst/NO-ROOT.txt). A
# shell there gets the layout by `. $SRV/activate` (box.env), never from the profile.
#
# From the staged repo copy ($STAGE = this checkout's scripts/burst, scripts/pipeline, deploy/candidate):
#   toolchains (elan at the tip's lean-toolchain, rustup at rust-toolchain.toml, bun pinned), $SRV/mini at TIP,
#   git identity, ~/.profile (PATH + `. box.env`), the pipeline scripts to $SRV/pipeline/scripts (what
#   scripts/pipeline/install does, from the staged copy), the candidate builder, the lean-ask REPL, sccache
#   (binary + env + a PERSISTENT user service), box.env from $SRV/burst/slots.env + the topology flags,
#   the slot watcher as a persistent service, the shared remote + its sync timer (gate role), the publisher
#   (gate) / journey runner (--journeys) as persistent services, the SPK package, the briefs ($STAGE/briefs).
set -euo pipefail
tip="" STAGE="" SRV=/srv origin="" mirrors="" peer="" from="" spk="" port=4226 role=lane journeys=0 sets=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tip) tip=$2; shift 2 ;; --stage) STAGE=$2; shift 2 ;; --srv) SRV=$2; shift 2 ;; --origin) origin=$2; shift 2 ;;
    --mirrors) mirrors=$2; shift 2 ;; --peer) peer=$2; shift 2 ;; --fetch-from) from=$2; shift 2 ;; --spk) spk=$2; shift 2 ;;
    --sccache-port) port=$2; shift 2 ;; --role) role=$2; shift 2 ;; --journeys) journeys=1; shift ;; --set) sets=$2; shift 2 ;;
    *) echo "user.sh: unknown $1" >&2; exit 64 ;;
  esac
done
[[ $tip =~ ^[0-9a-f]{40}$ ]] || { echo "user.sh: --tip must be 40 hex" >&2; exit 64; }
[ -d "$STAGE/pipeline" ] && [ -d "$STAGE/burst" ] || { echo "user.sh: --stage DIR with pipeline/ burst/ candidate/" >&2; exit 64; }
. "$SRV/burst/slots.env"; noroot=${BURST_NO_ROOT:-0}; NR=$SRV/burst/NO-ROOT.txt
export PIPELINE_ROOT=$SRV/pipeline ARTIFACT_ROOT=$SRV/artifacts JOURNEY_ROOT=$SRV/journeys
LOG=$SRV/burst/user-$(date -u +%Y%m%dT%H%M%SZ).log; exec > >(tee -a "$LOG") 2>&1
echo "== user phase $(date -Is) tip=$tip role=$role"
cd ~

# --- toolchains, pinned by the tip's own files ---
if [ "$noroot" = 1 ]; then
  for t in .elan/bin/elan .cargo/bin/rustup .bun/bin/bun; do [ -x ~/$t ] || { echo "NOT INSTALLED (no-root host: the owner's toolchains): ~/$t"; echo "toolchain ~/$t" >> "$NR"; }; done
else
[ -x ~/.elan/bin/elan ] || curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
[ -x ~/.cargo/bin/rustup ] || curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
[ -x ~/.bun/bin/bun ] || curl -fsSL https://bun.sh/install | bash -s "bun-v1.3.11" >/dev/null
fi
export PATH=$HOME/.bun/bin:$HOME/.elan/bin:$HOME/.cargo/bin:$PATH
[ "$noroot" = 1 ] || { git config --global user.name "ember arlynx"; git config --global user.email "cmrx64@gmail.com"; git config --global commit.gpgsign false; }

# --- the repo at TIP ---
[ -d "$SRV/mini/.git" ] || git clone -q https://github.com/emberian/minidregg.git "$SRV/mini"
git -C "$SRV/mini" cat-file -e "$tip^{commit}" 2>/dev/null || git -C "$SRV/mini" fetch -q origin "$tip" main next 2>/dev/null || git -C "$SRV/mini" fetch -q origin
git -C "$SRV/mini" checkout -q -B main "$tip"
lt=$(cat "$SRV/mini/lean-toolchain"); rt=$(sed -n 's/^channel *= *"\(.*\)"/\1/p' "$SRV/mini/rust-toolchain.toml")
if [ "$noroot" = 1 ]; then
  [ -d ~/.elan/toolchains/"$(echo "$lt" | sed 's#/#--#; s#:#---#')" ] && echo "lean toolchain $lt: present" || { echo "NOT INSTALLED (no-root host): lean toolchain $lt"; echo "lean toolchain $lt" >> "$NR"; }
  rustup toolchain list 2>/dev/null | grep -q "^$rt" && echo "rust toolchain $rt: present" || { echo "NOT INSTALLED (no-root host): rust toolchain $rt"; echo "rust toolchain $rt" >> "$NR"; }
else
elan toolchain install "$lt" 2>&1 | tail -1
rustup toolchain install "$rt" --profile minimal -c clippy -c rustfmt 2>&1 | tail -1
fi
# --- the tip's cargo dependencies, once: lane-build's rust step builds --offline --locked, so a fresh box without
# them fails at its first git dependency (burst5 10-17: sandstorm-package from emberian/dregg). A no-root host's
# ~/.cargo is its owner's: not fetched there, declared in NO-ROOT.txt.
if [ "$noroot" = 1 ]; then
  ( cd "$SRV/mini" && cargo "+$rt" fetch --locked --offline >/dev/null 2>&1 ) && echo "cargo deps: present" \
    || { echo "NOT FETCHED (no-root host): cargo deps of $tip"; echo "cargo deps" >> "$NR"; }
else
  ( cd "$SRV/mini" && cargo "+$rt" fetch --locked ) 2>&1 | tail -1
fi

# --- profile: PATH + box.env (the one box-local file every script reads; a login shell gets it too) ---
if [ "$noroot" = 1 ]; then
  printf '# %s/activate: this host'"'"'s pipeline layout (burst-up --no-root). Source it; the profile does not.\n. %q\n' "$SRV" "$SRV/pipeline/box.env" > "$SRV/activate"
else
grep -q '^# burst PATH' ~/.bashrc 2>/dev/null || { printf '# burst PATH (before the interactive guard)\nexport PATH=$HOME/.bun/bin:$HOME/.elan/bin:$HOME/.cargo/bin:$PATH\n' | cat - ~/.bashrc > ~/.bashrc.new && mv ~/.bashrc.new ~/.bashrc; }
grep -q 'bun/bin' ~/.profile 2>/dev/null || echo 'export PATH=$HOME/.bun/bin:$HOME/.elan/bin:$HOME/.cargo/bin:$PATH' >> ~/.profile
sed -i '/PIPELINE_SLOT_[12]=/d' ~/.profile
grep -q 'pipeline/box.env' ~/.profile || echo "[ -f $SRV/pipeline/box.env ] && . $SRV/pipeline/box.env   # slots, threads, sccache, lake cache (scripts/pipeline/box-env)" >> ~/.profile
fi

# --- pipeline scripts + candidate builder, from the staged copy (what scripts/pipeline/install does) ---
mkdir -p "$PIPELINE_ROOT/scripts" "$PIPELINE_ROOT/candidate"
rsync -a --delete "$STAGE/pipeline/" "$PIPELINE_ROOT/scripts/"
rsync -a "$STAGE/candidate/lane-build.sh" "$STAGE/candidate/lib.sh" "$PIPELINE_ROOT/candidate/"
# provenance = the commit the scripts were STAGED from (burst-up's checkout), which need not be the tip at $SRV/mini
{ cat "$STAGE/STAGED-FROM" 2>/dev/null || git -C "$SRV/mini" rev-parse HEAD; } > "$PIPELINE_ROOT/scripts/.installed-from"; echo "installed-from: $(cat "$PIPELINE_ROOT/scripts/.installed-from") (staged by burst-up)"
P=$PIPELINE_ROOT/scripts
# the FIFO Lean-slot wrapper at its well-known path (sized by PIPELINE_LEAN_SLOTS/_SLOT_THREADS/_SLOT_NICE in box.env, via --set);
# a hand-installed copy already there is left alone
mkdir -p "$PIPELINE_ROOT/slots"; [ -e "$PIPELINE_ROOT/slots/with-lean-slot" ] || ln -s ../scripts/with-lean-slot "$PIPELINE_ROOT/slots/with-lean-slot"
# the warm base's mk-lane.sh is its OWN tree's scripts/pipeline/mk-lane.sh (advance/relay keep it so); refresh when it knows MK_LANE_PROBE
if [ -f "$SRV/warm-base/src/scripts/pipeline/mk-lane.sh" ] && grep -q MK_LANE_PROBE "$SRV/warm-base/src/scripts/pipeline/mk-lane.sh"; then
  install -m 755 "$SRV/warm-base/src/scripts/pipeline/mk-lane.sh" "$SRV/warm-base/.mk-lane.sh.new" && mv -f "$SRV/warm-base/.mk-lane.sh.new" "$SRV/warm-base/mk-lane.sh"
fi

# --- the persistent unit files first (install-sccache starts the persistent sccache unit when its file exists) ---
U=~/.config/systemd/user; mkdir -p "$U"
unit() { sed -e "s|@SRV@|$SRV|g" -e "s|@PORT@|$port|g" -e "s|@HOME@|$HOME|g" "$STAGE/burst/units/$1" > "$U/$1.new" && mv -f "$U/$1.new" "$U/$1"; }
unit pipeline-sccache.service; unit pipeline-slots.service
[ "$role" = gate ] && unit pipeline-artifacts.service; [ "$journeys" = 1 ] && unit pipeline-journeys.service
# a no-root host is someone's machine: every pipeline unit runs at Nice=15 (a drop-in; the unit files stay the repo's)
if [ "$noroot" = 1 ]; then for u in pipeline-sccache pipeline-slots pipeline-artifacts pipeline-journeys; do [ -f "$U/$u.service" ] || continue
  mkdir -p "$U/$u.service.d"; printf '[Service]\nNice=15\nIOSchedulingClass=idle\n' > "$U/$u.service.d/50-no-root-nice.conf"; done; fi
# ... and its disk is not ours either: the sccache cache stays at BURST_SCCACHE_GB (default 30) instead of the unit's 120G
[ "$noroot" = 1 ] && printf '[Service]\nEnvironment=SCCACHE_CACHE_SIZE=%sG\n' "${BURST_SCCACHE_GB:-30}" > "$U/pipeline-sccache.service.d/60-no-root-cache.conf"
systemctl --user daemon-reload
# a TRANSIENT pipeline-sccache (install-sccache's own, pre-burst-up) must go before the persistent one can start
systemctl --user show pipeline-sccache.service -p FragmentPath 2>/dev/null | grep -q "/run/user" && systemctl --user stop pipeline-sccache.service 2>/dev/null || true
# --- sccache: binary + env; its server = the persistent unit (survives a reboot) ---
PIPELINE_SCCACHE_PORT=$port "$P/install-sccache" --cache-dir "$SRV/sccache" 2>&1 | tail -1

# --- box.env ---
args=(--slots "$BURST_LANE_SLOTS" --lean-threads "$BURST_LEAN_THREADS" --small-slots "$BURST_SMALL_SLOTS" --lake-cache "$SRV/lake-cache")
[ -n "$BURST_GATE_SLOTS" ] && args+=(--gate-slots "$BURST_GATE_SLOTS")
[ -n "$origin" ] && args+=(--origin "$origin"); [ -n "$mirrors" ] && args+=(--mirrors "$mirrors")
[ -n "$peer" ] && args+=(--peer "$peer"); [ -n "$from" ] && args+=(--fetch-from "$from")
[ "$SRV" != /srv ] && args+=(--srv "$SRV"); [ -n "$sets" ] && args+=(--set "$sets")
if [ -n "$spk" ]; then install -m 644 "$spk" "$PIPELINE_ROOT/spk/$(basename "$spk")"; args+=(--spk "$PIPELINE_ROOT/spk/$(basename "$spk")"); fi
"$P/box-env" "${args[@]}" >/dev/null
. "$PIPELINE_ROOT/box.env"

# --- the lean-ask REPL (pinned to the tip's toolchain) ---
( cd "$SRV/mini" && "$P/lean-ask-install-repl" "$PIPELINE_ROOT/repl" 2>&1 | tail -1 )

# --- enable + (re)start the persistent units (they replace the transient scopes and tmux sessions) ---
want="pipeline-sccache.service pipeline-slots.service"
[ "$role" = gate ] && want="$want pipeline-artifacts.service"; [ "$journeys" = 1 ] && want="$want pipeline-journeys.service"
for u in $want; do systemctl --user enable -q "$u"; systemctl --user restart "$u"; done
sleep 1; for u in $want; do printf '%s: %s\n' "$u" "$(systemctl --user is-active "$u")"; done

# --- gate: the shared remote + its GitHub sync timer; a seed TIPS line ---
if [ "$role" = gate ]; then
  "$P/shared-remote" init 2>&1 | tail -1
  touch "$ARTIFACT_ROOT/TIPS"
fi

# --- briefs: what an agent on this box must read ---
if [ -d "$STAGE/briefs" ]; then rsync -a --delete "$STAGE/briefs/" "$SRV/briefs/"; echo "briefs: $(ls "$SRV/briefs" | wc -l) files in $SRV/briefs"; fi
echo "== user phase DONE $(date -Is)"

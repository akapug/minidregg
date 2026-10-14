#!/usr/bin/env bash
# scripts/pipeline/nightly-burst.sh -- THE BAR, judged where it can be: a dedicated burst box, nothing else on it.
#
#   scripts/pipeline/nightly-burst.sh --host HOST --sha SHA [--boot HOST=ubuntu@IP] [--id nightly-YYYYMMDD]
#                                     [--births N] [--hbox hbox] [--phase up,set,rows,collect]
#
# DRAFT (INTEGRATOR, 2026-10-14). Not launched by anything. Renting the box and deleting it are outward acts:
# Ember okays both, ROOT runs this, and the box is deleted in the provider console after `collect`
# (this script never deletes a box or a resource).
#
# Why a burst box: hbox and persvati are loaded by dev work (load 20-60 measured all day on 10-14), and
# a wall-time verdict there is weather (growth: PASS once, FAIL 3x on the same code). The landing's
# births row is UNCONFIGURED on a busy box (journey-rows row_births); this nightly is where the bar is judged.
#
# Phases:
#   up       scripts/burst/burst-up --id ID --tip SHA --gate HOST --journeys HOST --phase stage,root,user,check
#            (no peer keys, no hbox puller, no warm base: the nightly builds no Lean)
#   set      the READY artifact set for SHA copied from hbox ($ARTIFACT_ROOT/SHA) through this machine to
#            HOST:/srv/artifacts/SHA (built once, on hbox, by publish-artifacts; never rebuilt here), checked
#            against its manifest.json sha256s on arrival
#   rows     on HOST, from SHA's own tree (/srv/mini at SHA, scripts/pipeline/journey-rows), PIPELINE_NIGHTLY=1:
#            births N=1000 (THE BAR: write p99 <= 5 s, cold reopen <= 60 s) and growth (updates, 1000 records),
#            one after the other, nothing else running; box.py quiet must pass before each (a busy burst box
#            is a broken nightly, reported as such, never a verdict)
#   collect  results.tsv + every row's OUT dir + quiet.json + box facts (nproc, CPU model, loadavg series)
#            to hbox:/tank/dregg-build/pipeline/nightly/ID/, then scripts/burst/burst-down --id ID HOST
#            (evidence relay; it never deletes)
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd); repo=$(CDPATH='' cd -- "$here/../.." && pwd)
host="" sha="" id="nightly-$(date -u +%Y%m%d)" births=1000 hbox=hbox phases=up,set,rows,collect boot=()
while [ $# -gt 0 ]; do
  case "$1" in
    --host) host=$2; shift 2 ;; --sha) sha=$2; shift 2 ;; --id) id=$2; shift 2 ;; --births) births=$2; shift 2 ;;
    --hbox) hbox=$2; shift 2 ;; --phase) phases=$2; shift 2 ;; --boot) boot+=(--boot "$2"); shift 2 ;;
    *) echo "nightly-burst: unknown $1" >&2; exit 64 ;;
  esac
done
[ -n "$host" ] && [[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "usage: nightly-burst.sh --host HOST --sha FULL_SHA [...]" >&2; exit 64; }
SSHOPTS=${BURST_SSH_OPTS:-}
rsh() { ssh $SSHOPTS -o BatchMode=yes -o ConnectTimeout=20 "$@"; }
log() { printf '%s nightly-burst %s: %s\n' "$(date -u +%H:%M:%SZ)" "$id" "$*"; }
has() { case ",$phases," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
AR=/tank/dregg-build/pipeline/artifacts; NROOT=/tank/dregg-build/pipeline/nightly/$id

if has up; then
  log "up: burst-up at $sha"
  "$repo/scripts/burst/burst-up" --id "$id" --tip "$sha" --gate "$host" --journeys "$host" "${boot[@]}" \
    --phase stage,root,user,check "$host" || { log "burst-up FAILED"; exit 2; }
fi

if has set; then
  rsh "$hbox" "test -f $AR/$sha/READY" || { log "REFUSED: no READY set for $sha on $hbox (publish-artifacts first)"; exit 3; }
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  rsync -a -e "ssh $SSHOPTS" "$hbox:$AR/$sha/" "$tmp/set/" && rsh "$host" "mkdir -p /srv/artifacts/$sha" \
    && rsync -a -e "ssh $SSHOPTS" "$tmp/set/" "$host:/srv/artifacts/$sha/" || { log "set copy FAILED"; exit 3; }
  rsh "$host" "cd /srv/artifacts/$sha && jq -r '.files[] | \"\(.sha256)  \(.path)\"' manifest.json | sha256sum -c --quiet" \
    || { log "REFUSED: the copied set does not match its manifest"; exit 3; }
  log "set: $sha READY on $host, sha256s match"
fi

if has rows; then
  # one row at a time, quiet before each; the verdict lines are journey-rows' own
  rsh "$host" "bash -s" "$sha" "$births" <<'REMOTE' || { log "rows FAILED to run"; exit 4; }
set -uo pipefail
sha=$1 births=$2
SRC=/srv/mini; cd "$SRC" && git fetch -q origin "$sha" && git checkout -q --detach "$sha"
SET=/srv/artifacts/$sha BIN=$SET/bin MANIFEST=$SET/manifest.json LEANENV=1
HOST=$BIN/minidregg-host MINI=$BIN/mini STORE=$BIN/minidregg-link-sqlite-store VERIFIER=$BIN/minidregg-credential-signature-verifier
export SRC SET BIN MANIFEST LEANENV HOST MINI STORE VERIFIER PIPELINE_NIGHTLY=1 PERF_BIRTHS_N=$births
. "$SRC/scripts/pipeline/journey-rows"
OUTROOT=/srv/nightly/$sha; mkdir -p "$OUTROOT"
for row in births growth; do
  python3 "$SRC/scripts/perf/box.py" quiet "$OUTROOT/$row.quiet.json" 3 0.5 > "$OUTROOT/$row.quiet.out" \
    || { printf '%s\tBROKEN\t0\tthe burst box was not quiet: %s\n' "$row" "$(tail -1 "$OUTROOT/$row.quiet.out")" >> "$OUTROOT/results.tsv"; continue; }
  RUN=$(mktemp -d /tmp/nb.XXXX) OUT=$OUTROOT/$row; mkdir -p "$OUT"; export RUN OUT
  t0=$(date +%s); ( cd "$RUN" && "row_$row" ) > "$OUT/row.out" 2> "$OUT/row.err"; rc=$?; t1=$(date +%s)
  printf '%s\t%s\t%s\t%s\n' "$row" "$([ $rc = 0 ] && echo PASS || echo FAIL)" "$((t1-t0))" "$(tail -1 "$OUT/row.err" | cut -c1-300)" >> "$OUTROOT/results.tsv"
  cat /proc/loadavg >> "$OUTROOT/loadavg.txt"; rm -rf "$RUN"
done
{ nproc; lscpu | grep 'Model name'; uname -r; } > "$OUTROOT/box.txt"
cat "$OUTROOT/results.tsv"
REMOTE
fi

if has collect; then
  tmp=${tmp:-$(mktemp -d)}
  rsync -a -e "ssh $SSHOPTS" "$host:/srv/nightly/$sha/" "$tmp/n/" && rsh "$hbox" "mkdir -p $NROOT" \
    && rsync -a -e "ssh $SSHOPTS" "$tmp/n/" "$hbox:$NROOT/" || { log "collect FAILED"; exit 5; }
  log "results at $hbox:$NROOT/results.tsv:"; rsh "$hbox" "cat $NROOT/results.tsv"
  "$repo/scripts/burst/burst-down" --id "$id" --hbox "$hbox" "$host" || log "burst-down reported a problem (see above)"
  log "done. The box is still up: delete it in the provider console (Ember's act)."
fi

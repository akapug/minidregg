#!/bin/bash
# collect-app-output.sh WORLD.env OUT_DIR [LETTER]: copy a world's resident evidence into OUT_DIR so a red
# says why the app died. Two sources, each best-effort and each named in OUT_DIR/collected.txt:
#   - the resident units' journals (`journalctl --user -u mini-spk-s$STORE-a*`; the operator can read them);
#   - the apps' own stdout and stderr, which sandbox.rs dup2()s onto a ROOT-PRIVATE file
#     app-output-r<volume>-g<generation>.log in the resident's journal directory under $GRAINS_ROOT.
#     Read with `sudo -n` when the caller is not root; skipped, and said so, when sudo is refused.
# Never signals or changes anything; exits 0 whatever it finds.
set -u
[[ $# -ge 2 ]] || { echo "usage: $0 WORLD.env OUT_DIR [LETTER]" >&2; exit 2; }
# shellcheck disable=SC1090
. "$1"; out=$2; tag=${3:-all}
mkdir -p "$out"; note=$out/collected.txt; : >"$note"
for u in $(systemctl --user list-units --all --plain --no-legend "mini-spk-s$STORE-a*.service" 2>/dev/null | awk '{print $1}'); do
  journalctl --user --no-pager -u "$u" >"$out/journal-$u.log" 2>&1 && echo "journal $u" >>"$note"
done
sudo_cmd=(); [[ $(id -u) == 0 ]] || sudo_cmd=(sudo -n)
files=$("${sudo_cmd[@]}" find "$GRAINS_ROOT" -name 'app-output-*.log' 2>/dev/null)
if [[ -z $files ]]; then
  echo "no app-output files readable under $GRAINS_ROOT (root-private; sudo ${sudo_cmd[*]:+refused or }none found)" >>"$note"
else
  n=0; while IFS= read -r f; do
    "${sudo_cmd[@]}" tail -c 20000 "$f" >"$out/$(basename "$f")" 2>/dev/null && { echo "app-output $f" >>"$note"; n=$((n+1)); }
  done <<<"$files"
fi
exit 0

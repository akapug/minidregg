#!/bin/bash
# route-cpu-probe.sh WORLD.env ROUTE_DIR [N]: the serving Host's CPU per request through a grain route.
# ROUTE_DIR is <stateRoot>/apps/<app>/routes/owner-web (it holds http.sock and browser.token), left standing
# by `featured-qualify.sh` (no QUALIFY_STOP). The serving Host is the stdio child of this world's
# `mini serve-operator`; its utime+stime ticks are read from /proc before and after N sequential GETs of /.
# Prints one line per request (wall seconds, Host CPU seconds) and a mean. Published, never a gate.
set -u
[[ $# -ge 2 ]] || { echo "usage: $0 WORLD.env ROUTE_DIR [N]" >&2; exit 2; }
. "$1"; dir=$2; n=${3:-5}
op=$(pgrep -f "serve-operator --host $BIN/minidregg-host" | head -1)   # read-only lookup of this world's operator, never a kill argument
[[ -n $op ]] || { echo "no serve-operator for $BIN" >&2; exit 1; }
host=$(pgrep -P "$op" | head -1)
[[ -n $host ]] || { echo "no serving Host under $op" >&2; exit 1; }
tck=$(getconf CLK_TCK)
ticks() { awk '{print $14+$15}' "/proc/$host/stat"; }
tot=0
for i in $(seq "$n"); do
  a=$(ticks)
  w=$(curl -sS --max-time 120 --unix-socket "$dir/http.sock" -H 'Host: grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")" -H 'Origin: https://grain.test' \
    -o /dev/null -w '%{http_code} %{time_total}' http://grain.test/)
  b=$(ticks); c=$(awk -v a="$a" -v b="$b" -v t="$tck" 'BEGIN{printf "%.2f",(b-a)/t}')
  echo "GET $i: $w s wall, host_cpu=${c}s"; tot=$(awk -v t="$tot" -v c="$c" 'BEGIN{print t+c}')
done
awk -v t="$tot" -v n="$n" 'BEGIN{printf "mean host_cpu per GET: %.2f s over %d\n", t/n, n}'

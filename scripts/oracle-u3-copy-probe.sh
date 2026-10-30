#!/usr/bin/env bash
# Private stopped-Store copy only. start/inspect/stop are separate so the
# same operator process can also be used for a later valid append control.
set -euo pipefail
[ "$#" -eq 4 ] || { echo 'usage: oracle-u3-copy-probe.sh start|inspect|stop FIXTURE_DIR HOST MINI' >&2; exit 2; }
mode=$1 fixture=$2 host=$3 mini=$4
service="$fixture/services"
op="$service/operator.sock"; public="$service/public.sock"
config="$fixture/deployment/qualified-config.json"
identity() { awk '{print $22}' "/proc/$1/stat"; }
stop_one() {
  local name=$1 pid start
  [ -s "$service/$name.pid" ] || return 0
  read -r pid start < "$service/$name.pid"
  if [ -r "/proc/$pid/stat" ] && [ "$(identity "$pid")" = "$start" ]; then
    kill "$pid"
  fi
}
ready() {
  local path=$1 pid=$2 n=0
  until [ -S "$path" ]; do
    kill -0 "$pid" 2>/dev/null || { echo "service exited before binding $path" >&2; return 1; }
    n=$((n+1)); [ "$n" -lt 240 ] || { echo "service socket deadline: $path" >&2; return 1; }
    sleep .25
  done
}
case "$mode" in
 start)
  [ ! -e "$service" ] || { echo 'service directory already exists' >&2; exit 1; }
  mkdir -m 700 "$service"
  trap 'stop_one public; stop_one operator' ERR
  (ulimit -v 12582912; exec nohup nice -n 15 taskset -c 22,23 "$mini" serve-operator --host "$host" --config "$config" --socket "$op" </dev/null >"$service/operator.log" 2>&1) &
  op_pid=$!; printf '%s %s\n' "$op_pid" "$(identity "$op_pid")" > "$service/operator.pid"
  ready "$op" "$op_pid"
  (ulimit -v 12582912; exec nohup nice -n 15 taskset -c 22,23 "$mini" serve-public-proxy --socket "$public" --upstream "$op" --config "$config" </dev/null >"$service/public.log" 2>&1) &
  public_pid=$!; printf '%s %s\n' "$public_pid" "$(identity "$public_pid")" > "$service/public.pid"
  ready "$public" "$public_pid"
  trap - ERR
  echo "private operator and public proxy ready; operator PID $op_pid"
  ;;
 inspect)
  [ -S "$op" ] && [ -S "$public" ] || { echo 'private sockets absent' >&2; exit 1; }
  ulimit -v 12582912
  nice -n 15 taskset -c 22,23 python3 "$fixture/oracle-stop-inspection-probe.py" \
    --host "$host" --config "$config" --operator-socket "$op" --public-socket "$public" \
    --plan "$fixture/stop-plan-v2.bin" --committed "$fixture/committed-v3.bin" \
    --mismatched-committed "$fixture/start-committed-v3.bin" --out "$fixture/probe-a"
  ;;
 stop)
  stop_one public; stop_one operator
  echo 'sent stop to matching recorded fixture service PIDs'
  ;;
 *) echo 'unknown mode' >&2; exit 2;;
esac

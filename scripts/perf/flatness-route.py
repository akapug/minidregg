#!/usr/bin/env python3
"""Law 17: repeat a constant-size GET through a standing SandMD route.

The caller creates and removes the world. All measurement identifies the exact
operator service by its PID file. HTTP errors, missing CPU samples, a restarted
service or a non-growing accepted history fail the run. No process-name lookup.
"""
import argparse
import json
import os
from pathlib import Path
import sys
from flatness import BrokenRun, Commands, ProcessCPU, certify, finish, validate_sizes


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('route', 'pid-file', 'root', 'mini', 'workspace'):
        ap.add_argument('--' + name, required=True, type=Path)
    ap.add_argument('--control', required=True)
    ap.add_argument('--n', type=int, default=1000)
    ap.add_argument('--lo', type=int, default=10)
    a = ap.parse_args()
    validate_sizes(a.n, a.lo)
    root = a.root.resolve()
    root.mkdir(mode=0o700)
    commands, rows = Commands(root / 'transcript'), []
    cpu = ProcessCPU(a.pid_file)
    token = (a.route / 'browser.token').read_text().strip()
    if not token or any(c in token for c in '\r\n'):
        raise BrokenRun('invalid browser token')
    def head(label):
        view = json.loads(commands.run(label, a.mini, 'checkpoint', '--action', 'view',
                                       '--workspace', a.workspace))
        return int(view['head'])
    heads = {'start': head('head-start')}
    with (root / 'samples.jsonl').open('w') as samples:
        for i in range(1, a.n + 1):
            # GET performs admitted dispatch work; certify every 32 requests outside
            # the measured request. The deployed tail bound stays in force.
            if i % 32 == 0:
                certify(commands, a.mini, a.workspace, a.control, f'certify-{i}')
            status, wall, used = commands.measured(
                cpu, f'get-{i}', 'curl', '-sS', '--max-time', '120',
                '--unix-socket', a.route / 'http.sock', '-H', 'Host: grain.test',
                '-H', f'Cookie: __Host-mini_spk_session={token}',
                '-H', 'Origin: https://grain.test', '-o', '/dev/null',
                '-w', '%{http_code}', 'http://grain.test/')
            if status.strip() != '200':
                raise BrokenRun(f'GET {i}: HTTP {status.strip()}')
            row = dict(operation=i, get_cpu_ms=used, get_wall_ms=wall,
                       history_size=head(f'head-{i}'))
            rows.append(row)
            samples.write(json.dumps(row) + '\n'); samples.flush()
            print(json.dumps(row), flush=True)
            if i == a.lo:
                heads['small'] = row['history_size']
    heads['large'] = head('head-large')
    (root / 'heads.json').write_text(json.dumps(heads, indent=2) + '\n')
    if heads['small'] - heads['start'] < a.lo or heads['large'] - heads['small'] < a.n - a.lo:
        raise BrokenRun('GET workload did not accumulate at least one admitted record per request')
    return finish(root, rows, a.n, a.lo, ('get_cpu_ms', 'get_wall_ms'))


if __name__ == '__main__':
    os.umask(0o077)
    try:
        sys.exit(main())
    except (BrokenRun, OSError, ValueError, KeyError) as e:
        print(f'FLATNESS broken: {e}', file=sys.stderr)
        sys.exit(2)

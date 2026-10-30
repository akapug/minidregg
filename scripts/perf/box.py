#!/usr/bin/env python3
"""The workload's box-side helpers (scripts/perf/workload.sh calls them; docs/PERF-WORKLOAD.md).

  box.py quiet OUT.json [WINDOW_S] [THRESHOLD_CORES]
      Sample every process on the box over WINDOW_S (default 3) and call one busy when it used at least
      THRESHOLD_CORES (default 0.5) of a core, excluding this process's own ancestors and, inside a journey
      run, every row scope of the SAME run (journey-runner puts row R of run X in pj-R-X.scope: the
      runner's own parallel rows are not someone else's load). Busy processes are
      grouped by their systemd unit (the cgroup leaf, e.g. a swarm-build scope) and named with their
      command. Writes OUT.json; exit 3 and prints "box not quiet: ..." when anything is busy.

  box.py settings OUT.json BIN_DIR N M K SEED BUDGET ROOT
      The inputs and settings of one run: what it measured with (binary sha256s, the candidate's source
      commit when BIN_DIR/../manifest.json names it), what it fed (N, M, K, seed, the workload scripts' and
      packages' sha256s) and where (host, CPU model, the Store's filesystem). `inputKey` hashes the part two
      runs must share to be compared (everything but the binaries and the time): a comparison tool refuses
      two results whose inputKey differs.

  box.py instructions ROOT PERF_CSV PERF_T0
      Attribute `perf stat -I` interval counts of instructions:u (the workload's whole process tree,
      Host and clients) to the phases in ROOT/phases.tsv; PERF_T0 is the Unix time perf started. Adds an
      `instructions_u` column to ROOT/results.tsv (on each phase's TOTAL line) and to ROOT/summary.json.
"""
import hashlib, json, os, pathlib, subprocess, sys, time

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
TICK = os.sysconf('SC_CLK_TCK')


def proc_cpu():
    out = {}
    for d in pathlib.Path('/proc').iterdir():
        if not d.name.isdigit():
            continue
        try:
            f = (d / 'stat').read_text()
            rest = f[f.rindex(')') + 2:].split()
            out[int(d.name)] = int(rest[11]) + int(rest[12])  # utime + stime
        except (OSError, ValueError, IndexError):
            pass
    return out


def ancestors():
    mine, pid = set(), os.getpid()
    while pid > 1:
        mine.add(pid)
        try:
            f = pathlib.Path(f'/proc/{pid}/stat').read_text()
            pid = int(f[f.rindex(')') + 2:].split()[1])
        except (OSError, ValueError):
            break
    return mine


def describe(pid):
    try:
        cmd = pathlib.Path(f'/proc/{pid}/cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
    except OSError:
        cmd = '?'
    try:
        unit = pathlib.Path(f'/proc/{pid}/cgroup').read_text().splitlines()[0].rsplit('/', 1)[-1]
    except (OSError, IndexError):
        unit = '?'
    return unit, cmd.strip()[:120]


def own_run_suffix():
    """The run id X when this process is inside a journey row scope pj-ROW-X.scope, else None."""
    try:
        leaf = pathlib.Path('/proc/self/cgroup').read_text().splitlines()[0].rsplit('/', 1)[-1]
    except (OSError, IndexError):
        return None
    if leaf.startswith('pj-') and leaf.endswith('.scope'):
        return leaf[:-len('.scope')].rsplit('-', 1)[-1]
    return None


def quiet(out, window=3.0, threshold=0.5):
    mine = ancestors()
    run = own_run_suffix()
    a = proc_cpu()
    t = time.monotonic()
    time.sleep(window)
    b = proc_cpu()
    dt = time.monotonic() - t
    units = {}
    for pid, cpu in b.items():
        if pid in mine or pid not in a:
            continue
        cores = (cpu - a[pid]) / TICK / dt
        if cores < 0.05:
            continue
        unit, cmd = describe(pid)
        if run and unit.startswith('pj-') and unit.endswith(f'-{run}.scope'):
            continue  # a sibling row of this journey run
        u = units.setdefault(unit, {'unit': unit, 'cores': 0.0, 'top': []})
        u['cores'] += cores
        u['top'].append((round(cores, 2), pid, cmd))
    busy = []
    for u in units.values():
        u['cores'] = round(u['cores'], 2)
        u['top'] = sorted(u['top'], reverse=True)[:3]
        if u['cores'] >= threshold:
            busy.append(u)
    busy.sort(key=lambda u: -u['cores'])
    doc = {'window_s': window, 'threshold_cores': threshold, 'busy': busy, 'excludedRun': run,
           'loadavg': pathlib.Path('/proc/loadavg').read_text().split()[:3]}
    pathlib.Path(out).write_text(json.dumps(doc, indent=1) + '\n')
    if busy:
        print('box not quiet: ' + '; '.join(
            f"{u['unit']} {u['cores']} cores ({u['top'][0][2][:60]})" for u in busy[:3]))
        return 3
    return 0


def sha(path):
    try:
        return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
    except OSError:
        return None


def settings(out, bin_dir, n, m, k, seed, budget, root):
    bin_dir = pathlib.Path(bin_dir).resolve()
    binaries = {f: sha(bin_dir / f) for f in ['minidregg-host', 'mini', 'minidregg-link-sqlite-store',
                                              'minidregg-credential-signature-verifier']}
    commit = None
    mf = bin_dir.parent / 'manifest.json'
    if mf.exists():
        try:
            j = json.loads(mf.read_text())
            commit = j.get('sourceCommit') or (j.get('provenance') or {}).get('sourceCommit')
        except (ValueError, AttributeError):
            pass
    scripts = {str(p.relative_to(REPO)): sha(p) for p in [
        HERE / 'workload.py', HERE / 'workload.sh', HERE / 'box.py',
        REPO / 'native/resource-client/activity_world.py', REPO / 'native/resource-client/newparticipant-acceptance.sh',
        REPO / 'native/resource-client/genesis.sh', REPO / 'world/call/Calls.obend', REPO / 'world/send/Sends.obend']}
    parent = pathlib.Path(root).parent
    fs = subprocess.run(['df', '--output=fstype', str(parent)], stdout=subprocess.PIPE, text=True).stdout.split()
    cpu = next((l.split(':', 1)[1].strip() for l in open('/proc/cpuinfo') if l.startswith('model name')), '?')
    inputs = {'births': int(n), 'updates': int(m), 'reads': int(k), 'seed': int(seed), 'scripts': scripts,
              'host': os.uname().nodename, 'cpu': cpu, 'filesystem': fs[-1] if fs else '?'}
    doc = {'type': 'mini-perf-workload-settings-v1', 'inputs': inputs,
           'inputKey': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
           'budgetSeconds': float(budget), 'binaries': binaries, 'sourceCommit': commit,
           'binDir': str(bin_dir), 'startedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    pathlib.Path(out).write_text(json.dumps(doc, indent=1) + '\n')
    return 0


def instructions(root, perf_csv, perf_t0):
    root = pathlib.Path(root)
    t0 = float(perf_t0)
    phases = [(l.split('\t')[0], float(l.split('\t')[1]), float(l.split('\t')[2]))
              for l in (root / 'phases.tsv').read_text().splitlines() if l.strip()]
    per = {p: 0 for p, _, _ in phases}
    seen = 0
    for line in pathlib.Path(perf_csv).read_text().splitlines():
        f = line.split(',')
        if line.startswith('#') or len(f) < 4 or 'instructions' not in line:
            continue
        try:
            at, count = t0 + float(f[0]), int(f[1])   # interval end, relative to perf's start
        except ValueError:
            continue                                   # "<not counted>" / "<not supported>" (an idle core type)
        seen += 1
        for p, s, e in phases:
            if s < at <= e + 0.25:                     # an interval belongs to the phase it ends in
                per[p] += count
                break
    if not seen:
        print('box.py: no instruction intervals in ' + perf_csv, file=sys.stderr)
        return 1
    rows = (root / 'results.tsv').read_text().splitlines()
    out = [rows[0] + '\tinstructions_u']
    for r in rows[1:]:
        f = r.split('\t')
        out.append(r + '\t' + (str(per.get(f[0], '')) if len(f) > 1 and f[1] == 'TOTAL' else ''))
    (root / 'results.tsv').write_text('\n'.join(out) + '\n')
    s = json.loads((root / 'summary.json').read_text())
    s['instructionsU'] = per
    (root / 'summary.json').write_text(json.dumps(s, indent=1) + '\n')
    with open(root / 'table.txt', 'a') as t:
        t.write('instructions:u per phase (Host + clients, perf stat -I): ' +
                ', '.join(f'{p} {per[p] / 1e9:.2f}G' for p, _, _ in phases) + '\n')
    return 0


if __name__ == '__main__':
    verb, args = sys.argv[1], sys.argv[2:]
    if verb == 'quiet':
        sys.exit(quiet(args[0], *(float(x) for x in args[1:3])))
    if verb == 'settings':
        sys.exit(settings(*args))
    if verb == 'instructions':
        sys.exit(instructions(*args))
    raise SystemExit(__doc__)

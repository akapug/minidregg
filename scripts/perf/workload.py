#!/usr/bin/env python3
"""The fixed performance workload: one scratch native Store, every phase timed per operation.

  scripts/perf/workload.py --bin CANDIDATE/bin --root NEW_DIR [--births N] [--updates M] [--reads K]
                           [--seed S] [--budget-s B] [--births-only]

The world is native/resource-client/activity_world.py (the same client path every Objective journey drives:
newparticipant-acceptance.sh genesis with the Objective policy, every turn a signed `mini activity` command).
Phases (docs/PERF-WORKLOAD.md):

  genesis     bring_up: keygen, objective policy, genesis (params.sh fill-genesis + genesis.sh), Host serving
  setup       two package publications (Calls, Sends) and the four fixed objects the call/send phase uses
  births      N Objective objects born: per object a native resource (`workspace create`) and its `create` turn
  updates     M `deposit` invokes over the born objects, round robin (each a plan quote and a submit)
  reads       K current reads (op 214 public view) and K past-state reads (`mini query --view at`) at heights
              spread over the history, below and above the first checkpoint boundary
  checkpoint  every certify (`mini checkpoint --action certify`): the cadence ones that keep the uncertified tail
              under the tail bound (L = 256) and the phase's own one; the history has crossed height 64 by then
  judgment    one cross-object call under a scoped grant (relayA.forward(vault), the vault's law admits only the
              sponsor) and one inbox send (poster.post(sink)) delivered by the second subject
  reopen      stop the Host by its PID file, start it on the same Store, time to the first answered read, then
              one more read

--births-only runs genesis, setup, births and reopen and nothing else (the `births` journey row,
scripts/pipeline/journey-rows: THE BAR is on births and the reopen after them). Cadence certifies keep firing
inside births (N large); their samples print under `checkpoint` even though that phase is not entered.

Inputs are deterministic for a SEED (object order, amounts, read heights); keys and op ids are fresh per run.
Writes ROOT/results.tsv (phase, op, count, p50_ms, p99_ms, max_ms, total_s), ROOT/table.txt, ROOT/summary.json,
and activity_world's ROOT/results.json + ROOT/transcript. Exit 0 iff every phase completed and every turn was
judged as expected; the wall budget (--budget-s) is judged by the caller (scripts/perf/workload.sh).
"""
import argparse, json, os, pathlib, random, signal, subprocess, sys, time

REPO = pathlib.Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'native' / 'resource-client'))
import activity_world as AW  # noqa: E402
from activity_world import World, PERMIT_ALL, TICKS, nat, record, eq, any_of, cap, op_id  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('--bin', required=True)
ap.add_argument('--root', required=True)
ap.add_argument('--births', type=int, default=20)
ap.add_argument('--updates', type=int, default=16)
ap.add_argument('--reads', type=int, default=8)
ap.add_argument('--seed', type=int, default=20261013)
ap.add_argument('--births-only', action='store_true',
                help='genesis, setup, births, reopen only (no updates, reads, checkpoint or judgment phase)')
ap.add_argument('--certify-every', type=int, default=192,
                help='certify when this many records are uncertified (must stay under the tail bound 256)')
a = ap.parse_args()
if a.births < 1 or a.updates < 0 or a.reads < 1:
    raise SystemExit('need --births >= 1, --updates >= 0, --reads >= 1')
PHASES = (['genesis', 'setup', 'births', 'reopen'] if a.births_only else
          ['genesis', 'setup', 'births', 'updates', 'reads', 'checkpoint', 'judgment', 'reopen'])
rng = random.Random(a.seed)

T0 = time.monotonic()
samples = {}          # (phase, op) -> [seconds]
phase_wall = {}       # phase -> seconds
phase_ok = {}         # phase -> bool
order = []            # phases in run order
phase_epochs = {}     # phase -> (start, end) Unix seconds: scripts/perf/box.py attributes instruction counts by them


def timed(phase, op, fn, *args, **kw):
    t = time.monotonic()
    try:
        return fn(*args, **kw)
    finally:
        samples.setdefault((phase, op), []).append(time.monotonic() - t)


class Phase:
    def __init__(self, name):
        self.name = name

    def __enter__(self):
        order.append(self.name)
        self.epoch0 = time.time()
        self.first = len(w.results)
        self.t = time.monotonic()
        self.cm = w.group(self.name)
        self.cm.__enter__()
        return self

    def __exit__(self, *exc):
        swallowed = self.cm.__exit__(*exc)
        phase_wall[self.name] = time.monotonic() - self.t
        phase_epochs[self.name] = (self.epoch0, time.time())
        rows = w.results[self.first:]
        phase_ok[self.name] = bool(rows) and all(r['ok'] for r in rows)
        return swallowed


w = World(a.bin, a.root, REPO)
OUT = w.root
born_at = {}  # resource name -> the acceptedCount its resource was born at
records = {'count': 0, 'certified': 0}   # Host acceptedCount of the newest record; of the newest certify


def note(value):
    c = value.get('acceptedCount') if isinstance(value, dict) else None
    if c is not None:
        records['count'] = max(records['count'], int(c))
    return value


def turn(phase, op, label, workspace, body, expect, detail=None):
    return note(timed(phase, op, w.turn, label, workspace, body, expect, detail))


def certify(phase, label):
    genesis = json.loads((w.W / 'genesis.json').read_text())
    r = timed(phase, 'certify', w.sh, label, w.mini, 'checkpoint', '--action', 'certify', '--workspace', w.sponsor,
              '--control', str(genesis['factoryControllerCapability']), '--min-tail', '1', ok=(0, 1, 2))
    v = w.last_json(r)
    ok = v.get('type') == 'confirmed' and v.get('confirmation') == 'installed'
    w.check(label, ok, {k: v.get(k) for k in ('type', 'confirmation', 'acceptedCount', 'error')})
    if ok:
        note(v)
        records['certified'] = records['count']
    return ok


def maybe_certify(phase, label):
    if records['count'] - records['certified'] >= a.certify_every:
        certify('checkpoint', f'{label}-cadence-certify')


def object_cap(name):
    return w.objects[name]['capability']


def resource(phase, name):
    timed(phase, 'resource', w.sh, f'resource-{name}', w.mini, 'workspace', '--action', 'create', '--dir', w.sponsor,
          '--name', name, '--storage', 'content', '--predicate', w.root / 'permit-all.json')
    ref = json.loads((w.sponsor / 'refs' / f'{name}.json').read_text())
    w.objects[name] = {'object': ref['target'], 'capability': ref['operationCapability']}
    born_at[name] = int(ref['provenance']['birthReceipt']['acceptedCount'])
    records['count'] = max(records['count'], born_at[name])


def create(phase, name, pin, law=PERMIT_ALL, start=0):
    o = w.objects[name]
    body = {'kind': 'create', 'object': o['object'], 'objectCapability': o['capability'], 'pin': pin,
            'stateType': w.TOTAL_STATE, 'law': law, 'upgrade': {'frozen': {}}, 'payer': w.SPONSOR_ACCOUNT,
            'payerCapability': w.SPONSOR_SPEND, 'seed': record(total=nat(start))}
    turn(phase, 'create', f'create-{name}', w.sponsor, body, 'installed')


def invoke_body(name, method, args, grants=None, postage=None):
    body = {'kind': 'invoke', 'object': w.objects[name]['object'], 'objectCapability': object_cap(name),
            'method': method, 'args': args, 'envelope': cap(TICKS), 'account': w.SPONSOR_ACCOUNT,
            'accountCapability': w.SPONSOR_SPEND, 'opId': op_id()}
    if grants is not None:
        body['grants'] = grants
    if postage is not None:
        body['postage'] = cap(postage)
        body['postageLoads'] = 1
    return body


def total(name, label, phase=None, op=None):
    v = timed(phase, op, w.state, name, label) if phase else w.state(name, label)
    return w.total_of(v), v


def query(name, view, height=None, phase=None, op=None):
    """A signed query of NAME's resource (`mini query --workspace`, answered by the serving session: ops 4/5):
    VIEW `resource` (current) or `at` HEIGHT (absolute, K-HISTORY-READ). Returns the query directory
    (challenge.json)."""
    wsd = json.loads((w.sponsor / 'workspace.json').read_text())
    target = str(w.objects[name]['object'])
    req = w.root / 'queries'
    req.mkdir(exist_ok=True)
    purpose = {'type': 'query', 'kind': 'object', 'target': target, 'view': view}
    if height is not None:
        purpose['height'] = str(height)
    intent = {'subject': str(wsd['subject']), 'nonce': str(time.time_ns()), 'purpose': purpose,
              'grants': [{'kind': 'object', 'target': target, 'capability': str(object_cap(name))}]}
    tag = f'{view}-{name}-{height if height is not None else "now"}-{time.time_ns()}'
    f = req / f'{tag}.json'
    f.write_text(json.dumps(intent))
    args = (tag, w.mini, 'query', '--workspace', w.sponsor, '--intent', f, '--view', view, '--dir', req / tag)
    r = timed(phase, op, w.sh, *args, ok=(0, 1, 2, 3)) if phase else w.sh(*args, ok=(0, 1, 2, 3))
    query.last = r
    return req / tag


def query_at(phase, name, height):
    query(name, 'at', height, phase, 'read-at')
    r = query.last
    return r.returncode, r


try:
    born = [f'b{i:04d}' for i in range(a.births)]
    rng.shuffle(born)  # the update and read order is fixed by the seed, not by creation order

    with Phase('genesis'):
        timed('genesis', 'bring-up', w.bring_up, [])
        w.check('genesis-serving', (w.W / 'public' / 'server.pid').exists(), str(w.W))

    with Phase('setup'):
        for n in ['relayA', 'vault', 'poster', 'sink']:
            resource('setup', n)
        CALLS = {'name': 'Calls', 'sourcePath': str(REPO / 'world/call/Calls.obend'), 'imports': []}
        SENDS = {'name': 'Sends', 'sourcePath': str(REPO / 'world/send/Sends.obend'), 'imports': []}
        CPIN, CART = timed('setup', 'publication', w.publication, 'pub-calls', [CALLS], '0', 'deposit')
        SPIN, SART = timed('setup', 'publication', w.publication, 'pub-sends', [SENDS], '0', 'deposit')
        for label, art in (('publish-calls', CART), ('publish-sends', SART)):
            turn('setup', 'publish', label, w.sponsor, dict(art, kind='publish', payer=w.SPONSOR_ACCOUNT,
                                                             payerCapability=w.SPONSOR_SPEND), 'installed')
        w.PIN = CPIN
        create('setup', 'relayA', CPIN)
        create('setup', 'vault', CPIN, law=any_of(eq('request/subject', w.SPONSOR)))
        create('setup', 'poster', SPIN)
        create('setup', 'sink', SPIN)
    height_after_setup = records['count']

    with Phase('births'):
        for i, name in enumerate(sorted(born)):
            maybe_certify('births', name)
            resource('births', name)
            create('births', name, CPIN, start=rng.randrange(0, 1000))

    if not a.births_only:
        with Phase('updates'):
            for i in range(a.updates):
                maybe_certify('updates', f'u{i}')
                name = born[i % len(born)]
                amount = rng.randrange(1, 100)
                turn('updates', 'invoke', f'u{i:04d}-{name}', w.sponsor, invoke_body(name, 'deposit', nat(amount)),
                     'installed')
        height_after_updates = records['count']

        with Phase('reads'):
            picks = [born[rng.randrange(len(born))] for _ in range(a.reads)]
            for i, name in enumerate(picks):
                t, _ = total(name, f'r{i:04d}-{name}', 'reads', 'read-current')
                w.check(f'r{i:04d}-{name}-has-state', t is not None, t)
            # past heights are absolute (genesis height G + log height): G from the current height a query answers at
            probe = query(picks[0], 'resource')
            G = int(json.loads((probe / 'challenge.json').read_text())['height']) - records['count']
            for i, name in enumerate(picks):
                h = G + rng.randrange(born_at[name], records['count'] + 1)   # within the object's life: its grant exists
                rc, r = query_at('reads', name, h)
                w.check(f'at{i:04d}-{name}-h{h}', rc == 0, {'rc': rc, 'err': r.stderr.decode(errors='replace')[-200:]})

        with Phase('checkpoint'):
            w.check('history-crossed-64', records['count'] > 64, records['count'])
            certify('checkpoint', 'phase-certify')

        with Phase('judgment'):
            # call: the vault admits only the sponsor as `request/subject`; a nested frame carries none, so the
            # forward lands only under a scoped grant {vault, deposit, exact 4, 1 use}
            g = {'object': w.objects['vault']['object'], 'method': 'deposit', 'code': CPIN, 'args': {'exact': nat(4)},
                 'uses': '1'}
            hop = record(target=nat(w.objects['vault']['object']), amount=nat(4))
            turn('judgment', 'call-granted', 'call-granted', w.sponsor, invoke_body('relayA', 'forward', hop, grants=[g]),
                 'installed')
            v, _ = total('vault', 'vault-after-call')
            w.check('call-landed', v == 4, v)
            # send: poster.post(sink, 3) queues a message; the second subject delivers it
            post = record(target=nat(w.objects['sink']['object']), amount=nat(3))
            sent = turn('judgment', 'send', 'send-post', w.sponsor, invoke_body('poster', 'post', post, postage=TICKS),
                        'installed')
            mid = (sent.get('report') or {}).get('value')  # the message id is the post's report
            w.check('send-queued', mid is not None, sent.get('report'))
            turn('judgment', 'deliver', 'send-deliver', w.second,
                 {'kind': 'deliverMessage', 'sender': w.objects['poster']['object'], 'target': w.objects['sink']['object'],
                  'message': str(mid)}, 'installed')
            s, _ = total('sink', 'sink-after-deliver')
            w.check('send-delivered', s == 3, s)

    with Phase('reopen'):
        pidfile = w.W / 'public' / 'server.pid'
        pid = int(pidfile.read_text())
        kids = subprocess.run(['pgrep', '-P', str(pid)], stdout=subprocess.PIPE).stdout.split()
        t = time.monotonic()
        os.kill(pid, signal.SIGTERM)
        for p in [pid] + [int(k) for k in kids]:
            for _ in range(600):
                if not pathlib.Path(f'/proc/{p}').exists():
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError(f'process {p} alive 30 s after TERM')
        samples.setdefault(('reopen', 'stop'), []).append(time.monotonic() - t)
        sock = w.sock
        log = w.W / 'public' / 'serve-reopen.log'
        t = time.monotonic()
        with open(log, 'wb') as lf:
            proc = subprocess.Popen([str(w.mini), 'serve', '--host', str(w.host), '--config', str(w.config),
                                     '--socket', str(sock)], stdout=lf, stderr=subprocess.STDOUT,
                                    stdin=subprocess.DEVNULL, start_new_session=True)
        pidfile.write_text(f'{proc.pid}\n')
        probe = born[0]
        polls = 0
        while True:
            if proc.poll() is not None:
                raise RuntimeError(f'server exited on reopen ({log})')
            if sock.exists() and b'serving' in log.read_bytes():
                r = w.sh(f'reopen-probe-{polls}', w.mini, 'activity', '--action', 'view', '--workspace', w.sponsor,
                         '--request', json.dumps({'objects': [w.objects[probe]['object']]}), ok=(0, 1, 2, 3))
                if r.returncode == 0:
                    break
            polls += 1
            if time.monotonic() - t > 600:
                raise RuntimeError('reopen: no answered read within 600 s')
            time.sleep(0.05)
        samples.setdefault(('reopen', 'to-first-read'), []).append(time.monotonic() - t)
        v, _ = total(probe, 'after-reopen', 'reopen', 'read-current')
        w.check('reopen-read-has-state', v is not None, v)
finally:
    w.stop()


def ms(x):
    return f'{x * 1000:.0f}'


def nearest(xs, p):
    xs = sorted(xs)
    return xs[max(0, (len(xs) * p + 99) // 100 - 1)]


total_s = time.monotonic() - T0
rows = []
for ph in order:
    for (p, op), xs in samples.items():
        if p == ph:
            rows.append((ph, op, len(xs), ms(nearest(xs, 50)), ms(nearest(xs, 99)), ms(max(xs)), f'{sum(xs):.2f}'))
    rows.append((ph, 'TOTAL', '', '', '', '', f'{phase_wall.get(ph, 0):.2f}'))
for (p, op), xs in samples.items():   # samples of a phase not entered (cadence certifies under --births-only)
    if p not in order:
        rows.append((p, op, len(xs), ms(nearest(xs, 50)), ms(nearest(xs, 99)), ms(max(xs)), f'{sum(xs):.2f}'))
store_bytes = int(subprocess.run(['du', '-sb', str(w.W / 'store')], stdout=subprocess.PIPE).stdout.split()[0]) \
    if (w.W / 'store').exists() else -1
completed = [p for p in PHASES if phase_ok.get(p)]
missing = [p for p in PHASES if p not in completed]
header = ('phase', 'op', 'count', 'p50_ms', 'p99_ms', 'max_ms', 'total_s')
(OUT / 'phases.tsv').write_text(''.join(f'{p}\t{phase_epochs[p][0]:.3f}\t{phase_epochs[p][1]:.3f}\n'
                                         for p in order if p in phase_epochs))
head = samples.get(('births', 'create'), [])
headline = ({'op': 'births/create', 'count': len(head), 'p50_ms': round(nearest(head, 50) * 1000),
             'p99_ms': round(nearest(head, 99) * 1000), 'max_ms': round(max(head) * 1000)} if head else None)
(OUT / 'results.tsv').write_text('\n'.join('\t'.join(map(str, r)) for r in [header] + rows) + '\n')
summary = {'type': 'mini-perf-workload-v1', 'birthsOnly': a.births_only, 'phases': PHASES, 'births': a.births, 'updates': a.updates, 'reads': a.reads,
           'seed': a.seed, 'records': records['count'], 'objectCount': len(w.objects), 'allTurnsOk': all(r['ok'] for r in w.results), 'storeBytes': store_bytes,
           'totalSeconds': round(total_s, 2), 'phasesCompleted': completed, 'phasesFailed': missing,
           'headline': headline, 'certifyEvery': a.certify_every,
           'host': os.uname().nodename, 'loadavg': open('/proc/loadavg').read().split()[:3]}
(OUT / 'summary.json').write_text(json.dumps(summary, indent=1) + '\n')
lines = [(f'HEADLINE births/create (an Objective object born): n={headline["count"]} p50 {headline["p50_ms"]} ms '
          f'p99 {headline["p99_ms"]} ms max {headline["max_ms"]} ms') if headline else 'HEADLINE births/create: none measured',
         f'{"phase":<11}{"op":<15}{"count":>6}{"p50_ms":>9}{"p99_ms":>9}{"max_ms":>9}{"total_s":>9}']
for r in rows:
    lines.append(f'{r[0]:<11}{r[1]:<15}{r[2]:>6}{r[3]:>9}{r[4]:>9}{r[5]:>9}{r[6]:>9}')
lines.append(f'N={a.births} ' + ('births-only' if a.births_only else f'M={a.updates} K={a.reads}') +
             f' seed={a.seed}: {records["count"]} records, '
             f'{len(w.objects)} objects, store {store_bytes} B, total {total_s:.1f} s; '
             f'phases failed: {",".join(missing) or "none"}')
(OUT / 'table.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))
w.finish(summary)
sys.exit(0 if not missing else 1)

#!/usr/bin/env python3
"""A world/ app admitted on the ACTIVITY route (Route B), on a scratch native world.

  world-activity-admit.py --bin DIR --root NEW_DIR --method FILE.obend --entry NAME
        --birth-input JSON --deposit N [--state-type JSON] [--seed JSON]

World from activity_world.py (this checkout's Objective policy, its ordinary tariff), then:
publication (`objective-publication SPEC activity DIR`), the publish turn, create (the object pins
the package), birth with the declared envelope and deposit, and the object's declared state and
the activity's record read back from the Host's public view. Every step is a signed `mini activity`
command; every outcome is the Host's, by name, recorded in ROOT/results.json and ROOT/transcript.
Steps beyond the birth (deliveries, refusals) are given as --script FILE.json, a list of turns:
  {"label":..., "body": {...} | "deliver": true, "expect": "installed|refused|...", "detail": "..."}
The last line printed is a JSON summary.
"""
import argparse, json, pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import activity_world as aw
from activity_world import World, record, nat, variant

ap = argparse.ArgumentParser()
for f in ['scenario','bin', 'root', 'method', 'entry', 'birth-input', 'deposit', 'state-type', 'seed', 'script', 'ticks']:
    ap.add_argument('--' + f)
a = ap.parse_args()
repo = HERE.parent.parent
w = World(a.bin, a.root, repo)
method = pathlib.Path(a.method).resolve()
ticks = int(a.ticks or aw.TICKS)
def two_object_route(w, a, method):
    """world/call and world/send: objects that pin one package of methods (the call and send kernels, not a
    birth). Mirrors the call and send groups of objective-call-native-journey.py / objective-send-native-journey.py."""
    from activity_world import op_id
    names = ['counter', 'relayA', 'relayB', 'bare'] if a.scenario == 'call' else ['poster', 'counter', 'bare']
    w.bring_up(names)
    pkg = {'name': method.stem, 'sourcePath': str(method), 'imports': []}
    w.PIN, art = w.publication('publication', [pkg], '0', 'deposit')
    w.turn('publish', w.sponsor, dict(art, kind='publish', payer=w.SPONSOR_ACCOUNT, payerCapability=w.SPONSOR_SPEND),
           'installed')
    O = {n: w.objects[n]['object'] for n in names}
    for n in names[:-1]:
        w.create(f'create-{n}', w.sponsor, n, aw.PERMIT_ALL, 'installed', seed=record(total=nat(0)))
    total = lambda n, label: w.total_of(w.state(n, label))
    rep = lambda value: int((value.get('report') or {}).get('value', -1))

    def invoke(label, name, meth, args, expect, detail=None, postage=False):
        body = {'kind': 'invoke', 'object': O[name], 'objectCapability': w.objects[name]['capability'],
                'method': meth, 'args': args, 'envelope': aw.cap(aw.TICKS), 'account': w.SPONSOR_ACCOUNT,
                'accountCapability': w.SPONSOR_SPEND, 'opId': op_id()}
        if postage:
            body['postage'] = aw.cap(aw.TICKS)
            body['postageLoads'] = 1
        return w.turn(label, w.sponsor, body, expect, detail)

    hop = lambda t, amt: record(target=nat(O[t]), amount=nat(amt))
    if a.scenario == 'call':
        with w.group('call'):
            out = invoke('leaf-deposit-5', 'counter', 'deposit', nat(5), 'installed')
            w.check('leaf-report-and-state-5', rep(out) == 5 and total('counter', 'leaf') == 5,
                    {'report': out.get('report'), 'total': total('counter', 'leaf-b')})
            out = invoke('twice-2', 'relayA', 'twice', hop('counter', 2), 'installed')
            # law: a second call in the same turn is shown the first's applied write (5 + 2 + 2)
            w.check('second-callee-sees-first-write', rep(out) == 9 and total('counter', 'twice') == 9,
                    {'report': out.get('report'), 'total': total('counter', 'twice-b')})
            before = total('counter', 'pre-reentry')
            invoke('reentry-refused', 'relayA', 'relay',
                   record(via=nat(O['relayB']), target=nat(O['relayA']), amount=nat(1)), 'charged',
                   ['reentry', str(O['relayA'])])
            w.check('reentry-commits-nothing', total('counter', 'post-reentry') == before and
                    total('relayA', 'post-reentry-a') == 0, {'counter': before})
    else:
        with w.group('send'):
            out = invoke('post-4', 'poster', 'post', hop('counter', 4), 'installed', postage=True)
            m1 = rep(out)
            w.check('queued-not-delivered', total('counter', 'queued') == 0, {'message': m1})
            w.turn('deliver-4', w.second, {'kind': 'deliverMessage', 'sender': O['poster'], 'target': O['counter'],
                                           'message': str(m1)}, 'installed')
            # law: the message is delivered later, by anyone (the second subject), and lands exactly once
            w.check('delivered-lands-once', total('counter', 'delivered') == 4, {'message': m1})
            w.turn('deliver-again-refused', w.second, {'kind': 'deliverMessage', 'sender': O['poster'],
                   'target': O['counter'], 'message': str(m1)}, 'refused')
            invoke('send-to-bare-refused', 'poster', 'post', hop('bare', 1), 'refused', 'notAnObject', postage=True)
    return w.finish({'pin': w.PIN})


try:
    if a.scenario in ('call', 'send'):
        code = two_object_route(w, a, method)
        sys.exit(code)
    w.bring_up(['obj'])
    mod = {'name': method.stem, 'sourcePath': str(method), 'imports': []}
    pin, art = w.publication('publication', [mod], '0', a.entry)
    w.PIN = pin
    pub = {'payer': w.SPONSOR_ACCOUNT, 'payerCapability': w.SPONSOR_SPEND}
    with w.group('publish'):
        w.turn('publish', w.sponsor, dict(art, kind='publish', **pub), 'installed')
    with w.group('create'):
        state_type = json.loads(a.state_type) if a.state_type else None
        seed = json.loads(a.seed) if a.seed else None
        w.create('create', w.sponsor, 'obj', aw.PERMIT_ALL, 'installed', state_type=state_type, seed=seed)
    with w.group('birth'):
        o = w.objects['obj']
        body = {'kind': 'birth', 'object': o['object'], 'objectCapability': o['capability'],
                'account': w.SPONSOR_ACCOUNT, 'accountCapability': w.SPONSOR_SPEND, 'pin': pin,
                'input': json.loads(a.birth_input), 'envelope': aw.cap(ticks), 'resume': aw.cap(ticks),
                'timeout': aw.cap(ticks), 'deposit': str(a.deposit)}
        tx = w.turn('birth', w.sponsor, body, 'installed').get('transaction')
        v = w.state('obj', 'born', tx)
        w.born = v
        print(json.dumps({'record': v.get('record'), 'state': v.get('state'), 'purse': v.get('purse'),
                          'height': v.get('height')})[:1500])
    if a.scenario == 'tally':
        # Tally law (world/activity/Tally.obend): a reply of `amount` is an ADD to the state the activity was
        # resumed with; only the named decider may decide the slot; each delivery advances the generation.
        total = World.total_of
        rec = v['recordCell']
        with w.group('tally'):
            w.check('born-awaiting-total-0', total(v) == 0 and v['record'].get('phase', {}).get('kind') == 'awaiting',
                    {'state': v.get('state'), 'phase': v['record'].get('phase')})
            cur = v
            for rnd, amount in enumerate([5, 7], start=1):
                slot = World.await_of(cur)['source']['slot']
                if rnd == 1:
                    w.turn('stranger-resolve-refused', w.sponsor,
                           {'kind': 'resolve', 'slot': slot, 'answer': {'reply': record(amount=nat(amount))}},
                           'refused', 'notDecider')
                w.turn(f'resolve-{amount}', w.second, {'kind': 'resolve', 'slot': slot,
                       'answer': {'reply': record(amount=nat(amount))}}, 'installed')
                w.turn(f'deliver-{amount}', w.sponsor, {'kind': 'deliver', 'record': rec, 'await': World.await_of(cur)['id'],
                       'account': '0', 'accountCapability': '0'}, 'installed')
                cur = w.state('obj', f'after-{amount}', tx)
                print(json.dumps({'round': rnd, 'total': total(cur), 'generation': cur['record'].get('generation'),
                                  'height': cur.get('height')}))
            w.check('replies-add-never-overwrite', total(cur) == 12 and cur['record'].get('generation') == '2',
                    {'total': total(cur), 'generation': cur['record'].get('generation')})
    code = w.finish({'pin': pin, 'height': (w.totals[-1] if w.totals else {}).get('height')})
finally:
    w.stop()
sys.exit(code)

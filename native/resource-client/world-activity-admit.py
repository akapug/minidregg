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
try:
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

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
DUES_AMOUNT = 200000000
PAID_STATE = {'tag': 'field', 'name': 'paid', 'member': {'tag': 'natural'}, 'tail': {'tag': 'emptyRow'}}


def field_of(state, name):
    """A natural field of a record datum (None when absent)."""
    if not state or state.get('tag') != 'record':
        return None
    value = next((f['value'] for f in state.get('fields', []) if f.get('name') == name), {})
    return int(value['value']) if value.get('tag') == 'natural' else None


def source_of(v):
    return World.await_of(v).get('source', {})


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
    if a.scenario == 'effect':
        # world/activity/Effects.obend: commit {total: set 5}, then transfer 1 to the second subject's account
        a.birth_input = json.dumps(record(init=variant('set', nat(5)), to=nat(int(w.SECOND)), amount=nat(1)))
    if a.scenario == 'dues':
        # world/dues/StandingDues.obend: the payer is the sponsor (it funds the purse), the room the second
        # subject's account; one period's amount is more than half the deposit, so the purse pays it once and
        # the kernel refuses the second (`unfunded`): the period stays owed.
        a.birth_input = json.dumps(record(
            terms=record(payer=nat(int(w.SPONSOR_ACCOUNT)), room=nat(int(w.SECOND)), amount=nat(DUES_AMOUNT),
                         period=nat(10), start=nat(0), periods=nat(4), window=nat(3), lease={'tag': 'boolean', 'value': False}),
            deposit=nat(int(a.deposit)), keeper=nat(int(w.SECOND)), fresh={'tag': 'boolean', 'value': True}))
        a.state_type = a.state_type or json.dumps(PAID_STATE)
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
    if a.scenario == 'effect':
        # The statement's poles natively: an effect Plan is decided AT its yield. Satisfiable: the birth's commit is
        # performed (`settled`, total 5); the delivery's transfer of 1 is performed (the second subject's balance
        # rises by exactly 1, the write lands). Teeth: a transfer far above the purse is refused `unfunded`, one to
        # the collector `reserved`; each moves nothing and writes nothing (balance and state version unchanged).
        rec, bal = v['recordCell'], World.balance
        deliver = lambda label, cur, tx_rec: w.turn(label, w.sponsor, {'kind': 'deliver', 'record': tx_rec,
                                                    'await': World.await_of(cur)['id'], 'account': '0',
                                                    'accountCapability': '0'}, 'installed')
        with w.group('effect-satisfiable'):
            w.check('commit-performed-at-birth', source_of(v) == {'kind': 'performed', 'verdict': 'settled', 'reason': None}
                    and World.total_of(v) == 5, {'source': source_of(v), 'state': v.get('state')})
            second0 = bal(v, w.SECOND)
            deliver('deliver-commit', v, rec)
            v1 = w.state('obj', 'after-transfer', tx)
            w.check('transfer-performed-moves-exactly-1',
                    source_of(v1) == {'kind': 'performed', 'verdict': 'settled', 'reason': None}
                    and bal(v1, w.SECOND) == second0 + 1 and World.total_of(v1) == 6,
                    {'source': source_of(v1), 'second': [second0, bal(v1, w.SECOND)], 'state': v1.get('state')})
            deliver('deliver-transfer', v1, rec)
        for name, to, amount, reason in [('unfunded', int(w.SECOND), 10 ** 15, 'unfunded'),
                                         ('reserved', int(w.COLLECTOR), 1, 'reserved')]:
            with w.group(f'effect-teeth-{name}'):
                body = {'kind': 'birth', 'object': o['object'], 'objectCapability': o['capability'],
                        'account': w.SPONSOR_ACCOUNT, 'accountCapability': w.SPONSOR_SPEND, 'pin': pin,
                        'input': record(init=variant('add', nat(0)), to=nat(to), amount=nat(amount)),
                        'envelope': aw.cap(ticks), 'resume': aw.cap(ticks), 'timeout': aw.cap(ticks),
                        'deposit': str(a.deposit)}
                t2 = w.turn(f'birth-{name}', w.sponsor, body, 'installed').get('transaction')
                b = w.state('obj', f'born-{name}', t2)
                deliver(f'deliver-commit-{name}', b, b['recordCell'])
                after = w.state('obj', f'refused-{name}', t2)
                w.check(f'transfer-refused-{reason}-moves-nothing',
                        source_of(after) == {'kind': 'performed', 'verdict': 'refused', 'reason': reason}
                        and bal(after, w.SECOND) == bal(b, w.SECOND) and bal(after, w.COLLECTOR) >= bal(b, w.COLLECTOR)
                        and after.get('stateVersion') == b.get('stateVersion'),
                        {'source': source_of(after), 'second': [bal(b, w.SECOND), bal(after, w.SECOND)],
                         'version': [b.get('stateVersion'), after.get('stateVersion')]})
    if a.scenario == 'dues':
        # Dues law (world/dues/StandingDues.obend) natively: period k is paid once, in order, exactly `amount`,
        # FROM THE PURSE to the room, decided by the kernel at the transfer's yield; a payment the purse cannot
        # cover is refused by name (`unfunded`) and the period stays owed; a replayed period pays nothing.
        rec, bal = v['recordCell'], World.balance
        resolve = lambda label, cur, event: w.turn(label, w.second, {'kind': 'resolve', 'slot': source_of(cur)['slot'],
                                                    'answer': {'reply': event}}, 'installed')
        deliver = lambda label, cur: w.turn(label, w.sponsor, {'kind': 'deliver', 'record': rec,
                                            'await': World.await_of(cur)['id'], 'account': '0',
                                            'accountCapability': '0'}, 'installed')
        discharge = lambda period, now: variant('discharge', record(period=nat(period), now=nat(now)))
        with w.group('dues'):
            w.check('born-awaiting-the-keeper-ledger-0', source_of(v).get('kind') == 'reply'
                    and field_of(v.get('state'), 'paid') == 0, {'source': source_of(v), 'state': v.get('state')})
            room0 = bal(v, w.SECOND)
            resolve('discharge-0', v, discharge(0, 0))
            deliver('deliver-discharge-0', v)
            v1 = w.state('obj', 'paid-0', tx)
            w.check('period-0-paid-exactly-amount-from-the-purse',
                    source_of(v1) == {'kind': 'performed', 'verdict': 'settled', 'reason': None}
                    and bal(v1, w.SECOND) == room0 + DUES_AMOUNT and field_of(v1.get('state'), 'paid') == DUES_AMOUNT,
                    {'source': source_of(v1), 'room': [room0, bal(v1, w.SECOND)], 'state': v1.get('state'),
                     'purse': [v.get('purse'), v1.get('purse')]})
            deliver('deliver-settled-0', v1)
            v2 = w.state('obj', 'awaiting-1', tx)
            resolve('replay-0', v2, discharge(0, 5))
            deliver('deliver-replay-0', v2)
            v3 = w.state('obj', 'replay-refused', tx)
            w.check('replayed-period-pays-nothing', source_of(v3).get('kind') == 'reply'
                    and bal(v3, w.SECOND) == room0 + DUES_AMOUNT, {'source': source_of(v3), 'room': bal(v3, w.SECOND)})
            resolve('discharge-1', v3, discharge(1, 10))
            deliver('deliver-discharge-1', v3)
            v4 = w.state('obj', 'unfunded-1', tx)
            w.check('period-1-refused-unfunded-moves-nothing',
                    source_of(v4) == {'kind': 'performed', 'verdict': 'refused', 'reason': 'unfunded'}
                    and bal(v4, w.SECOND) == room0 + DUES_AMOUNT and field_of(v4.get('state'), 'paid') == DUES_AMOUNT,
                    {'source': source_of(v4), 'room': bal(v4, w.SECOND), 'state': v4.get('state'), 'purse': v4.get('purse')})
            deliver('deliver-refused-1', v4)
            v5 = w.state('obj', 'still-owed-1', tx)
            w.check('period-1-still-owed-awaiting', source_of(v5).get('kind') == 'reply', {'source': source_of(v5)})
    code = w.finish({'pin': pin, 'height': (w.totals[-1] if w.totals else {}).get('height')})
finally:
    w.stop()
sys.exit(code)

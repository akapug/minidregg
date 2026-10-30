#!/usr/bin/env python3
"""Law 17: fixed-size document appends at small and large accumulated state.

Measures the whole mini-serve process tree (including reaped helpers), and end-to-end
wall time. Both submit and propose gate. Certification uses the normal admitted
checkpoint path so the default 1,000 operations do not hit the 256-record tail law.
Exit 0 PASS, 1 FAIL, 2 broken/incomplete. Outputs samples.jsonl and result.json.
"""
import argparse
import json
import os
from pathlib import Path
import sys
from flatness import BrokenRun, Commands, ProcessCPU, certify, failure_prefix, finish, validate_sizes


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('bin', 'root', 'src'):
        ap.add_argument('--' + name, required=True, type=Path)
    ap.add_argument('--n', type=int, default=1000)
    ap.add_argument('--lo', type=int, default=10)
    a = ap.parse_args()
    validate_sizes(a.n, a.lo)
    root, binary, src = a.root.resolve(), a.bin.resolve(), a.src.resolve()
    root.mkdir(mode=0o700)  # An existing world's data is never reused or removed.
    commands = Commands(root / 'transcript')
    mini = binary / 'mini'
    os.environ['CANDIDATE'] = str(binary.parent)
    # This measures a fresh world, including genesis, rather than a template's prefix.
    os.environ['NEWPARTICIPANT_TEMPLATE_DIR'] = ''
    os.environ['MINI_CONSENT_ANCHOR_DIR'] = str(root / 'a')
    os.environ['NEWPARTICIPANT_SPONSOR_BALANCE'] = '1000000000'
    os.environ['NEWPARTICIPANT_OWNER_BUDGET'] = '1000000000'
    os.environ['NEWPARTICIPANT_METER_ALLOWANCE'] = '1000000000000'
    metrics = ('submit_cpu_ms', 'submit_wall_ms', 'propose_cpu_ms', 'propose_wall_ms')
    w, rows, cpu = root / 'w', [], None
    try:
        commands.run('genesis', 'sh', src / 'native/resource-client/newparticipant-acceptance.sh',
                     binary / 'minidregg-host', mini, binary / 'minidregg-link-sqlite-store',
                     binary / 'minidregg-credential-signature-verifier', w, w / 'public/mini.sock')
        cpu = ProcessCPU(w / 'public/server.pid')
        sponsor = w / 'sponsor'
        control = str(json.loads((w / 'genesis.json').read_text())['factoryControllerCapability'])
        law = {'type': 'any', 'predicates': [
            {'type': 'memberOf', 'slot': 'request/verb', 'values': ['1', '3', '4', '5']},
            {'type': 'all', 'predicates': [
                {'type': 'eq', 'slot': 'request/verb', 'value': '2'},
                {'type': 'le', 'slot': 'content/payload-bytes/after', 'value': str(128*a.n+65536)}]}]}
        (root / 'law.json').write_text(json.dumps(law))
        commands.run('doc-new', mini, 'workspace', '--action', 'doc-new', '--dir', sponsor,
                     '--name', 'paper', '--predicate', root / 'law.json')
        with (root / 'samples.jsonl').open('w') as samples:
            for i in range(1, a.n + 1):
                if i % 96 == 0:
                    certify(commands, mini, sponsor, control, f'certify-{i}')
                label = f'a{i}'
                request = {'type': 'minidregg-workspace-proposal-v1', 'action': 'invoke', 'targets': [
                    {'name': 'paper', 'payload': {'type': 'document', 'actions': [
                        {'type': 'append', 'text': 'paragraph ' + 'x'*32}]}}]}
                req_file = root / (label + '.json')
                req_file.write_text(json.dumps(request))
                row = {'operation': i}
                for step, args in (
                    ('propose', ['--request', req_file, '--proposal-id', label]),
                    ('submit', ['--intent', sponsor / 'proposals' / label / 'intent.json',
                                '--attempt', sponsor / 'attempts' / label])):
                    _, wall, used = commands.measured(cpu, label + '-' + step, mini, 'workspace',
                                                      '--action', step, '--dir', sponsor, *args)
                    row[step + '_wall_ms'], row[step + '_cpu_ms'] = wall, used
                outcome = json.loads((sponsor / 'attempts' / label / 'outcome.json').read_text())
                if outcome.get('type') != 'confirmed' or outcome.get('confirmation') != 'installed':
                    raise BrokenRun(f'{label}: append not installed')
                row['history_size'] = int(outcome['acceptedCount'])
                rows.append(row)
                samples.write(json.dumps(row) + '\n'); samples.flush()
                print(json.dumps(row), flush=True)
                if failure_prefix(rows, a.n, a.lo, metrics):
                    return finish(root, rows, len(rows), a.lo, metrics, requested_n=a.n)
        return finish(root, rows, a.n, a.lo, metrics)
    finally:
        if cpu is not None:
            cpu.stop()
        elif (w / 'public/server.pid').exists():
            ProcessCPU(w / 'public/server.pid').stop()
        if (root / 'a').exists():
            commands.run('stop-residents', 'bash', src / 'scripts/spk-platform/stop-residents.sh', root)


if __name__ == '__main__':
    os.umask(0o077)
    try:
        sys.exit(main())
    except (BrokenRun, OSError, ValueError, KeyError) as e:
        print(f'FLATNESS broken: {e}', file=sys.stderr)
        sys.exit(2)

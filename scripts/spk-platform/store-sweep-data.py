#!/usr/bin/env python3
"""Sweep bookkeeping only. Mini's grain journey owns admission and lifecycle semantics."""
import csv
import datetime
import io
import json
from pathlib import Path
import sys

PROTOCOL = 'mini-store-qualification-v1'
SCOPE = 'install-share-start-enroll-get-root'
LETTERS = 'jklmnop'  # grain-journey.sh's market coordinates 61..67


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.new')
    tmp.write_text(text)
    tmp.replace(path)


def records(out, candidate):
    return [r for p in sorted((out/'records').glob('*.json'))
            if (r := json.loads(p.read_text()))['candidate'] == candidate]


def batches(apps, out, candidate, size, retry=None):
    if not 1 <= size <= len(LETTERS):
        raise ValueError('batch size must be 1..7 (grain-journey market letters j..p)')
    done = {(r['appId'], r['packageId']) for r in records(out, candidate)
            if not (r['verdict'] == 'FAIL' and r['stage'] == retry)}
    todo = [a for a in apps if (a['appId'], a['packageId']) not in done]
    return [todo[i:i+size] for i in range(0, len(todo), size)]


def profile(raw, decoded, raw_limit, decoded_limit):
    return 'market-large-v1' if raw > raw_limit or decoded > decoded_limit else 'standard-v1'


def retry_stage(out, candidate, stage):
    archive = out/'records'/'history'/datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%f')
    for path in sorted((out/'records').glob('*.json')):
        row = json.loads(path.read_text())
        if row['candidate'] == candidate and row['verdict'] == 'FAIL' and row['stage'] == stage:
            archive.mkdir(parents=True, exist_ok=True)
            path.replace(archive/path.name)
    publish(out, candidate)


def publish(out, candidate):
    rows = records(out, candidate)
    summary = dict(protocol=PROTOCOL, scope=SCOPE, candidate=candidate,
                   counts={v: sum(r['verdict'] == v for r in rows) for v in ('PASS', 'FAIL')}, apps=rows)
    atomic(out/'qualification.json', json.dumps(summary, indent=2) + '\n')
    columns = ['candidate', 'appId', 'packageId', 'name', 'verdict', 'stage', 'reason',
               'evidence', 'importProfile', 'rawBytes', 'decodedBytes', 'checkedAt']
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter='\t', lineterminator='\n')
    writer.writerow(columns)
    for row in rows:
        writer.writerow([str(row[k]).replace('\t', ' ').replace('\r', ' ').replace('\n', ' ') for k in columns])
    atomic(out/'verdicts.tsv', buf.getvalue())


def record(out, candidate, app, verdict, stage, reason, evidence, import_profile, raw, decoded):
    if verdict not in ('PASS', 'FAIL') or (verdict == 'PASS' and stage != 'get'):
        raise ValueError('PASS requires the completed GET stage; verdict must be PASS or FAIL')
    row = dict(candidate=candidate, appId=app['appId'], packageId=app['packageId'], name=app['name'],
               verdict=verdict, stage=stage, reason=reason, evidence=evidence,
               importProfile=import_profile, rawBytes=raw, decodedBytes=decoded,
               checkedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
    atomic(out/'records'/f"{candidate}-{app['packageId']}.json", json.dumps(row) + '\n')
    publish(out, candidate)


if __name__ == '__main__':
    action, *args = sys.argv[1:]
    if action == 'plan':
        index, out, candidate, size, maximum, retry = args
        apps = json.loads(Path(index).read_text())['apps']
        # The native index-check validates real runs. Dry runs still refuse unsafe IDs and duplicates.
        import re
        seen = set()
        for a in apps:
            if not re.fullmatch('[0-9a-f]{32}', a['packageId']) or a['packageId'] in seen:
                raise ValueError('invalid or duplicate packageId')
            seen.add(a['packageId'])
        plan = batches(apps, Path(out), candidate, int(size), retry)
        if int(maximum):
            plan = plan[:int(maximum)]
        for batch in plan:
            print(json.dumps([dict(a, letter=l) for l, a in zip(LETTERS, batch)]))
    elif action == 'record':
        out, candidate, entry, verdict, stage, reason, evidence, p, raw, decoded = args
        record(Path(out), candidate, json.loads(entry), verdict, stage, reason, evidence, p, int(raw), int(decoded))
    elif action == 'publish':
        publish(Path(args[0]), args[1])
    elif action == 'profile':
        print(profile(*map(int, args)))
    elif action == 'retry-stage':
        retry_stage(Path(args[0]), args[1], args[2])
    else:
        raise SystemExit(f'unknown action: {action}')

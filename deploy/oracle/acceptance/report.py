#!/usr/bin/env python3
"""Untrusted acceptance assertions, not a Mini semantic or admission engine.

Reads retained native receipts, Linux mount observations and HTTP reply bytes.
A passing report is emitted only when every assertion passes. It does not score
Oracle's specialist panels or assert that returned answers are formally proved.
"""
import hashlib
import json
import math
import re
from pathlib import Path
import sys


def read(path):
    return json.loads(path.read_bytes())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mount_rows(directory):
    result = []
    for path in sorted(directory.glob('*.txt')):
        for line in path.read_text().splitlines():
            fields = line.split()
            if len(fields) >= 10 and fields[4] in ('/opt/oracle-data', '/var'):
                result.append({'pid': path.stem, 'device': fields[2],
                               'root': fields[3], 'target': fields[4],
                               'options': fields[5].split(',')})
    return result


def main():
    run, inventory_sha = Path(sys.argv[1]), sys.argv[2]
    ev = run / 'world/evidence'
    checks = {}

    def require(name, condition):
        checks[name] = bool(condition)
        if not condition:
            raise AssertionError(name)

    replies = {}
    for label in ('a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12', 'a13', 'a14', 'b1', 'b2'):
        path = ev / f'post-{label}-body.body'
        value = read(path)
        replies[label] = {'sha256': sha(path), 'bytes': path.stat().st_size,
                          'status': value.get('reply', {}).get('status'),
                          'path': value.get('reply', {}).get('path'),
                          'refusal': value.get('reply', {}).get('refusal'),
                          'response': value.get('reply', {}).get('response', '')}
    require('whitman', replies['a1']['status'] == 'answered' and 'Whitman' in replies['a1']['response'])
    require('austen', replies['a2']['status'] == 'answered' and 'Austen' in replies['a2']['response'])
    require('followup_1775', replies['a3']['status'] == 'answered'
            and '16 December 1775 (Gregorian calendar)' in replies['a3']['response']
            and 'unavailable' not in replies['a3']['response'].lower())
    require('isa_minus_4_5', replies['a4']['status'] == 'answered' and '-4.5' in replies['a4']['response'])
    require('invalid_altitude_units_refused', replies['a5']['status'] in ('withheld', 'clarification')
            and '-4.5' not in replies['a5']['response'])
    require('two_grains_same_ids_distinct_answers', replies['b1']['status'] == 'answered'
            and 'Austen' in replies['b1']['response']
            and replies['b1']['sha256'] != replies['a1']['sha256'])
    require('first_grain_unchanged_by_second', replies['a1']['sha256'] == replies['a6']['sha256'])
    require('restart_exact_reply', replies['a1']['sha256'] == replies['a7']['sha256'])
    require('restart_exact_followup', replies['a3']['sha256'] == replies['a8']['sha256'])
    require('second_grain_unchanged_by_restart', replies['b1']['sha256'] == replies['b2']['sha256'])
    mars = re.search(r'([0-9]+(?:\.[0-9]+)?)\s+Earth years', replies['a9']['response'])
    require('supplied_mars_periods_preserved', replies['a9']['status'] == 'answered' and mars is not None
            and math.isclose(float(mars.group(1)), 3 * 687 / 365.25, rel_tol=1e-9))
    require('shakespeare_month_precision', replies['a10']['status'] == 'answered'
            and 'April 1564' in replies['a10']['response']
            and 'day unspecified' in replies['a10']['response']
            and not re.search(r'\b[0-9]{1,2} April 1564', replies['a10']['response']))
    require('salinger_real_first_day', replies['a11']['status'] == 'answered'
            and '1 January 1919' in replies['a11']['response']
            and 'day unspecified' not in replies['a11']['response'])
    require('salinger_carter_order_uses_source_dates', replies['a12']['status'] == 'answered'
            and replies['a12']['response'].startswith('[ev:derived] J. D. Salinger.')
            and '1 January 1919 (Gregorian calendar)' in replies['a12']['response']
            and '1 October 1924 (Gregorian calendar)' in replies['a12']['response']
            and 'by 58 years' not in replies['a12']['response'])
    require('shakespeare_newton_order_preserves_month_precision', replies['a13']['status'] == 'answered'
            and replies['a13']['response'].startswith('[ev:derived] William Shakespeare.')
            and 'April 1564 (Julian calendar; day unspecified)' in replies['a13']['response']
            and '25 December 1642 (Julian calendar)' in replies['a13']['response']
            and 'by 104 years' not in replies['a13']['response'])
    require('uncertain_birth_order_terminal_refusal', replies['a14']['status'] == 'withheld'
            and replies['a14']['path'] == 'composed>date_order_unverified'
            and isinstance(replies['a14']['refusal'], dict)
            and replies['a14']['refusal'].get('terminal') is True
            and replies['a14']['refusal'].get('reason') == 'date_order_unverified')
    require('inventory_bytes_pinned', sha(run / 'inventory.json') == inventory_sha)
    publication = read(run / 'publication.json')
    require('published_exact_inventory', publication.get('inventory_sha256') == inventory_sha)
    operator_import = read(run / 'import-profile.json')
    selected_profile = operator_import['selected_profile']

    configs, mounts, native_receipts = {}, {}, {}
    for app in ('9101', '9201'):
        directory = run / 'receiving' / app
        configs[app] = [read(p) for p in sorted(directory.glob('g*/resident.json'))]
        require(f'grain_{app}_native_configs', bool(configs[app]))
        completion = read(directory / 'install-completed-v2.json')
        require(f'grain_{app}_native_install_completed',
                completion.get('protocol') == 'mini-spk-install-completed-v2'
                and completion.get('rawSha256') == configs[app][0]['expectedRawSha256']
                and bool(completion.get('completionReceipt', {}).get('eventId')))
        require(f'grain_{app}_imported_under_selected_profile',
                read(directory / 'import-policy.json') == {'profile': selected_profile})
        maps = list((directory / 'namespaces').glob('*.uid_map'))
        for mapping in maps:
            rows = [tuple(map(int, line.split())) for line in mapping.read_text().splitlines()]
            require(f'grain_{app}_{mapping.stem}_host_root_unmapped', bool(rows)
                    and all(outside != 0 for inside, outside, count in rows))
        require(f'grain_{app}_actual_namespace_observed', bool(maps))
        attachment = read(directory / 'minidregg-data.json')
        require(f'grain_{app}_signed_data_declaration', attachment == {
            'schema': 'minidregg-public-data-v1', 'inventory_sha256': inventory_sha})
        mounts[app] = mount_rows(directory / 'mounts')
        data_mounts = [m for m in mounts[app] if m['target'] == '/opt/oracle-data']
        require(f'grain_{app}_read_only_data_mounted', bool(data_mounts)
                and all('ro' in m['options'] for m in data_mounts))
        require(f'grain_{app}_mount_exact_inventory', all(
            m['root'].endswith(f'/sha256-{inventory_sha}/data') for m in data_mounts))
        native_receipts[app] = [{'file': str(p.relative_to(run)), 'sha256': sha(p)}
                               for p in sorted(directory.glob('g*/*completed*.json'))]
        require(f'grain_{app}_native_start_completion', bool(native_receipts[app]))
    require('restart_keeps_runtime_and_var', len(configs['9101']) >= 2
            and len({c['expectedRawSha256'] for c in configs['9101']}) == 1
            and len({c['persistentVar'] for c in configs['9101']}) == 1)
    require('both_grains_same_signed_runtime', len({c['expectedRawSha256']
            for cs in configs.values() for c in cs}) == 1)
    require('separate_var_paths', configs['9101'][0]['persistentVar'] != configs['9201'][0]['persistentVar'])
    data = {app: {(m['device'], m['root']) for m in rows if m['target'] == '/opt/oracle-data'}
            for app, rows in mounts.items()}
    require('same_physical_data_mount', len(data['9101']) == 1 and data['9101'] == data['9201'])
    vars_ = {app: {(m['device'], m['root']) for m in rows if m['target'] == '/var'}
             for app, rows in mounts.items()}
    require('separate_physical_var_mounts', bool(vars_['9101']) and bool(vars_['9201'])
            and vars_['9101'].isdisjoint(vars_['9201']))
    refusals = {}
    for label in ('missing-data', 'wrong-data'):
        before, after = read(run / f'{label}-before.json'), read(run / f'{label}-after.json')
        stable = lambda s: [r for r in s['runs'] if r['state'] != 'never-begun']
        require(f'{label}_lifecycle_unchanged', stable(before) == stable(after))
        require(f'{label}_no_running_or_uncertain', all(r['state'] in ('stopped', 'never-begun') for r in after['runs']))
        code = int((run / f'{label}.exit').read_text())
        require(f'{label}_prompt_refusal', code not in (0, 124))
        journal = (run / f'{label}.unit.log').read_text()
        require(f'{label}_signed_dataset_custody_refusal',
                f'signed public-data {inventory_sha} custody refused:' in journal)
        if label == 'wrong-data':
            require('wrong-data_inventory_mismatch_cause',
                    'published inventory differs from signed attachment digest' in journal)
        else:
            require('missing-data_catalog_absent_cause',
                    f'signed public-data {inventory_sha} custody refused: '
                    'No such file or directory (os error 2)' in journal)
        refusals[label] = {'exit': code, 'stderr': (run / f'{label}.stderr').read_text()[-8192:],
                           'unit_journal': journal[-8192:]}
    import_units = {}
    for line in (run / 'import-units.jsonl').read_text().splitlines():
        item = json.loads(line)
        unit, message = item.get('USER_UNIT', ''), item.get('MESSAGE', '')
        if not unit.startswith('mini-spk-ingest-'):
            continue
        record = import_units.setdefault(unit, {'timestamps': [], 'failed': False,
                                               'started': False, 'finished': False})
        record['timestamps'].append(int(item['__MONOTONIC_TIMESTAMP']))
        selected = re.search(r'--import-profile ([a-z0-9-]+)', message)
        if selected:
            record['profile'] = selected.group(1)
        if 'Failed with result' in message:
            record['failed'] = True
        if message.startswith(f'Started {unit} '):
            record['started'] = True
        if message.startswith(f'{unit}: Consumed '):
            record['finished'] = True
    for record in import_units.values():
        stamps = record.pop('timestamps')
        record['observed_elapsed_seconds'] = (max(stamps) - min(stamps)) / 1_000_000
    # Type=exec logs no explicit successful exit at this journal level. A finished
    # nonfailed unit is therefore combined with the exact native install
    # completion and materializer's retained policy checks above.
    require('selected_importer_completed_with_native_install', any(
        record.get('profile') == selected_profile and record['started']
        and record['finished'] and not record['failed']
        for record in import_units.values()))
    report = {'schema': 'mini-oracle-shared-data-acceptance-v1', 'passed': True,
              'scope': 'Private Linux Store; real Mini install/share/enrollment/dispatch and sandbox. '
                       'No public deployment, specialist panel score, or formal answer-proof claim.',
              'inventory_sha256': inventory_sha,
              'runtime_spk_sha256': configs['9101'][0]['expectedRawSha256'],
              'appliance_receipt_sha256': sha(run / 'receiving/9101/APPLIANCE.json'),
              'checks': checks, 'queries': replies, 'mounts': mounts,
              'operator_import': operator_import,
              'import_units': import_units,
              'native_completion_receipts': native_receipts, 'refusals': refusals}
    (run / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'passed': True, 'checks': len(checks), 'report': str(run / 'report.json')}))


if __name__ == '__main__':
    main()

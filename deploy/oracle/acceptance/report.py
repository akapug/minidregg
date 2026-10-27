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


def consent_evidence(run, require):
    directory = run / 'agent-lifetime'
    world = read(run / 'world-identity.json')
    created = read(directory / 'controller-create.json')
    staged = read(directory / 'controller-stage-receipt.json')
    base = world['root'] + '/controller'
    expected = {
        'providerSha256': sha(run / 'bin/minidregg-client-consent'),
        'transportSha256': sha(run / 'bin/mini'),
        'configSha256': sha(run / 'world/store/base/workroom/deployment/pinned-config.json'),
        'socket': base + '/home/consent/peer.sock',
        'socketUnit': f"mini-spk-controller-consent-{world['store']}.socket",
        'serviceUnit': f"mini-spk-controller-consent-{world['store']}.service",
        'serviceUid': created['operatorUid'], 'controllerUid': created['controllerUid'],
        'activationPeerUid': 0, 'provider': base + '/bin/minidregg-client-consent',
        'config': base + '/consent/config.json', 'anchors': base + '/consent/anchors',
    }
    require('controller_consent_v2_distinct_identity',
            created.get('protocol') == staged.get('protocol') == 'mini-spk-controller-v2'
            and created.get('store') == staged.get('store') == world['store']
            and type(created['operatorUid']) is int and created['operatorUid'] > 0
            and type(created['controllerUid']) is int and created['controllerUid'] > 0
            and created['operatorUid'] != created['controllerUid']
            and created.get('consentSocket') == expected['socket']
            and created.get('consentPeerUid') == 0)
    require('controller_consent_exact_stage_pins', staged.get('consent') == expected)
    require('controller_consent_exact_config_bytes',
            sha(directory / 'controller-stage/host-config.json') == expected['configSha256'])
    starts = {}
    for label, filename in (('bootstrap', 'controller-bootstrap-start.json'),
                            ('initial', 'controller-start-initial.json'),
                            ('restart', 'controller-start-restart.json')):
        receipt = read(directory / filename)
        value = receipt.get('consent', {})
        require(f'consent_{label}_exact_pins',
                receipt.get('action') == 'start' and receipt.get('store') == world['store']
                and all(value.get(key) == item for key, item in expected.items())
                and expected['serviceUnit'] in receipt.get('units', [])
                and expected['socketUnit'] in receipt.get('units', []))
        require(f'consent_{label}_observed_readiness_only',
                value.get('readiness') == 'process-and-socket-only'
                and value.get('independentAdmissionObserved') is False
                and type(value.get('mainPid')) is int and value['mainPid'] > 0
                and type(value.get('processStartTicks')) is int and value['processStartTicks'] > 0
                and re.fullmatch('[0-9a-f]{32}', value.get('invocationId', '')) is not None
                and value.get('socketUid') == created['controllerUid'] and value.get('socketMode') == '0600'
                and all(isinstance(value.get(key), list) and len(value[key]) == 2
                        and all(type(n) is int and n >= 0 for n in value[key]) and value[key][1] > 0
                        for key in ('socketIdentity', 'processExecutableIdentity')))
        starts[label] = value
    require('consent_restarts_have_distinct_invocations',
            len({value['invocationId'] for value in starts.values()}) == 3)
    require('consent_restarts_keep_transport_inode',
            all(value['processExecutableIdentity'] == starts['bootstrap']['processExecutableIdentity']
                for value in starts.values()))
    observations = {}
    for stage, start in (('probe', 'initial'), ('probe-after-restart', 'restart')):
        value = read(directory / f'consent-memory-after-{stage}.json')
        properties = value.get('properties', {})
        require(f'consent_{stage}_resources_match_active_invocation',
                value.get('schema') == 'mini-oracle-consent-resources-v1'
                and value.get('unit') == expected['serviceUnit'] and value.get('observation_exit') == 0
                and properties.get('ActiveState') == 'active'
                and properties.get('MainPID') == str(starts[start]['mainPid'])
                and properties.get('InvocationID') == starts[start]['invocationId'])
        def bytes_or_unavailable(key):
            raw = properties.get(key, '')
            return int(raw) if raw.isascii() and raw.isdecimal() and int(raw) < 2**64 - 1 else None
        observations[stage] = {'observation': value,
                               'memory_peak_bytes': bytes_or_unavailable('MemoryPeak'),
                               'memory_limit_bytes': bytes_or_unavailable('MemoryMax')}
    return {'stage': expected, 'starts': starts, 'resources': observations,
            'scope': 'Startup receipts show process/socket readiness only. Actual agent operations below '
                     'exercise independent consent. Memory observations cover this run, not arbitrary Store sizes.'}


def controller_continuation(run, require):
    directory = run / 'continuations/controller-create-1'
    created = read(run / 'agent-lifetime/controller-create.json')
    if not directory.exists():
        require('controller_created_without_unrecorded_recovery', not created.get('resumedPendingCreation', False))
        return None
    value = read(directory / 'prepared.json')
    world = read(run / 'world-identity.json')
    require('controller_continuation_exact_boundary',
            value.get('schema') == 'mini-oracle-controller-continuation-v1'
            and value.get('boundary') == 'after-definite-share-before-any-START'
            and value.get('run') == str(run) and value.get('store') == world['store']
            and value.get('repeated_phases') == []
            and value.get('controller_recovery_verb') == 'controller-resume-create'
            and value.get('prior_exit') == {'execution_exit': 1, 'cleanup_exit': 0, 'namespace_preserved': True}
            and created.get('resumedPendingCreation') is True
            and created.get('controllerUid') == value.get('controller_uid'))
    for name, digest in value['prior_files'].items():
        relative = Path(name)
        require('continuation_snapshot_' + name,
                not relative.is_absolute() and '..' not in relative.parts
                and sha(directory / 'prior' / relative) == digest)
    for phase in ('store', 'birth-a', 'install-a', 'birth-b', 'install-b', 'share-a'):
        for suffix in ('cmd', 'stdout', 'stderr', 'exit', 'seconds'):
            name = f'world/evidence/{phase}.{suffix}'
            require(f'continuation_preserves_{phase}_{suffix}', sha(run / name) == value['prior_files'][name])
    for app in ('9101', '9201'):
        status = read(directory / f'status-{app}.json')
        require(f'continuation_{app}_installed_before_first_START',
                status.get('app') == app and status.get('installCompleted') is True and status.get('runs') == [])
    for line in (directory / 'recovery-input-sha256.txt').read_text().splitlines():
        digest, path = line.split(None, 1)
        require('continuation_source_' + path, Path(path).is_absolute() and sha(Path(path)) == digest)
    return {'prepared': value, 'prepared_sha256': sha(directory / 'prepared.json'),
            'recovery_input_manifest_sha256': sha(directory / 'recovery-input-sha256.txt'),
            'scope': 'Preserved first failure; continued only the pending account creation and later phases. '
                     'No repeated genesis, installation, publication or application share.'}


def main():
    run, inventory_sha = Path(sys.argv[1]), sys.argv[2]
    ev = run / 'world/evidence'
    checks = {}

    def require(name, condition):
        checks[name] = bool(condition)
        if not condition:
            raise AssertionError(name)

    replies = {}
    for label in ('a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12', 'a13', 'a14', 'b1', 'b2', 'b3'):
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
    require('second_grain_exact_replay_after_reconciliation', replies['b1']['sha256'] == replies['b3']['sha256'])
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
    disk_plan = read(run / 'disk-plan.json')
    require('capacity_plan_keeps_native_guards', disk_plan.get('fits') is True
            and disk_plan.get('reservation') is False
            and disk_plan.get('order') == 'install-both-before-publication'
            and disk_plan['available_bytes'] >= disk_plan['materialize_guard_bytes']
            and disk_plan['projected_available_after_publication'] >= disk_plan['verify_guard_bytes'])
    disk = {name: read(run / f'disk-{name}.json')
            for name in ('before-install', 'after-install', 'after-publication', 'after-stops')}
    require('observed_post_publication_verification_space',
            disk['after-publication']['available_bytes'] >= disk_plan['verify_guard_bytes'])

    op155 = {letter: read(run / f'op155-{letter}/report.json') for letter in ('a', 'b')}
    operator_identities = [read(run / f'op155-operator-{boundary}.json')
                           for boundary in ('before', 'after-a', 'before-b', 'after-b')]
    require('stop_inspection_same_operator_process', all(
        identity == operator_identities[0] for identity in operator_identities))
    require('fresh_stop_resident_controls_at_both_boundaries', all(
        item.get('schema') == 'mini-stop-inspection-probe-v1' and item.get('passed') is True
        and item.get('mode') == 'resident-only' and item.get('served_checks_passed') is True
        and item.get('cold_comparison') == 'not-performed'
        for item in op155.values()))
    copied_benchmark = read(run / 'copied-store-stop-benchmark.json')
    require('separate_copied_store_cold_comparison_same_host',
            copied_benchmark.get('schema') == 'mini-stop-inspection-continuation-v1'
            and copied_benchmark.get('passed') is True
            and copied_benchmark.get('host_sha256') == op155['a']['host_sha256']
            and copied_benchmark.get('config_sha256') != op155['a']['config_sha256']
            and re.fullmatch(r'[0-9a-f]{64}', copied_benchmark.get('cold_sha256', '')) is not None
            and copied_benchmark.get('canonical_wrong_claim_checked') is True
            and copied_benchmark.get('source_and_copied_store_and_anchor') == 'hashes unchanged'
            and copied_benchmark.get('controls') == {
                'trailing-claim': 'source', 'malformed-pair': 'transport-routing',
                'mismatched-committed': 'source', 'public-denied': 'transport-routing'})
    require('stop_inspection_refreshed_for_new_claim',
            op155['a']['plan_sha256'] != op155['b']['plan_sha256']
            and op155['a']['committed_sha256'] != op155['b']['committed_sha256']
            and op155['a']['host_sha256'] == op155['b']['host_sha256']
            and op155['a']['config_sha256'] == op155['b']['config_sha256'])
    require('stop_inspection_rejects_old_canonical_claim',
            op155['b'].get('canonical_wrong_claim_checked') is True
            and op155['b'].get('mismatched_committed_sha256') == op155['a']['committed_sha256'])

    configs, mounts, native_receipts, stop_receipts = {}, {}, {}, {}
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
                               for p in sorted(directory.glob('g*/start-completed*.json'))]
        require(f'grain_{app}_two_native_start_completions',
                len({Path(row['file']).parts[2] for row in native_receipts[app]}) >= 2)
        stop_receipts[app] = [{'file': str(p.relative_to(run)), 'sha256': sha(p), 'receipt': read(p)}
                              for p in sorted(directory.glob('g*/stop-completion/**/receipt-anchor.json'))]
        require(f'grain_{app}_two_native_stop_completions', len({Path(row['file']).parts[2] for row in stop_receipts[app]}) >= 2
                and all(row['receipt'].get('eventId') and row['receipt'].get('worldRoot')
                        for row in stop_receipts[app]))
    require('restart_keeps_runtime_and_var', len(configs['9101']) >= 2
            and len({c['expectedRawSha256'] for c in configs['9101']}) == 1
            and len({c['persistentVar'] for c in configs['9101']}) == 1)
    require('reconciled_restart_keeps_runtime_and_var', len(configs['9201']) >= 2
            and len({c['expectedRawSha256'] for c in configs['9201']}) == 1
            and len({c['persistentVar'] for c in configs['9201']}) == 1)
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
    reconciliation_dir = run / 'reconcile-b'
    prior = read(reconciliation_dir / 'record-before.json')
    inactive = read(reconciliation_dir / 'record-inactive.json')
    stopped = read(reconciliation_dir / 'record-stopped.json')
    manager = dict(line.split('=', 1) for line in
                   (reconciliation_dir / 'manager-inactive.txt').read_text().splitlines())
    require('manager_stop_keeps_running_journal_exact', prior == inactive and inactive['phase'] == 'running')
    require('reconciliation_exact_inactive_unit', manager.get('Id') == prior['identity']['unit']
            and manager.get('LoadState') == 'loaded' and manager.get('ActiveState') == 'inactive'
            and manager.get('MainPID') == '0' and manager.get('InvocationID') == ''
            and manager.get('ControlGroup') == '' and manager.get('Job') in ('', '0'))
    require('native_stop_reconciles_same_incarnation', stopped['phase'] == 'stopped'
            and stopped['identity'] == prior['identity']
            and stopped['invocation_id'] == prior['invocation_id']
            and stopped['control_group'] == prior['control_group'] and stopped['child_pid'] is None)
    reconciled_status = read(reconciliation_dir / 'after-native-stop.json')
    require('reconciled_generation_source_stopped', any(
        row['generation'] == str(prior['identity']['generation']) and row['state'] == 'stopped'
        for row in reconciled_status['runs']))
    for letter in ('a', 'b'):
        final_status = read(ev / f'status-{letter}.stdout')
        require(f'final_{letter}_source_stopped', all(
            row['state'] in ('stopped', 'never-begun') for row in final_status['runs']))
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
    # This stage is mandatory for the U3 claim. Receiving HTTP responses above
    # cannot substitute for a controller's agent-origin lifetime grant, native
    # dispatch receipt and distinct-purse settlement.
    consent = consent_evidence(run, require)
    continuation = controller_continuation(run, require)
    agent_stages = {}
    for stage in ('probe', 'probe-after-restart'):
        agent_dir = run / 'agent-lifetime' / stage
        agent_probe = read(agent_dir / 'result.json')
        agent_cases = read(agent_dir / 'cases.json')
        require(f'agent_{stage}_lifetime_probe_completed',
                agent_probe.get('protocol') == 'mini-oracle-lifetime-tool-probe-v1'
                and agent_probe.get('application') == 'oracle-app'
                and agent_probe.get('cases') == len(agent_cases)
                and agent_probe.get('result') == 'all-cases-have-definite-lifetime-delivery-and-settlement')
        require(f'agent_{stage}_discovery_and_invoke_exercised',
                any(case['tool'] == 'mini_oracle_discover' and case['status'] == 200
                    for case in agent_cases)
                and any(case['tool'] == 'mini_oracle_call' and case['status'] == 200
                        for case in agent_cases))
        agent_outcomes = []
        for case in agent_cases:
            name = case['name']
            require(f'agent_{stage}_case_{name}_safe_name', bool(re.fullmatch(r'[A-Za-z0-9_-]{1,64}', name)))
            reply = read(agent_dir / f'{name}.http.json')
            attempt = read(agent_dir / f'{name}.lifetime-attempt.json')
            require(f'agent_{stage}_case_{name}_definite_lifetime_settlement',
                    reply.get('protocol') == 'mini-spk-agent-api-v3'
                    and reply.get('type') == 'http-v3' and reply.get('status') == case['status']
                    and attempt.get('phase') == 'definite' and attempt.get('reported') is True
                    and attempt.get('routeName') == 'oracle-app'
                    and str(attempt.get('operationId')) == reply.get('operationId')
                    and attempt.get('bindingSha256') == reply.get('bindingSha256')
                    and attempt.get('operationFingerprint') == reply.get('operationFingerprint')
                    and attempt.get('lifetimeCommittedReceipt') == reply.get('committedReceipt')
                    and reply.get('committedReceipt') is not None
                    and attempt.get('lifetimeSettledResponseSha256') == reply.get('responseSha256')
                    and re.fullmatch(r'[0-9a-f]{64}', reply.get('responseSha256', '')) is not None
                    and attempt.get('lifetimeSettlement', {}).get('forwardOperationId') == attempt.get('operationId')
                    and attempt.get('lifetimeSettlement', {}).get('settlement', {}).get('operation') == 'dispatch settle')
            require(f'agent_{stage}_case_{name}_retained_tool_result_exact',
                    sha(agent_dir / f'{name}.result.json') == sha(agent_dir / f'{name}.retained-result.json'))
            agent_outcomes.append({'name': name, 'tool': case['tool'], 'status': reply['status'],
                                   'operation_id': reply['operationId'],
                                   'response_sha256': reply['responseSha256'],
                                   'attempt_sha256': sha(agent_dir / f'{name}.lifetime-attempt.json')})
        agent_stages[stage] = {'probe': agent_probe, 'outcomes': agent_outcomes}
    first_agent = run / 'agent-lifetime/probe'
    restarted_agent = run / 'agent-lifetime/probe-after-restart'
    require('agent_restart_uses_same_appliance_requests',
            sha(first_agent / 'cases.json') == sha(restarted_agent / 'cases.json'))
    for case in read(first_agent / 'cases.json'):
        if case['tool'] != 'mini_oracle_call':
            continue
        name = case['name']
        initial = read(first_agent / f'{name}.http.json')
        restarted = read(restarted_agent / f'{name}.http.json')
        require(f'agent_{name}_exact_appliance_reply_after_restart',
                initial['bodyText'] == restarted['bodyText'] and initial['status'] == restarted['status'])
        require(f'agent_{name}_new_native_dispatch_after_restart',
                initial['operationId'] != restarted['operationId']
                and (first_agent / f'{name}.request-id').read_text() !=
                    (restarted_agent / f'{name}.request-id').read_text())
    authority = read(run / 'agent-lifetime/authority/report.json')
    require('actual_lifetime_positive_and_wrong_indices_qualified',
            authority.get('protocol') == 'mini-oracle-agent-authority-probe-v1'
            and authority.get('passed') is True
            and authority.get('positiveReserveReceipt', {}).get('eventId')
            and authority.get('wrong-event22-index', {}).get('passed') is True
            and authority.get('wrong-event27-index', {}).get('passed') is True
            and authority.get('revocationTested') is False
            and authority.get('unsubmittedStalePlanTested') is False
            and authority.get('hostSha256') == op155['a']['host_sha256']
            and authority.get('configSha256') == op155['a']['config_sha256']
            and authority.get('applicationAttemptSha256') == sha(
                first_agent / 'discover-core-query.lifetime-attempt.json'))
    report = {'schema': 'mini-oracle-shared-data-acceptance-v1', 'passed': True,
              'scope': 'Private Linux Store; real Mini install/share/enrollment/dispatch, agent lifetime tools, '
                       'source STOP/restart/reconciliation and sandbox. '
                       'No public deployment, specialist panel score, or formal answer-proof claim.',
              'inventory_sha256': inventory_sha,
              'runtime_spk_sha256': configs['9101'][0]['expectedRawSha256'],
              'appliance_receipt_sha256': sha(run / 'receiving/9101/APPLIANCE.json'),
              'checks': checks, 'queries': replies, 'mounts': mounts,
              'operator_import': operator_import,
              'disk_plan': disk_plan, 'disk_observations': disk,
              'import_units': import_units,
              'native_completion_receipts': native_receipts,
              'native_stop_receipts': stop_receipts,
              'stop_inspection': op155, 'operator_identity': operator_identities[0],
              'separate_copied_store_cold_benchmark': {'receipt': copied_benchmark,
                  'sha256': sha(run / 'copied-store-stop-benchmark.json'),
                  'scope': 'Different copied Store/config; same Host. Fresh probes are resident-only.'},
              'agent_lifetime': agent_stages, 'agent_authority_controls': authority,
              'controller_consent': consent,
              'controller_continuation': continuation,
              'stopped_running_reconciliation': {'before': prior, 'inactive_manager': manager,
                                                 'source_stopped': stopped},
              'refusals': refusals}
    (run / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'passed': True, 'checks': len(checks), 'report': str(run / 'report.json')}))


if __name__ == '__main__':
    main()

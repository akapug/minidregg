#!/usr/bin/env python3
"""Untrusted acceptance orchestration, never native recovery authority.

Preserves the exact stopped attempt and binds approved binaries before the
fixed installer invokes native recovery. No tool submission or journal edits.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys

from continue_controller import (durable_json, manifest, read, require,
                                 retained_run_custody, sha, stopped_services, verify_lock)


def decode_export(value, store):
    require(value.get('protocol') == 'mini-spk-controller-evidence-v1' and value.get('store') == store,
            'controller export identity differs')
    files = value.get('files')
    require(isinstance(files, dict) and len(files) <= 4096, 'controller export file count invalid')
    decoded, size = {}, 0
    for name, row in files.items():
        relative = Path(name)
        require(not relative.is_absolute() and '..' not in relative.parts, 'export path escapes state')
        raw = base64.b64decode(row['base64'], validate=True)
        size += len(raw)
        require(size <= 64 * 1024 * 1024 and hashlib.sha256(raw).hexdigest() == row['sha256'],
                'controller export bytes differ')
        decoded[name] = raw
    return decoded


def prebirth(export, store, request_id, operation_id):
    """Evidence shape only; native command rechecks actual current authority."""
    require(re.fullmatch('[0-9a-f]{32}', request_id) and type(operation_id) is int and operation_id > 0,
            'foreground identity malformed')
    files = decode_export(export, store)
    journal = json.loads(files['journal.json'])
    attempt = journal.get('foregroundAttempt') or {}
    require(journal.get('format') == 'minidregg-grain-runtime-v1'
            and attempt.get('requestId') == request_id and attempt.get('operationId') == operation_id
            and attempt.get('name') == 'mini_create_application_session'
            and attempt.get('phase') == 'uncertain' and attempt.get('reported') is False
            and attempt.get('resultPath') is None and attempt.get('resultSha256') is None,
            'not the exact unresolved foreground session')
    state = Path(journal['binding']['config']['stateDir'])
    request_name = f'foreground-{operation_id:016}.request.json'
    require(attempt.get('requestPath') == str(state / request_name)
            and hashlib.sha256(files[request_name]).hexdigest() == attempt['requestSha256'],
            'retained foreground request changed')
    request = json.loads(files[request_name])
    require(request == {'requestId':request_id,'name':'mini_create_application_session',
                        'arguments':{'application':'oracle-bootstrap-app','family':'oracle-session'}},
            'retained session selectors differ')
    identity = json.loads(files['foreground-request-' + request_id + '.json'])
    require(identity == {key:attempt[key] for key in ('requestId','operationId','requestSha256')},
            'foreground request index differs')
    for name in ('pending','toolPending','dispatchPending','providerPending','toolHold','dispatchHold','providerHold',
                 'birthOperation','birthPending','applicationApiAttempt','dispatchAttempt','child','settlementDue'):
        require(journal.get(name) is None, 'conflicting retained work: ' + name)
    require(journal.get('bornResources') == [] and journal.get('birthNextOrdinal') == {}
            and journal.get('unresolvedExternal') == [], 'a birth or unrelated uncertainty already exists')
    require(not any(name.startswith(('birth-','foreground-recovery-')) for name in files),
            'native birth or recovery already began')
    hold = journal.get('parentHold') or {}
    require(hold.get('reserveConfirmed') is True and hold.get('reserveRefused') is False
            and hold.get('reserve') == '1' and hold.get('charge') == '0', 'original parent reserve absent')
    reserve = Path(hold['reserveAttempt'])
    require(reserve.parent == state and re.fullmatch('attempt-[0-9]{16}',reserve.name), 'reserve custody path differs')
    outcome = json.loads(files[reserve.name+'/outcome.json'])
    require(outcome.get('type') == 'confirmed' and outcome.get('confirmation') in ('installed','replayed')
            and outcome.get('worldRoot') == hold['reserveBoundary'], 'retained parent reserve receipt differs')
    require(reserve.name+'/call.bin' in files and reserve.name+'/outcome.bin' in files,
            'native reserve exact call/outcome absent')
    return {'request_id':request_id,'operation_id':operation_id,'request_sha256':attempt['requestSha256'],
            'journal_sha256':hashlib.sha256(files['journal.json']).hexdigest(),
            'reserve_call_sha256':hashlib.sha256(files[reserve.name+'/call.bin']).hexdigest(),
            'reserve_receipt':outcome,'parent_hold':hold,'binding':journal['binding']}


def prepare(plan_path, exported_path, status_path, sources_path, output):
    plan = read(plan_path)
    require(plan.get('protocol') == 'mini-oracle-foreground-recovery-plan-v1', 'recovery plan protocol differs')
    run = Path(plan['run'])
    verify_lock(run)
    world = read(run/'world-identity.json')
    require(world['store'] == plan['store'] and not list((run/'world/evidence').glob('start-*.cmd')),
            'retained Store or unstarted application boundary differs')
    require(output == run/'continuations'/('foreground-'+str(plan['operation_id'])) and not output.exists(),
            'recovery evidence already exists or path differs; inspect, never repeat')
    for key in ('predecessor_export','predecessor_status','runtime','public_mini','spk','inventory','benchmark','qualification_manifest'):
        pin = plan[key]; path = Path(pin['path'])
        require(path.is_absolute() and not path.is_symlink() and path.is_file() and sha(path) == pin['sha256'],
                'recovery plan input changed: '+key)
    exported, status = read(exported_path), read(status_path)
    require(exported == read(Path(plan['predecessor_export']['path']))
            and status == read(Path(plan['predecessor_status']['path'])), 'fresh stopped evidence differs from reviewed predecessor')
    boundary = prebirth(exported,plan['store'],plan['request_id'],plan['operation_id'])
    require(status.get('store') == plan['store'] and status.get('stopped') is True
            and status['publicListener']['binarySha256'] == plan['old_public_mini_sha256']
            and status['runtimeSha256'] == plan['old_runtime_sha256'], 'installed binary predecessor differs')
    custody, services = retained_run_custody(run), stopped_services(run,plan['store'])
    inputs = manifest(run/'input-sha256.txt')
    for key in ('spk','inventory','benchmark'):
        pin=plan[key];require(inputs.get(pin['path']) == pin['sha256'], 'original v5 input changed: '+key)
    sources = manifest(sources_path)
    qualification = manifest(Path(plan['qualification_manifest']['path']))
    for key in ('runtime','public_mini'):
        pin=plan[key]
        require(qualification.get(pin['path']) == pin['sha256'], 'recovery binary not in independent qualification manifest')
        require(sources.get(pin['path']) == pin['sha256'], 'recovery binary not in execution source manifest')
    workroom=run/'world/store/base/workroom'
    config=workroom/'deployment/pinned-config.json'
    require(sha(config)==plan['host_config_sha256'], 'source Host configuration changed')
    logical=[workroom/'store/forward-link.sqlite3',workroom/'store.head-anchor']
    require({p.name for p in (workroom/'store').iterdir()}=={'forward-link.sqlite3'}
            and all(p.is_file() and not p.is_symlink() for p in logical)
            and sum(p.stat().st_size for p in logical)<=64*1024*1024, 'stopped logical Store shape exceeds snapshot scope')
    original_result = run/'agent-lifetime/session-birth.result.json'
    require(original_result.is_file(), 'original failed client result absent')
    before={str(p):sha(p) for p in logical}
    output.mkdir(mode=0o700); prior=output/'prior';prior.mkdir(mode=0o700)
    for path in [*logical,config,plan_path,exported_path,status_path,sources_path,original_result]:
        target=prior/(hashlib.sha256(str(path).encode()).hexdigest()[:16]+'-'+path.name)
        shutil.copyfile(path,target);target.chmod(0o400)
        require(sha(path)==sha(target),'snapshot changed during copy')
        with target.open('rb') as stream: os.fsync(stream.fileno())
    for directory in (prior,output,output.parent):
        fd=os.open(directory,os.O_RDONLY|os.O_DIRECTORY)
        try:os.fsync(fd)
        finally:os.close(fd)
    require(before=={str(p):sha(p) for p in logical},'Store changed during recovery snapshot')
    (output/'phases').mkdir(mode=0o700)
    durable_json(output/'prepared.json',{'protocol':'mini-oracle-foreground-recovery-prepared-v1','plan':plan,
        'plan_sha256':sha(plan_path),'boundary':boundary,'run_custody':custody,'stopped_services':services,
        'source_manifest':sources,'store_before':before,
        'original_result_sha256':sha(original_result),'snapshot_files':{p.name:sha(p) for p in prior.iterdir()},
        'resend':False,'acknowledge_before_settlement':False,'automatic_retry':False})
    return output


def validate_result(plan, recovered, retained, journal, exported):
    require(recovered.get('type') == 'mini-foreground-session-recovery-v1'
            and recovered.get('resultReady') is True
            and recovered.get('requestId') == plan['request_id']
            and str(recovered.get('operationId')) == str(plan['operation_id'])
            and recovered.get('acknowledged') is False, 'native recovery identity or ACK differs')
    require(retained.get('type') == 'tool-complete' and retained.get('requestId') == plan['request_id']
            and str(retained.get('operationId')) == str(plan['operation_id']) and retained.get('isError') is False
            and retained.get('result', {}).get('isError') is False, 'retained result is not definite success')
    for name in ('parentHold','toolHold','pending','toolPending','birthOperation','birthPending'):
        require(journal.get(name) is None,'recovered session retains unsettled work: '+name)
    attempt=journal.get('foregroundAttempt') or {}
    require(attempt.get('requestId')==plan['request_id'] and attempt.get('operationId')==plan['operation_id']
            and attempt.get('phase')=='definite' and attempt.get('reported') is False,
            'native foreground is not definite and awaiting ordinary ACK')
    files = decode_export(exported, plan['store'])
    require(json.loads(files['journal.json']) == journal, 'settled export journal differs')
    state = Path(journal['binding']['config']['stateDir'])
    result_name = f"foreground-{plan['operation_id']:016}.result.json"
    raw = files[result_name]
    require(attempt.get('resultPath') == str(state / result_name)
            and hashlib.sha256(raw).hexdigest() == attempt.get('resultSha256') == recovered.get('resultSha256')
            and json.loads(raw) == retained.get('result'), 'native recovery result digest or bytes differ')
    require({str(row.get('target')) for row in journal.get('bornResources',[])} == {'29420','29421'}
            and len(journal['bornResources']) == 2,'native session pair was not retained')


if __name__ == '__main__':
    try:
        if len(sys.argv)==7 and sys.argv[1]=='prepare':
            print(prepare(*map(Path,sys.argv[2:])))
        elif len(sys.argv)==7 and sys.argv[1]=='result':
            validate_result(*[read(Path(p)) for p in sys.argv[2:]])
        else:raise ValueError('usage: recover_foreground.py prepare PLAN EXPORT STATUS SOURCES OUT | result PLAN RECOVERY RESULT JOURNAL EXPORT')
    except (ValueError,KeyError,OSError) as error:
        raise SystemExit('foreground continuation stopped: '+str(error))

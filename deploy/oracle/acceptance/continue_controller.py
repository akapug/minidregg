#!/usr/bin/env python3
"""Untrusted fixture continuity checks, not Mini admission or recovery authority.

Preserve the definite pre-START account-creation failure before the installer
performs its separately checked pending-account recovery. Never submit a call.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import stat
import sys
import tarfile


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def require(condition, message):
    if not condition:
        raise ValueError(message)


def manifest(path):
    values = {}
    for line in path.read_text().splitlines():
        digest, name = line.split(None, 1)
        item = Path(name)
        require(item.is_absolute() and not item.is_symlink() and item.is_file(), 'manifest path differs')
        require(sha(item) == digest, 'retained bytes changed: ' + name)
        values[name] = digest
    return values


def prepare(run, spk, inventory, benchmark, repo, check_only=False):
    ev = run / 'world/evidence'
    workroom = run / 'world/store/base/workroom'
    require(read(run / 'exit.json') == {'execution_exit': 1, 'cleanup_exit': 0,
                                      'namespace_preserved': True}, 'not the definite preserved failure')
    log = run.parent / 'journey-v5.log'
    require("configuration error - unknown item 'CREATE_MAIL_SPOOL'" in log.read_text()
            and 'controller setup refused:' in log.read_text(), 'account creation refusal differs')
    require((run / 'agent-lifetime/controller-create.json').read_bytes() == b'', 'controller create already replied')
    for name in ('controller-stage.json', 'controller-stage-receipt.json', 'session-birth.request-id',
                 'session-birth.result.json', 'issued-grant.json', 'probe'):
        require(not (run / 'agent-lifetime' / name).exists(), 'controller work already began: ' + name)
    for name in ('operator.pid', 'participant.pid'):
        require(not (run / 'world/sock' / name).exists(), 'Store service remains present')
    stale_sockets = {}
    for name in ('operator/host.sock', 'participant/host.sock'):
        path = run / 'world/sock' / name
        require(not path.is_symlink(), 'retained service socket is linked')
        if path.exists():
            metadata = path.lstat()
            require(stat.S_ISSOCK(metadata.st_mode) and stat.S_IMODE(metadata.st_mode) == 0o600
                    and metadata.st_uid == os.getuid(), 'retained socket custody differs')
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
                probe.settimeout(1)
                try:
                    probe.connect(str(path))
                except ConnectionRefusedError:
                    stale_sockets[str(path)] = {'device': metadata.st_dev, 'inode': metadata.st_ino,
                                                'observed': 'connection-refused-without-sending-bytes'}
                else:
                    raise ValueError('Store socket still has a listener')
    phases = ('store', 'birth-a', 'install-a', 'birth-b', 'install-b', 'share-a')
    for name in phases:
        require((ev / (name + '.exit')).read_text().strip() == '0', 'prior phase did not complete: ' + name)
    require(not list(ev.glob('start-*.cmd')), 'a START was already attempted')
    inputs = manifest(run / 'input-sha256.txt')
    binaries = manifest(run / 'binary-sha256.txt')
    for path in (spk, inventory, benchmark):
        require(inputs.get(str(path)) == sha(path), 'original input identity differs')
    preserved = manifest(run / 'failure-store-preservation.sha256')
    require(set(preserved) == {str(workroom / 'store/forward-link.sqlite3'),
                              str(workroom / 'store.head-anchor')}, 'stopped Store snapshot differs')
    world = read(run / 'world-identity.json')
    root = Path('/var/lib/mini-spk-worlds') / world['store']
    require(str(root) == world['root'], 'world path differs')
    profile = read(ev / 'profile-result.json')
    state = Path(profile['stateRoot'])
    require(state == root / world['store'] / 'host' and profile['miniConfig'] == str(workroom / 'deployment/pinned-config.json')
            and profile['miniConfigSha256'] == sha(Path(profile['miniConfig'])), 'profile identity differs')
    for app, letter in (('9101', 'a'), ('9201', 'b')):
        installed = read(ev / f'install-{letter}.stdout')
        require(installed.get('protocol') == 'mini-spk-grain-install-v2'
                and installed.get('app') == app and installed.get('store') == world['store']
                and installed.get('rawSha256') == sha(spk)
                and installed.get('completion') == read(state / 'apps' / app / 'install/install-completed-v2.json'),
                'retained native install completion differs')
        require(not list((state / 'apps' / app).glob('g[0-9]*')), 'native START generation exists')
    native_files = {}
    with tarfile.open(run / 'native-state.tar') as archive:
        require(len(archive.getmembers()) <= 2048
                and sum(item.size for item in archive.getmembers()) <= 64 * 1024 * 1024,
                'native archive exceeds this bounded continuation')
        for item in archive.getmembers():
            if item.isdir():
                continue
            relative = Path(item.name)
            require(item.isfile() and not relative.is_absolute() and '..' not in relative.parts
                    and relative.parts[0] == 'apps', 'native archive shape differs')
            digest = hashlib.sha256(archive.extractfile(item).read()).hexdigest()
            require(sha(state / relative) == digest, 'native record changed: ' + item.name)
            native_files[item.name] = digest
    actual = {str(p.relative_to(state)) for p in (state / 'apps').rglob('*') if p.is_file()}
    require(actual == set(native_files), 'native record set changed')
    publication = read(run / 'publication.json')
    revision = root / 'spk/public-data' / ('sha256-' + sha(inventory))
    require(publication.get('inventory_sha256') == sha(inventory)
            and publication.get('directory') == str(revision)
            and not revision.is_symlink() and sha(revision / 'inventory.json') == sha(inventory),
            'published inventory identity differs')
    route = read(ev / 'share-a.stdout')
    require(route.get('protocol') == 'mini-spk-grain-route-v1' and route.get('app') == '9101'
            and route.get('ticket') == '9120' and route.get('kind') == 'api'
            and route.get('signedApiPath') == '/', 'retained receiving share differs')
    reservation_path = Path('/etc/mini-spk-controller-reservations') / (world['store'] + '.json')
    reservation = read(reservation_path)
    output = run / 'continuations/controller-create-1'
    require(not output.exists(), 'controller continuation already attempted')
    if check_only:
        return {'checked': True, 'store': world['store'], 'controller_uid': reservation['controllerUid'],
                'boundary': 'after-definite-share-before-any-START', 'repeated_phases': []}
    output.parent.mkdir(mode=0o700, exist_ok=True)
    output.mkdir(mode=0o700)
    prior = output / 'prior'
    prior.mkdir(mode=0o700)
    names = ['exit.json', 'input-sha256.txt', 'binary-sha256.txt', 'native-state.tar',
             'failure-store-preservation.sha256', 'world-identity.json', 'publication.json',
             'agent-lifetime/controller-create.json', 'world/evidence/journey.log', 'cleanup.log', 'broker.log']
    names += [str(p.relative_to(run)) for p in (run / 'world/sock').rglob('*') if p.is_file()]
    names += [name for name in ('residents.log',) if (run / name).is_file()]
    names += [str(p.relative_to(run)) for name in (*phases, 'services') for p in ev.glob(name + '.*') if p.is_file()]
    for name in names:
        target = prior / name
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        shutil.copyfile(run / name, target)
    shutil.copyfile(log, prior / 'journey-v5.log')
    files = list((workroom / 'store').rglob('*'))
    require(all(not p.is_symlink() for p in files)
            and sum(p.stat().st_size for p in files if p.is_file()) <= 64 * 1024 * 1024,
            'stopped Store copy exceeds this bounded recovery')
    shutil.copytree(workroom / 'store', prior / 'logical-store')
    shutil.copyfile(workroom / 'store.head-anchor', prior / 'logical-store.head-anchor')
    require(sha(prior / 'logical-store/forward-link.sqlite3') == preserved[str(workroom / 'store/forward-link.sqlite3')]
            and sha(prior / 'logical-store.head-anchor') == preserved[str(workroom / 'store.head-anchor')], 'Store copy differs')
    manifest(run / 'failure-store-preservation.sha256')
    prior_files = {str(p.relative_to(prior)): sha(p) for p in prior.rglob('*') if p.is_file()}
    for p in prior.rglob('*'):
        p.chmod(0o500 if p.is_dir() else 0o400)
    prior.chmod(0o500)
    value = {'schema': 'mini-oracle-controller-continuation-v1', 'boundary': 'after-definite-share-before-any-START',
             'run': str(run), 'recovery_source': str(repo), 'store': world['store'],
             'controller_uid': reservation['controllerUid'], 'reservation_sha256': sha(reservation_path),
             'prior_exit': read(prior / 'exit.json'), 'prior_files': prior_files,
             'archived_original_paths': {str(run / name): {'path': str(prior / name), 'sha256': prior_files[name]}
                                         for name in names},
             'original_inputs': inputs, 'original_binaries': binaries, 'native_files_before': native_files,
             'store_before': preserved, 'repeated_phases': [],
             'stale_service_sockets': stale_sockets,
             'store_snapshot': {str(workroom / 'store/forward-link.sqlite3'): str(prior / 'logical-store/forward-link.sqlite3'),
                                str(workroom / 'store.head-anchor'): str(prior / 'logical-store.head-anchor')},
             'supported_services_to_restart': ['broker', 'operator', 'participant'],
             'controller_recovery_verb': 'controller-resume-create'}
    (output / 'prepared.json').write_text(json.dumps(value, indent=2) + '\n')
    return output


if __name__ == '__main__':
    os.umask(0o077)
    args = sys.argv[1:]
    check = args[:1] == ['--check-only']
    value = prepare(*map(Path, args[1:] if check else args), check_only=check)
    print(json.dumps(value) if check else value)

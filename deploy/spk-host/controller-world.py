#!/usr/bin/python3
"""Fixed root setup for a world's isolated test controller, never Store admission.

Invoked only by install-user-world. Supplied programs execute in fixed systemd
units as the operator/controller, never as root. Failed inputs stay where they
were supplied; receipts and immutable configuration revisions remain inspectable.
"""
import base64
import contextlib
import fcntl
import grp
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import resource
import selectors
import shutil
import signal
import socket
import stat
import struct
import subprocess
import sys
import time

WORLDS = Path('/var/lib/mini-spk-worlds')
REGISTRY = Path('/etc/mini-spk-volumes')
UNITS = Path('/etc/systemd/system')
HISTORY = Path('/var/lib/mini-spk-controller-history')
TOOLS = {'mini_create_application_session', 'mini_oracle_discover', 'mini_oracle_call', 'mini_grain_status'}
FILES = {'controller.json': 524288, 'host-config.json': 1048576,
         **{f'custody/{role}.key': 32 for role in ('controller', 'tool', 'dispatch', 'provider')},
         'state/shared-app-refs/app-birth.bin': 1048576,
         'state/shared-app-refs/bootstrap-ticket.bin': 1048576}
FINAL_FILES = {'state/shared-app-refs/agent-ticket.bin': 1048576,
               **{f'state/oracle-grant/{n}': 1048576 for n in ('seal.json', 'call.bin', 'submit-marker.json', 'receipt.json')}}
BINS = ('grain-runtime', 'mini', 'minidregg-host')
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LANG': 'C.UTF-8'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def canonical(value):
    require(isinstance(value, str) and re.fullmatch(r'/[A-Za-z0-9_./-]+', value)
            and all(p not in ('', '.', '..') for p in value[1:].split('/')), 'noncanonical setup path')
    return Path(value)


def run(args, **kwargs):
    return subprocess.run(args, check=True, env=ENV, timeout=60, **kwargs)


def metadata(path, owner=None, mode=None):
    m = path.lstat()
    require(not stat.S_ISLNK(m.st_mode), f'symlink refused: {path}')
    if owner is not None:
        require(m.st_uid == owner, f'owner refused: {path}')
    if mode is not None:
        require(stat.S_IMODE(m.st_mode) == mode, f'mode refused: {path}')
    return m


def ancestry(path, owners):
    for p in reversed((path, *path.parents)):
        m = metadata(p)
        require(stat.S_ISDIR(m.st_mode) and m.st_uid in owners and not m.st_mode & 0o022,
                f'ancestor custody refused: {p}')


def fingerprint(m):
    return (m.st_dev, m.st_ino, m.st_uid, m.st_gid, m.st_mode, m.st_size, m.st_mtime_ns, m.st_ctime_ns)


def read_file(path, owner, maximum, executable=False, allow_empty=False, required_mode=None):
    ancestry(path.parent, {0, owner})
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_uid == owner,
                f'regular source custody refused: {path}')
        require(required_mode is None or stat.S_IMODE(before.st_mode) == required_mode,
                f'private source mode refused: {path}')
        require(not before.st_mode & 0o7022 and (allow_empty or before.st_size > 0) and before.st_size <= maximum,
                f'source mode/size refused: {path}')
        require(not executable or before.st_mode & 0o111, f'nonexecutable binary: {path}')
        require('security.capability' not in os.listxattr(fd), f'file capabilities refused: {path}')
        chunks, left = [], maximum + 1
        while left:
            chunk = os.read(fd, min(left, 1024 * 1024))
            if not chunk:
                break
            chunks.append(chunk)
            left -= len(chunk)
        data = b''.join(chunks)
        require(len(data) == before.st_size and fingerprint(before) == fingerprint(os.fstat(fd))
                and fingerprint(before) == fingerprint(path.lstat()), f'source changed while copying: {path}')
        return data
    finally:
        os.close(fd)


def write_new(path, data, uid=0, gid=0, mode=0o600):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, mode)
    try:
        os.fchown(fd, uid, gid)
        os.fchmod(fd, mode)
        with os.fdopen(os.dup(fd), 'wb') as out:
            out.write(data)
            out.flush()
        os.fsync(fd)
    finally:
        os.close(fd)
    d = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(d)
    finally:
        os.close(d)


def mkdir(path, uid=0, gid=0, mode=0o700):
    path.mkdir(mode=mode)
    os.chown(path, uid, gid)
    os.chmod(path, mode)


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


# Permanent reservations are intentionally separate from removable controller
# resources. Old resident namespaces can retain a mapping after account removal.
RESERVATIONS = Path('/etc/mini-spk-controller-reservations')
MAX_IDENTITIES = 4096
MAX_ID = 2**32 - 1


def strict_json(data):
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, 'duplicate root identity field')
            value[key] = item
        return value
    return json.loads(data, object_pairs_hook=pairs)


def ident(value, subordinate=False):
    return type(value) is int and (65536 if subordinate else 1) <= value < MAX_ID


def registry_record(path):
    r = strict_json(read_file(path, 0, 65536, required_mode=0o644))
    keys = {'protocol', 'store', 'deploymentId', 'hostId', 'grainsRoot', 'operatorUid', 'operatorGid', 'appUids', 'helper', 'helperSha256'}
    require(isinstance(r, dict) and set(r) == keys and r['protocol'] == 'mini-spk-volume-registry-v1', 'root world registry schema refused')
    require(isinstance(r['store'], str) and re.fullmatch('[0-9a-f]{16}', r['store'])
            and path.name == r['store'] + '.json' and r['grainsRoot'] == str(WORLDS / r['store']), 'world registry path differs')
    require(all(isinstance(r[k], str) and re.fullmatch('[0-9a-f]{64}', r[k]) for k in ('deploymentId', 'hostId', 'helperSha256'))
            and ident(r['operatorUid']) and ident(r['operatorGid']), 'world registry identity malformed')
    require(isinstance(r['helper'], str) and re.fullmatch(r'/usr/local/libexec/mini-spk-volume-helper(?:-[0-9a-f]{16})?', r['helper']), 'world helper path malformed')
    app = r['appUids']
    require(isinstance(app, list) and 1 <= len(app) <= 64 and all(ident(i, True) for i in app)
            and len(set(app)) == len(app) and not set(app) & {r['operatorUid'], r['operatorGid']}, 'world app identity set malformed')
    return r


def namespace_record(r):
    fields = {'protocol', 'store', 'deploymentId', 'hostId', 'operatorUid', 'operatorGid', 'controllerUid', 'controllerGid', 'account'}
    require(isinstance(r, dict) and set(r) == fields and r['protocol'] == 'mini-spk-controller-namespace-v1', 'controller reservation schema refused')
    require(isinstance(r['store'], str) and re.fullmatch('[0-9a-f]{16}', r['store'])
            and r['account'] == 'mini-c-' + r['store'], 'controller reservation name malformed')
    require(all(isinstance(r[k], str) and re.fullmatch('[0-9a-f]{64}', r[k]) for k in ('deploymentId', 'hostId'))
            and all(ident(r[k]) for k in ('operatorUid', 'operatorGid'))
            and all(ident(r[k], True) for k in ('controllerUid', 'controllerGid'))
            and not {r['operatorUid'], r['operatorGid']} & {r['controllerUid'], r['controllerGid']}, 'controller reservation identity malformed')
    return r


def bounded_json_paths(directory):
    try:
        ancestry(directory, {0})
    except FileNotFoundError:
        # Missing fixed directory is the legacy empty case; a dangling symlink
        # or inaccessible existing directory never gets that interpretation.
        require(not directory.exists() and not directory.is_symlink(), 'identity directory custody refused')
        return []
    found = []
    for entry in directory.iterdir():
        if entry.name.endswith('.json'):
            found.append(entry)
            require(len(found) <= MAX_IDENTITIES, 'root identity registry count exceeds bound')
    return sorted(found)


def occupied_ids():
    occupied, reservations = set(), {}
    for path in bounded_json_paths(REGISTRY):
        r = registry_record(path)
        require(not occupied.intersection(r['appUids']), 'root app registries overlap')
        occupied.update(r['appUids'])
        occupied.update((r['operatorUid'], r['operatorGid']))
    for path in bounded_json_paths(RESERVATIONS):
        r = namespace_record(strict_json(read_file(path, 0, 4096, required_mode=0o644)))
        require(path.name == r['store'] + '.json', 'controller reservation filename differs')
        ids = {r['controllerUid'], r['controllerGid']}
        require(not occupied.intersection(ids), 'controller reservation overlaps a world or another reservation')
        occupied.update(ids); reservations[r['store']] = r
    # Existing removed-controller evidence is also a reservation, including
    # receipts from the earlier system-account allocator. Never reclaim it.
    for path in bounded_json_paths(HISTORY):
        h = strict_json(read_file(path, 0, 65536, required_mode=0o600))
        require(isinstance(h, dict) and h.get('removed') is True and isinstance(h.get('receipt'), dict), 'removed controller receipt malformed')
        r = h['receipt']; store = r.get('store')
        require(isinstance(store, str) and re.fullmatch('[0-9a-f]{16}', store) and path.name == store + '.json'
                and r.get('protocol') == 'mini-spk-controller-v1' and r.get('name') == 'mini-c-' + store
                and ident(r.get('uid')) and ident(r.get('gid')), 'removed controller identity malformed')
        if store in reservations:
            require((r['uid'], r['gid']) == (reservations[store]['controllerUid'], reservations[store]['controllerGid']), 'removed controller reservation changed')
        else:
            require(not occupied.intersection((r['uid'], r['gid'])), 'removed controller identity overlaps live allocation')
            occupied.update((r['uid'], r['gid']))
    # A pending create has a permanent reservation before any account creation.
    # Older allocations without one must not silently disappear from scanning.
    for path in bounded_json_paths(REGISTRY):
        r = registry_record(path); directory = WORLDS / r['store'] / 'controller'
        if directory.exists() or directory.is_symlink():
            ancestry(directory, {0})
            require(r['store'] in reservations, 'existing/pending controller lacks permanent identity reservation')
    return occupied


def merged(ranges):
    out = []
    for start, end in sorted(ranges):
        if out and start <= out[-1][1]: out[-1] = (out[-1][0], max(out[-1][1], end))
        else: out.append((start, end))
    return out


def subordinate_ranges(path, operator_uid):
    data = read_file(path, 0, 1024 * 1024, allow_empty=True, required_mode=0o644).decode('ascii')
    own, other = [], []
    lines = data.splitlines(); require(len(lines) <= 16384, 'subordinate delegation line bound exceeded')
    for line in lines:
        if not line or line.startswith('#'): continue
        parts = line.split(':')
        require(len(parts) == 3 and re.fullmatch('[A-Za-z0-9_.-]{1,256}', parts[0])
                and re.fullmatch('[0-9]+', parts[1]) and re.fullmatch('[0-9]+', parts[2]), 'subordinate delegation row malformed')
        owner, first, count = parts[0], int(parts[1]), int(parts[2])
        require(0 <= first < MAX_ID and 0 < count <= MAX_ID and first + count <= MAX_ID, 'subordinate delegation range overflows')
        if owner.isascii() and owner.isdecimal(): owner_uid = int(owner)
        else:
            try: owner_uid = pwd.getpwnam(owner).pw_uid
            except KeyError: owner_uid = None
        (own if owner_uid == operator_uid else other).append((first, first + count))
    return merged(own), merged(other)


def intersection(left, right):
    out = []; i = j = 0
    while i < len(left) and j < len(right):
        first, end = max(left[i][0], right[j][0], 65536), min(left[i][1], right[j][1])
        if first < end: out.append((first, end))
        if left[i][1] < right[j][1]: i += 1
        else: j += 1
    return out


def delegated(operator_uid):
    uids, foreign_uids = subordinate_ranges(Path('/etc/subuid'), operator_uid)
    gids, foreign_gids = subordinate_ranges(Path('/etc/subgid'), operator_uid)
    return intersection(uids, gids), merged(foreign_uids + foreign_gids)


def in_ranges(identity, ranges):
    return any(first <= identity < end for first, end in ranges)


def nss_ids():
    users, groups = pwd.getpwall(), grp.getgrall()
    require(len(users) <= 16384 and len(groups) <= 16384, 'NSS identity snapshot bound exceeded')
    return {i for p in users for i in (p.pw_uid, p.pw_gid)} | {g.gr_gid for g in groups}


def nss_free(identity, enumerated=None):
    try: pwd.getpwuid(identity)
    except KeyError: pass
    else: return False
    try: grp.getgrgid(identity)
    except KeyError: pass
    else: return False
    return identity not in (nss_ids() if enumerated is None else enumerated)


def delegation_owners():
    names, ids = set(), set()
    for path in (Path('/etc/subuid'), Path('/etc/subgid')):
        data = read_file(path, 0, 1024 * 1024, allow_empty=True, required_mode=0o644).decode('ascii')
        require(len(data.splitlines()) <= 16384, 'subordinate delegation line bound exceeded')
        for line in data.splitlines():
            if not line or line.startswith('#'): continue
            parts = line.split(':')
            require(len(parts) == 3 and re.fullmatch('[A-Za-z0-9_.-]{1,256}', parts[0]), 'subordinate delegation owner malformed')
            if parts[0].isascii() and parts[0].isdecimal(): ids.add(int(parts[0]))
            else: names.add(parts[0])
    return names, ids


def allocate_identity(operator_uid, account):
    occupied = occupied_ids(); own, foreign = delegated(operator_uid); accounts = nss_ids()
    delegated_names, delegated_ids = delegation_owners()
    require(account not in delegated_names, 'new controller name already has subordinate grants')
    examined = 0
    for first, end in own:
        for identity in range(first, end):
            examined += 1
            require(examined <= 65536, 'controller allocation candidate bound exhausted; no range truncated or reclaimed')
            if identity not in occupied and identity not in delegated_ids and not in_ranges(identity, foreign) and nss_free(identity, accounts):
                return identity
    raise ValueError('no unused controller identity in exclusive delegated UID/GID intersection')


def check_app_allocation(store, helper, op_text, first_text, count_text):
    require(re.fullmatch('[0-9a-f]{16}', store) and re.fullmatch(r'/usr/local/libexec/mini-spk-volume-helper(?:-[0-9a-f]{16})?', helper), 'app allocation coordinates malformed')
    require(all(re.fullmatch('[1-9][0-9]*', s) for s in (op_text, first_text, count_text)), 'app allocation decimal malformed')
    operator, first, count = map(int, (op_text, first_text, count_text))
    require(ident(operator) and ident(first, True) and 2 <= count <= 64 and first + count <= MAX_ID
            and str(operator) == os.environ.get('SUDO_UID', str(operator)), 'app allocation identity/bound refused')
    occupied = occupied_ids(); own, foreign = delegated(operator); accounts = nss_ids()
    require(all(in_ranges(i, own) and not in_ranges(i, foreign) and i not in occupied and nss_free(i, accounts)
                for i in range(first, first + count)), 'app range collides with reserved/account/foreign identity or is not delegated')
    return {'store': store, 'appRangeChecked': [first, first + count]}


def store_context(store, helper):
    require(re.fullmatch('[0-9a-f]{16}', store), 'invalid Store')
    require(re.fullmatch(r'/usr/local/libexec/mini-spk-volume-helper(?:-[0-9a-f]{16})?', helper), 'invalid helper')
    r = registry_record(REGISTRY / (store + '.json'))
    require(r['protocol'] == 'mini-spk-volume-registry-v1' and r['store'] == store and r['helper'] == helper,
            'registered Store/helper differs')
    require(str(r['operatorUid']) == os.environ.get('SUDO_UID', str(r['operatorUid'])), 'caller is not Store operator')
    require(r['operatorUid'] != 0 and pwd.getpwuid(r['operatorUid']).pw_gid == r['operatorGid'], 'operator account differs')
    root = WORLDS / store
    require(r['grainsRoot'] == str(root), 'registered world path differs')
    ancestry(root, {0})
    base = root / 'controller'
    return r, base


def names(store):
    return [f'mini-spk-controller-{store}.service', f'mini-spk-controller-proxy-{store}.socket',
            f'mini-spk-controller-proxy-{store}.service']


def manager_properties(name):
    output = run(['/usr/bin/systemctl', 'show', name, '--property=LoadState,FragmentPath,Transient,User,ActiveState,MainPID'],
                 stdout=subprocess.PIPE).stdout.decode()
    return dict(line.split('=', 1) for line in output.splitlines() if '=' in line)


def load(store, helper):
    registry, base = store_context(store, helper)
    ancestry(base, {0})
    receipt = json.loads(read_file(base / 'receipt.json', 0, 65536))
    require(receipt['protocol'] == 'mini-spk-controller-v1' and receipt['store'] == store
            and receipt['operatorUid'] == registry['operatorUid'], 'controller receipt differs')
    require(receipt['name'] == 'mini-c-' + store and receipt['home'] == str(base / 'home')
            and receipt['units'] == names(store), 'controller layout differs')
    account = pwd.getpwnam(receipt['name'])
    require((account.pw_uid, account.pw_gid, account.pw_dir, account.pw_shell) ==
            (receipt['uid'], receipt['gid'], receipt['home'], '/usr/sbin/nologin'), 'controller account changed')
    group = grp.getgrgid(receipt['gid'])
    require(group.gr_name == receipt['name'] and not group.gr_mem, 'controller private group changed')
    require(sum(p.pw_uid == receipt['uid'] for p in pwd.getpwall()) == 1, 'controller UID aliases refused')
    require(receipt['uid'] not in [0, registry['operatorUid'], *registry['appUids']], 'controller UID collision')
    reserved = namespace_record(strict_json(read_file(RESERVATIONS / (store + '.json'), 0, 4096, required_mode=0o644)))
    actual = namespace_record(strict_json(read_file(base / 'namespace.json', 0, 4096, required_mode=0o644)))
    require(reserved == actual and (actual['controllerUid'], actual['controllerGid']) == (receipt['uid'], receipt['gid'])
            and actual['operatorUid'] == registry['operatorUid'] and actual['operatorGid'] == registry['operatorGid']
            and actual['deploymentId'] == registry['deploymentId'] and actual['hostId'] == registry['hostId'], 'controller allocation reservation differs')
    m = metadata(base / 'home', receipt['uid'], 0o700)
    require([m.st_dev, m.st_ino] == receipt['homeIdentity'], 'controller home replaced')
    return registry, base, receipt


def create(store, helper):
    registry, base = store_context(store, helper)
    name = 'mini-c-' + store
    require(not base.exists() and not base.is_symlink(), 'controller resources already exist')
    require(not (HISTORY / (store + '.json')).exists(), 'removed controller identity cannot be silently reused')
    require(not any(p.pw_name == name for p in pwd.getpwall()) and not any(g.gr_name == name for g in grp.getgrall()),
            'controller account/group name already exists')
    identity = allocate_identity(registry['operatorUid'], name)
    namespace = {'protocol': 'mini-spk-controller-namespace-v1', 'store': store,
                 'deploymentId': registry['deploymentId'], 'hostId': registry['hostId'],
                 'operatorUid': registry['operatorUid'], 'operatorGid': registry['operatorGid'],
                 'controllerUid': identity, 'controllerGid': identity, 'account': name}
    namespace_record(namespace)
    if not RESERVATIONS.exists(): mkdir(RESERVATIONS, mode=0o755)
    ancestry(RESERVATIONS, {0})
    # Written before either group/account creation. Never deleted on failure or
    # removal: old resident namespaces can retain this mapping indefinitely.
    write_new(RESERVATIONS / (store + '.json'), encoded(namespace), mode=0o644)
    mkdir(base, mode=0o755)
    write_new(base / 'lifecycle.lock', b'controller lifecycle lock\n')
    write_new(base / 'pending.json', encoded({'store': store, 'name': name, 'operatorUid': registry['operatorUid']}))
    run(['/usr/sbin/groupadd', '--system', '--gid', str(identity), name])
    run(['/usr/sbin/useradd', '--system', '--uid', str(identity), '--gid', str(identity), '--no-user-group', '--no-create-home', '--no-log-init',
         '--key', 'CREATE_MAIL_SPOOL=no', '--key', 'SUB_UID_COUNT=0', '--key', 'SUB_GID_COUNT=0',
         '--home-dir', str(base / 'home'), '--shell', '/usr/sbin/nologin', name])
    a = pwd.getpwnam(name)
    require((a.pw_uid, a.pw_gid) == (identity, identity) and a.pw_uid not in [0, registry['operatorUid'], *registry['appUids']], 'allocated controller UID/GID collision')
    require(not any(g.gr_mem and name in g.gr_mem for g in grp.getgrall()), 'controller supplemental groups refused')
    mkdir(base / 'home', a.pw_uid, a.pw_gid)
    mkdir(base / 'listener', registry['operatorUid'], registry['operatorGid'])
    mkdir(base / 'reverse', a.pw_uid, a.pw_gid, 0o711)
    m = (base / 'home').stat()
    receipt = {'protocol': 'mini-spk-controller-v1', 'store': store, 'name': name, 'uid': a.pw_uid, 'gid': a.pw_gid,
               'operatorUid': registry['operatorUid'], 'operatorGid': registry['operatorGid'],
               'home': str(base / 'home'), 'homeIdentity': [m.st_dev, m.st_ino], 'units': names(store),
               'activationPeerUid': 0, 'proxyServiceUid': registry['operatorUid'],
               'controllerHome': str(base / 'home'), 'controllerUid': a.pw_uid,
               'listenerSocket': str(base / 'listener/api.sock'), 'reverseSocket': str(base / 'reverse/custody.sock'),
               'operatorSocket': str(base / 'home/operator/mini.sock'), 'operatorPeerUid': 0}
    write_new(base / 'receipt.json', encoded(receipt))
    write_new(base / 'namespace.json', encoded(namespace), mode=0o644)
    return receipt


def no_processes(uid):
    live = []
    for p in Path('/proc').iterdir():
        if p.name.isdecimal():
            try:
                if p.stat().st_uid == uid:
                    live.append(int(p.name))
            except FileNotFoundError:
                pass
    require(not live, f'controller still has processes; preserve resources: {live}')


def unit_bytes(r, base, upstream):
    home = Path(r['home'])
    stem = 'mini-spk-controller-proxy-' + r['store']
    common = ('\nNoNewPrivileges=yes\nPrivateTmp=yes\nProtectSystem=strict\nProtectHome=yes\n'
              'MemoryMax=2G\nMemorySwapMax=0\nCPUQuota=100%\nTasksMax=128\nRuntimeMaxSec=10800\n'
              'TimeoutStopSec=30\nKillMode=control-group\nUMask=0077\n')
    runtime = (f'[Unit]\nDescription=Mini isolated controller {r["store"]}\n[Service]\n'
               f'User={r["uid"]}\nGroup={r["gid"]}\n'
               f'ExecStart={base}/bin/grain-runtime serve {home}/controller.json\n'
               f'Environment=HOME={home}\nWorkingDirectory={home}/workspace\nReadWritePaths={home} {base}/reverse\n' + common)
    sock = (f'[Unit]\nDescription=Mini controller operator activation {r["store"]}\n[Socket]\n'
            f'ListenStream={home}/operator/mini.sock\nSocketUser={r["uid"]}\nSocketGroup={r["gid"]}\n'
            f'SocketMode=0600\nDirectoryMode=0700\nRemoveOnStop=yes\nAccept=no\nService={stem}.service\n')
    proxy = (f'[Unit]\nDescription=Mini fixed operator proxy {r["store"]}\nRequires={stem}.socket\n'
             f'[Service]\nUser={r["operatorUid"]}\nGroup={r["operatorGid"]}\n'
             f'ExecStart={base}/bin/mini serve-agent-operator-proxy --socket {home}/operator/mini.sock '
             f'--upstream {upstream} --config {base}/proxy/config.json --controller-uid {r["uid"]}\n' + common)
    return dict(zip(r['units'], (runtime.encode(), sock.encode(), proxy.encode())))


def acl_text(path):
    return run(['/usr/bin/getfacl', '-c', '-p', '-n', '--', str(path)], stdout=subprocess.PIPE).stdout.decode()


def grant_acl(path, uid, permission, operator, receipt_path=None):
    m = metadata(path)
    require(m.st_uid in (0, operator), 'public socket ancestry owner refused')
    before = acl_text(path)
    require(not any(line.startswith(f'user:{uid}:') for line in before.splitlines()), 'controller ACL already exists')
    # Refuse extended ACLs instead of widening their masks or changing other users.
    require(not any(line.startswith(('mask:', 'default:')) or re.match(r'(user|group):[^:]+:', line)
                    for line in before.splitlines()), 'public socket ancestry has extended ACL; explicit operator preparation required')
    entry = {'path': str(path), 'dev': m.st_dev, 'ino': m.st_ino, 'before': before}
    if receipt_path is not None:
        write_new(receipt_path, encoded(entry))
    run(['/usr/bin/setfacl', '-m', f'u:{uid}:{permission}', '--', str(path)])
    entry['after'] = acl_text(path)
    if receipt_path is not None:
        write_new(receipt_path.with_suffix('.after.json'), encoded(entry))
    return entry


def stage(store, helper, bundle_arg, bins_arg, upstream_arg, public_arg):
    registry, base, r = load(store, helper)
    no_processes(r['uid'])
    require(not (base / 'stage.json').exists() and not (base / 'stage-pending.json').exists(), 'controller stage already attempted')
    bundle, bins, upstream, public = map(canonical, (bundle_arg, bins_arg, upstream_arg, public_arg))
    op = registry['operatorUid']
    ancestry(bundle, {0, op}); ancestry(bins, {0, op})
    actual = set()
    allowed_dirs = {'custody', 'state', 'state/shared-app-refs', 'state/oracle-grant', 'workspace'}
    for directory, dirs, files in os.walk(bundle, followlinks=False):
        require(len(actual) <= len(FILES) + len(FINAL_FILES), 'controller bundle exceeds file bound')
        for n in dirs:
            child = Path(directory) / n
            require(str(child.relative_to(bundle)) in allowed_dirs, 'controller bundle directory outside allowlist')
            metadata(child, op)
        actual.update(str((Path(directory) / n).relative_to(bundle)) for n in files)
    require(set(FILES) <= actual <= set(FILES) | set(FINAL_FILES), 'controller bundle files differ from exact allowlist')
    limits = {**FILES, **FINAL_FILES}
    data = {n: read_file(bundle / n, op, limits[n], required_mode=0o600 if n.startswith('custody/') else None)
            for n in actual}
    require(all(len(data['custody/' + role + '.key']) == 32 for role in ('controller', 'tool', 'dispatch', 'provider')), 'controller key size differs')
    binaries = {n: read_file(bins / n, op, 256 * 1024 * 1024, True) for n in BINS}
    config = json.loads(data['controller.json']); host = json.loads(data['host-config.json'])
    home = Path(r['home'])
    require(config.get('commands') == [] and config.get('stateDir') == str(home / 'state')
            and config.get('controlSocket') == str(home / 'state/control.sock')
            and config.get('cwd') == str(home / 'workspace') and config.get('hostConfig') == str(home / 'host-config.json')
            and config.get('hostSocket') == str(public), 'controller configuration layout differs')
    ancestry(upstream.parent, {0, op}); um = metadata(upstream, op, 0o600)
    require(stat.S_ISSOCK(um.st_mode), 'primary operator endpoint is not a socket')
    ancestry(public.parent, {0, op}); pm = metadata(public, op)
    require(stat.S_ISSOCK(pm.st_mode), 'public endpoint is not a socket')
    units = unit_bytes(r, base, upstream)
    require(all(not (UNITS / n).exists() and not (UNITS / n).is_symlink() for n in units), 'controller unit already exists')
    require(all(manager_properties(n).get('LoadState') == 'not-found' for n in units),
            'controller unit name already loaded; replacement refused')
    pending = {'sourceBundle': str(bundle), 'files': {n: sha(v) for n, v in data.items()},
               'binaries': {n: sha(v) for n, v in binaries.items()}, 'publicSocket': str(public),
               'upstreamSocket': str(upstream), 'upstreamIdentity': [um.st_dev, um.st_ino], 'acl': [],
               'units': {n: sha(value) for n, value in units.items()}}
    write_new(base / 'stage-pending.json', encoded(pending))
    # Fresh home only; no running controller can redirect the root setup writes.
    require(not list(home.iterdir()), 'controller home is not fresh')
    for rel in ('bin', 'custody', 'state', 'state/shared-app-refs', 'state/oracle-grant', 'workspace', 'operator', 'tool-requests'):
        mkdir(home / rel, r['uid'], r['gid'])
    mkdir(base / 'bin', mode=0o755); mkdir(base / 'configs'); mkdir(base / 'proxy', op, registry['operatorGid'])
    for n, value in data.items():
        write_new(home / n, value, r['uid'], r['gid'])
    for n, value in binaries.items():
        write_new(base / 'bin' / n, value, mode=0o755)
        write_new(home / 'bin' / n, value, r['uid'], r['gid'], 0o500)
    write_new(base / 'configs' / (sha(data['controller.json']) + '.json'), data['controller.json'])
    write_new(base / 'proxy/config.json', data['host-config.json'], op, registry['operatorGid'])
    # Only traversal of private ancestors and access to the PUBLIC socket. The
    # operator's private listener and Store files receive no controller ACL.
    paths = [p for p in reversed((public.parent, *public.parent.parents)) if not metadata(p).st_mode & 0o001]
    for p, perm in [(p, '--x') for p in paths] + [(public, '-w-')]:
        pending['acl'].append(grant_acl(p, r['uid'], perm, op, base / f'acl-{len(pending["acl"]) + 1:03}.json'))
    for n, value in units.items():
        write_new(UNITS / n, value, mode=0o644)
    pending['units'] = {n: sha(value) for n, value in units.items()}
    write_new(base / 'stage.json', encoded(pending))
    run(['/usr/bin/systemctl', 'daemon-reload'])
    return {**r, 'stage': str(base / 'stage.json')}


def checked_units(base, r, partial=False):
    stage_path = base / 'stage.json'
    if partial and not stage_path.exists():
        stage_path = base / 'stage-pending.json'
        if not stage_path.exists():
            require(not any((UNITS / n).exists() for n in r['units']), 'unrecorded controller units exist')
            return {'units': {}, 'binaries': {}}
    stage = json.loads(read_file(stage_path, 0, 65536))
    for n in r['units']:
        if partial and not (UNITS / n).exists() and not (UNITS / n).is_symlink():
            continue
        require(sha(read_file(UNITS / n, 0, 16384)) == stage['units'][n], 'controller unit changed')
    for n in BINS:
        if partial and not (base / 'bin' / n).exists() and not (base / 'bin' / n).is_symlink():
            continue
        require(sha(read_file(base / 'bin' / n, 0, 256 * 1024 * 1024, True)) == stage['binaries'][n], 'controller binary changed')
    return stage


def service(store, helper, action):
    _, base, r = load(store, helper)
    checked_units(base, r, partial=(action == 'stop'))
    for name in r['units']:
        observed = manager_properties(name)
        if observed.get('LoadState') == 'not-found' and action == 'stop':
            continue
        require(observed.get('FragmentPath') == str(UNITS / name) and observed.get('Transient') == 'no',
                'controller manager unit identity differs')
        if name.endswith('.service'):
            expected = r['uid'] if name == r['units'][0] else r['operatorUid']
            require(observed.get('User') == str(expected), 'controller manager unit user differs')
    if action == 'start':
        run(['/usr/bin/systemctl', 'start', r['units'][1], r['units'][0]])
        ready = Path(r['home']) / 'state/control.sock'
        deadline = time.monotonic() + 180
        while True:
            observed = manager_properties(r['units'][0])
            require(observed.get('ActiveState') in ('active', 'activating'),
                    'controller unit exited before control readiness; inspect its journal')
            try:
                m = metadata(ready, r['uid'], 0o600)
                require(stat.S_ISSOCK(m.st_mode), 'controller control endpoint is not a socket')
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                    connection.settimeout(1)
                    connection.connect(str(ready))
                    pid, uid, _ = struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                    require(uid == r['uid'] and str(pid) == observed.get('MainPID'),
                            'controller control peer differs from exact manager process')
                break
            except (FileNotFoundError, ConnectionRefusedError, TimeoutError):
                require(time.monotonic() < deadline, 'controller control readiness timed out; no tool was sent')
                time.sleep(.2)
    else:
        present = [n for n in r['units'] if (UNITS / n).exists()]
        if present:
            run(['/usr/bin/systemctl', 'stop', *present])
        no_processes(r['uid'])
    return {'store': store, 'action': action, 'units': r['units']}


def config_update(store, helper, source_arg):
    _, base, r = load(store, helper)
    checked_units(base, r); no_processes(r['uid'])
    source = canonical(source_arg)
    proof = {}
    if stat.S_ISDIR(source.lstat().st_mode):
        actual = set()
        allowed_dirs = {'state', 'state/shared-app-refs', 'state/oracle-grant'}
        for directory, dirs, files in os.walk(source, followlinks=False):
            for n in dirs:
                p = Path(directory) / n; metadata(p, r['operatorUid'])
                require(str(p.relative_to(source)) in allowed_dirs, 'config bundle directory refused')
            actual.update(str((Path(directory) / n).relative_to(source)) for n in files)
            require(len(actual) <= 1 + len(FINAL_FILES), 'config bundle exceeds file bound')
        require('controller.json' in actual and actual <= {'controller.json'} | set(FINAL_FILES), 'config bundle files refused')
        data = read_file(source / 'controller.json', r['operatorUid'], 524288)
        proof = {n: read_file(source / n, r['operatorUid'], FINAL_FILES[n]) for n in actual - {'controller.json'}}
    else:
        data = read_file(source, r['operatorUid'], 524288)
    value = json.loads(data); home = Path(r['home'])
    require(value.get('commands') == [] and value.get('stateDir') == str(home / 'state')
            and value.get('controlSocket') == str(home / 'state/control.sock'), 'controller config layout differs')
    old = read_file(home / 'controller.json', r['uid'], 524288)
    require((base / 'configs' / (sha(old) + '.json')).is_file(), 'current config is not a retained revision')
    for name, content in proof.items():
        path = home / name
        if path.exists() or path.is_symlink():
            require(read_file(path, r['uid'], FINAL_FILES[name]) == content, 'retained grant evidence differs')
    target = base / 'configs' / (sha(data) + '.json')
    require(not target.exists(), 'configuration revision already retained')
    write_new(target, data)
    for name, content in proof.items():
        path = home / name
        if not path.exists():
            write_new(path, content, r['uid'], r['gid'])
    pending = home / '.controller-next.json'
    write_new(pending, data, r['uid'], r['gid'])
    os.replace(pending, home / 'controller.json')
    return {'store': store, 'configurationSha256': sha(data), 'previousSha256': sha(old)}


def controller_child(r, argv, setup=None):
    def identity():
        os.setsid(); os.setgroups([]); os.setgid(r['gid']); os.setuid(r['uid']); os.umask(0o077)
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256))
        if setup:
            setup()
    proc = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            preexec_fn=identity, env={**ENV, 'HOME': r['home']})
    try:
        total = 0; deadline = time.monotonic() + 1200
        sel = selectors.DefaultSelector()
        sel.register(proc.stdout, selectors.EVENT_READ, sys.stdout.buffer)
        sel.register(proc.stderr, selectors.EVENT_READ, sys.stderr.buffer)
        while sel.get_map():
            require(time.monotonic() < deadline, 'controller command timed out; retain request ID, do not resend')
            for key, _ in sel.select(1):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    sel.unregister(key.fileobj); continue
                total += len(chunk); require(total <= 16 * 1024 * 1024, 'controller output exceeds bound')
                key.data.write(chunk); key.data.flush()
        return proc.wait(timeout=10)
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait(timeout=10)


def tool(store, helper, verb, request_id, extra):
    _, base, r = load(store, helper)
    checked_units(base, r)
    require(re.fullmatch('[0-9a-f]{32}', request_id), 'request ID must be 32 lowercase hex')
    home = Path(r['home']); runtime = str(base / 'bin/grain-runtime'); socket = str(home / 'state/control.sock')
    if verb == 'tool':
        require(len(extra) == 2 and extra[0] in TOOLS, 'unsupported controller tool')
        data = read_file(canonical(extra[1]), r['operatorUid'], 262144)
        require(isinstance(json.loads(data), dict), 'tool arguments must be an object')
        path = home / 'tool-requests' / (request_id + '.args.json')
        def setup():
            ancestry(path.parent, {0, r['uid']})
            write_new(path, data, r['uid'], r['gid'])
        return controller_child(r, [runtime, 'tool', socket, 'soft', request_id, extra[0], str(path)], setup)
    require(not extra and verb in ('tool-result', 'tool-ack'), 'unsupported controller result operation')
    return controller_child(r, [runtime, verb, socket, request_id])


def export_state(store, helper):
    _, base, r = load(store, helper)
    checked_units(base, r)
    root = Path(r['home']) / 'state'; files = {}; total = 0; directories = 0
    for directory, dirs, entries in os.walk(root, followlinks=False):
        directories += 1
        require(directories <= 512 and len(Path(directory).relative_to(root).parts) <= 16, 'controller evidence directory bound exceeded')
        for name in dirs:
            metadata(Path(directory) / name, r['uid'])
        for name in entries:
            path = Path(directory) / name
            if stat.S_ISSOCK(path.lstat().st_mode):
                continue
            require(len(files) < 512, 'controller evidence file bound exceeded')
            data = read_file(path, r['uid'], 8 * 1024 * 1024, allow_empty=True)
            total += len(data); require(total <= 32 * 1024 * 1024, 'controller evidence byte bound exceeded')
            files[str(path.relative_to(root))] = {'sha256': sha(data), 'base64': base64.b64encode(data).decode()}
    return {'protocol': 'mini-spk-controller-evidence-v1', 'store': store, 'files': files}


def reserve_export(store, helper, attempt_text):
    _, base, r = load(store, helper)
    require(re.fullmatch('0|[1-9][0-9]{0,19}', attempt_text) and int(attempt_text) < 2**64,
            'dispatch attempt ID must be canonical decimal u64')
    prefix = f'agent-lifetime-reserve-{int(attempt_text):016}'
    root = Path(r['home']) / 'state' / prefix
    files = {}; total = 0
    for name in ('source.json', 'pin.json', 'request.bin', 'plan.bin', 'plan.frame',
                 'call.bin', 'receipt.json', 'submit-marker.json'):
        data = read_file(root / name, r['uid'], 12_102_760, required_mode=0o600)
        total += len(data)
        require(total <= 32 * 1024 * 1024, 'selected reserve evidence exceeds byte bound')
        files[prefix + '/' + name] = {'sha256': sha(data), 'base64': base64.b64encode(data).decode()}
    return {'protocol': 'mini-spk-controller-evidence-v1', 'store': store, 'files': files}


def remove(store, helper):
    _, base, r = load(store, helper)
    stage = checked_units(base, r, partial=True)
    service(store, helper, 'stop')
    # Only restore ACLs on the exact recorded objects and exact unchanged ACL.
    for path in sorted(base.glob('acl-[0-9][0-9][0-9].json'), reverse=True):
        intent = json.loads(read_file(path, 0, 16384))
        target = canonical(intent['path']); m = metadata(target)
        require((m.st_dev, m.st_ino) == (intent['dev'], intent['ino']), 'public ACL object replaced; cleanup refused')
        after_path = path.with_suffix('.after.json')
        if after_path.exists():
            entry = json.loads(read_file(after_path, 0, 16384))
            require(entry['before'] == intent['before'] and acl_text(target) == entry['after'], 'public ACL changed; cleanup refused')
            run(['/usr/bin/setfacl', '--restore=-'], input=(f'# file: {target}\n' + intent['before']).encode())
        else:
            require(acl_text(target) == intent['before'], 'incomplete ACL mutation; preserve intent receipt for operator repair')
    mounts = Path('/proc/self/mountinfo').read_text().splitlines()
    require(not any(line.split()[4].startswith(str(base) + '/') or line.split()[4] == str(base) for line in mounts), 'controller subtree has mounts')
    for n in r['units']:
        if (UNITS / n).exists():
            (UNITS / n).unlink()
    run(['/usr/bin/systemctl', 'daemon-reload'])
    no_processes(r['uid'])
    run(['/usr/sbin/userdel', r['name']])
    try:
        group = grp.getgrnam(r['name'])
    except KeyError:
        pass
    else:
        require(group.gr_gid == r['gid'] and not group.gr_mem, 'controller group changed')
        run(['/usr/sbin/groupdel', r['name']])
    if not HISTORY.exists():
        mkdir(HISTORY)
    ancestry(HISTORY, {0})
    write_new(HISTORY / (store + '.json'), encoded({'receipt': r, 'stage': stage, 'removed': True}))
    shutil.rmtree(base)
    return {'store': store, 'removedController': r['name'], 'receipt': str(HISTORY / (store + '.json'))}


def main(args):
    require(os.geteuid() == 0, 'controller setup requires root installer')
    require(len(args) >= 3, 'controller verb requires STORE HELPER')
    action, store, helper, *extra = args
    # Same global allocator lock as ordinary world setup; no nested installer call.
    if action == 'controller-check-app-allocation':
        require(len(extra) == 3, 'app allocation check requires operator/start/count')
        held = os.fstat(8); named = os.stat('/run/mini-spk-world-install.lock', follow_symlinks=False)
        require(stat.S_ISREG(held.st_mode) and held.st_uid == 0 and held.st_nlink == 1
                and not held.st_mode & 0o022 and (held.st_dev, held.st_ino) == (named.st_dev, named.st_ino),
                'inherited global allocator lock differs')
        fcntl.flock(8, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(check_app_allocation(store, helper, *extra), sort_keys=True))
        return 0
    with open('/run/mini-spk-world-install.lock', 'a') as lock, contextlib.ExitStack() as held_locks:
        fcntl.flock(lock, fcntl.LOCK_EX)
        held = None
        if action != 'controller-create':
            _, base = store_context(store, helper)
            ancestry(base, {0})
            held = os.open(base / 'lifecycle.lock', os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
            held_locks.callback(os.close, held)
            m = os.fstat(held)
            require(stat.S_ISREG(m.st_mode) and m.st_uid == 0 and m.st_nlink == 1
                    and stat.S_IMODE(m.st_mode) == 0o600, 'controller lifecycle lock custody refused')
            shared = action in ('controller-tool', 'controller-tool-result', 'controller-tool-ack',
                                'controller-journal', 'controller-export', 'controller-reserve-export')
            # Lock order is global allocator, then controller. Never wait on a
            # controller while holding the allocator: an active call gets a
            # visible busy refusal, not account/config deletion underneath it.
            fcntl.flock(held, (fcntl.LOCK_SH if shared else fcntl.LOCK_EX) | fcntl.LOCK_NB)
        if action == 'controller-create' and not extra: result = create(store, helper)
        elif action == 'controller-stage' and len(extra) == 4: result = stage(store, helper, *extra)
        elif action in ('controller-start', 'controller-stop') and not extra: result = service(store, helper, action[11:])
        elif action == 'controller-config' and len(extra) == 1: result = config_update(store, helper, extra[0])
        elif action in ('controller-tool', 'controller-tool-result', 'controller-tool-ack') and extra:
            # A long controller call must not monopolize the host installation lock.
            fcntl.flock(lock, fcntl.LOCK_UN)
            return tool(store, helper, action[11:], extra[0], extra[1:])
        elif action == 'controller-export' and not extra: result = export_state(store, helper)
        elif action == 'controller-reserve-export' and len(extra) == 1: result = reserve_export(store, helper, extra[0])
        elif action == 'controller-journal' and not extra:
            _, base, r = load(store, helper)
            result = json.loads(read_file(Path(r['home']) / 'state/journal.json', r['uid'], 8 * 1024 * 1024))
        elif action == 'controller-remove' and not extra: result = remove(store, helper)
        else: raise ValueError('unsupported controller installer arguments')
        print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f'controller setup refused: {error}', file=sys.stderr)
        sys.exit(1)

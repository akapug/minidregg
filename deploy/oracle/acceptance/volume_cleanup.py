#!/usr/bin/env python3
"""Untrusted cleanup observation, not volume authority or a mount operation.

Join an authenticated native volumes-status reply to saved broker requests and
an independent findmnt observation. The caller must have stopped its services;
the plan is a snapshot. Native unmount/destroy still enforce their own custody.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


def require(ok, message):
    if not ok:
        raise ValueError(message)


def decode(raw):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=unique)


def read(path, bound):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and 0 < before.st_size <= bound,
                'cleanup input is not a bounded regular file')
        with os.fdopen(os.dup(fd), 'rb') as source:
            raw = source.read(bound + 1)
        def identity(m):
            return m.st_dev, m.st_ino, m.st_mode, m.st_uid, m.st_gid, m.st_size, m.st_mtime_ns, m.st_ctime_ns
        require(len(raw) == before.st_size and identity(before) == identity(os.fstat(fd))
                and identity(before) == identity(path.lstat()), 'cleanup input changed while read')
        return raw
    finally:
        os.close(fd)


KEYS = ('store', 'deploymentId', 'grain', 'volumePath', 'appUid', 'sizeMib', 'volumeId')


def coordinates(request, root, store):
    require(isinstance(request, dict), 'volume request is not an object')
    grain = request.get('grain')
    require(isinstance(grain, str) and re.fullmatch('[1-9][0-9]{0,17}', grain), 'volume grain malformed')
    require(request.get('store') == store and request.get('volumePath') == f'{root}/vars/{store}-{grain}',
            'volume crosses selected world')
    require(all(isinstance(request.get(key), str) and re.fullmatch('[0-9a-f]{64}', request[key])
                for key in ('deploymentId', 'volumeId')), 'volume identity malformed')
    require(type(request.get('appUid')) is int and 65536 <= request['appUid'] < 2**32 - 1
            and type(request.get('sizeMib')) is int and 64 <= request['sizeMib'] <= 16384,
            'volume UID or quota malformed')
    return {key: request[key] for key in KEYS}


def find_mount(path):
    # TARGET output is bounded by the selected fixed path, rather than an
    # arbitrary mount's potentially large options/source descriptions.
    result = subprocess.run(['/usr/bin/findmnt', '-n', '-M', path, '-o', 'TARGET'],
                            capture_output=True, timeout=10, env={'PATH': '/usr/bin:/bin'})
    require(len(result.stdout) <= 4096 and len(result.stderr) <= 4096, 'findmnt output exceeds bound')
    return result.returncode, result.stdout, result.stderr


def plan(root, inventory, requests, observe=find_mount):
    require(isinstance(root, str) and re.fullmatch('/var/lib/mini-spk-worlds/[0-9a-f]{16}', root),
            'cleanup world path malformed')
    store = root.rsplit('/', 1)[1]
    require(isinstance(inventory, dict) and inventory.get('protocol') == 'mini-spk-volumes-status-v1'
            and inventory.get('store') == store and inventory.get('volumesRoot') == root + '/volumes',
            'native volume inventory world differs')
    volumes = inventory.get('volumes')
    require(isinstance(volumes, list) and len(volumes) <= 64 and len(requests) <= 64,
            'cleanup volume count exceeds bound')
    registered, saved = {}, {}
    for volume in volumes:
        require(isinstance(volume, dict), 'native volume entry malformed')
        bound = coordinates(volume.get('request'), root, store)
        require(bound['grain'] not in registered, 'duplicate registered volume')
        require(type(volume.get('mounted')) is bool and volume.get('settled') is True
                and volume.get('paused') is False, 'volume is not settled and unpaused')
        registered[bound['grain']] = (bound, volume['mounted'])
    for filename, raw in requests:
        request = decode(raw)
        bound = coordinates(request, root, store)
        require(bound['grain'] not in saved, 'duplicate saved volume request')
        saved[bound['grain']] = (bound, filename, raw)
    require(registered.keys() == saved.keys(), 'saved and registered volume sets differ')
    result = []
    for grain in sorted(saved, key=int):
        bound, filename, raw = saved[grain]
        native, mounted = registered[grain]
        require(bound == native, 'saved volume request differs from exact native registration')
        code, out, error = observe(bound['volumePath'])
        absent = code == 1 and out == b'' and error == b''
        present = code == 0 and out == (bound['volumePath'] + '\n').encode() and error == b''
        require(absent or present, 'findmnt returned an error or an unexpected exact target')
        require(mounted == present, 'native and independent mount observations disagree')
        result.append({'grain': grain, 'action': 'unmount' if present else 'already-unmounted',
                       'requestFile': filename, 'requestSha256': hashlib.sha256(raw).hexdigest(),
                       'request': {**bound, 'verb': 'unmount'},
                       'nativeMounted': mounted, 'findmntExit': code})
    return {'protocol': 'mini-oracle-volume-cleanup-plan-v1', 'store': store,
            'root': root, 'volumes': result, 'scope': 'stopped-service physical observation only'}


def main(args):
    require(len(args) == 2, 'usage: volume_cleanup.py GRAINS_ROOT NATIVE_STATUS_JSON')
    root, status = args
    # Bound directory enumeration before globbing; broker files are operator
    # owned, and still cannot select an unregistered volume or foreign path.
    entries, requests = 0, []
    with os.scandir(Path(root) / 'broker') as directory:
        for entry in directory:
            entries += 1
            require(entries <= 4096, 'broker directory enumeration exceeds bound')
            if re.fullmatch('volume-[^/]+[.]json', entry.name):
                require(len(requests) < 64, 'saved volume count exceeds bound')
                requests.append((entry.name, read(Path(entry.path), 16384)))
    raw = read(Path(status), 65536)
    result = plan(root, decode(raw), requests)
    result['nativeStatusSha256'] = hashlib.sha256(raw).hexdigest()
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit('volume cleanup observation refused: ' + str(error))

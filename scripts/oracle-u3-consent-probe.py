#!/usr/bin/env python3
"""Startup and frame-only check on retained settings; no admission or signing."""
import hashlib, json, subprocess, sys
from pathlib import Path
old, new, config, out = map(Path, sys.argv[1:])
out.mkdir(mode=0o700, parents=False, exist_ok=False)
raw = config.read_bytes()
def sha(b): return hashlib.sha256(b).hexdigest()
def check(name, binary, path, expected, refusal=None):
    result = subprocess.run([str(binary), str(path), 'stdio'], input=b'\x01\x00\x00\x00\xe9', stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    (out / (name + '.stdout')).write_bytes(result.stdout)
    (out / (name + '.stderr')).write_bytes(result.stderr)
    if expected == 'ready':
        assert result.returncode == 0 and result.stdout == b'\x01\x00\x00\x00\xe9', (name, result.returncode, result.stdout, result.stderr)
    else:
        assert result.returncode != 0 and result.stdout == b'' and refusal.encode() in result.stderr, (name, result.returncode, result.stdout, result.stderr)
    return {'exit': result.returncode, 'stdout_sha256': sha(result.stdout), 'stderr_sha256': sha(result.stderr)}
parsed = json.loads(raw)
assert parsed.get('agentLifetimeDispatchTargets'), 'fixture lacks lifetime authoring metadata'
store = Path(parsed['storageRoot'])
anchor = Path(str(store) + '.head-anchor')
database = store / 'forward-link.sqlite3'
store_before, anchor_before = sha(database.read_bytes()), sha(anchor.read_bytes())
results = {'old_retained': check('old-retained', old, config, 'refused', 'unsupported settings in client consent provider'), 'new_retained': check('new-retained', new, config, 'ready')}
for label, key, value in [('unknown-nonnull', 'reviewUnknownSetting', True), ('empty-targets', 'agentLifetimeDispatchTargets', []), ('nontable-targets', 'agentLifetimeDispatchTargets', [None]), ('too-many-targets', 'agentLifetimeDispatchTargets', [{}] * 9)]:
    modified = dict(parsed); modified[key] = value
    path = out / (label + '.json'); path.write_text(json.dumps(modified, separators=(',', ':')))
    reason = 'unsupported settings in client consent provider' if label == 'unknown-nonnull' else 'agentLifetimeDispatchTargets metadata requires one to eight objects'
    results[label] = check(label, new, path, 'refused', reason)
assert sha(config.read_bytes()) == sha(raw), 'retained settings changed'
assert sha(database.read_bytes()) == store_before and sha(anchor.read_bytes()) == anchor_before, 'retained Store or anchor changed'
receipt = {'schema':'oracle-u3-consent-startup-v1','passed':True,'scope':'retained settings startup and pre-admission frame 233 only; no source admission or signing', 'config_sha256':sha(raw), 'old_binary_sha256':sha(old.read_bytes()), 'new_binary_sha256':sha(new.read_bytes()), 'store_sha256':store_before, 'head_anchor_sha256':anchor_before, 'checks':results}
(out/'report.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt, indent=2))

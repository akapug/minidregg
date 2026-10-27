#!/usr/bin/env python3
"""Join saved cold evidence and later warm controls; perform no replay."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
a, b = root / 'probe-a', root / 'probe-b'
def digest(data): return hashlib.sha256(data).hexdigest()
def file_digest(path): return digest(path.read_bytes())
def require(value, message):
    if not value: raise RuntimeError(message)
old, new = (json.loads((p / 'report.json').read_bytes()) for p in (a, b))
require(file_digest(a / 'report.json') == '93502a642090d7095f74ce3a5665f6284937d56efdde647ac3d430e24bc580c3', 'original failed receipt changed')
require(new['passed'] and new['mode'] == 'resident-only' and new['canonical_wrong_claim_checked'], 'resident controls incomplete')
for key in ('host_sha256', 'config_sha256', 'plan_sha256', 'committed_sha256'):
    require(old[key] == new[key], f'{key} changed')
cold = (a / 'cold.json').read_bytes()
require(digest(cold) == '3a9fe14762a92461d0553835d4c166d19aebb442e48b8b03dcd822a06406ccf3', 'cold changed')
for path in (a/'served-first.bin', a/'served-repeat.bin', b/'served-first.bin', b/'served-repeat.bin', b/'served-after-refusals.bin'):
    require(path.read_bytes() == b'\x9b' + cold, f'cold/served mismatch: {path}')
for label in ('malformed-pair', 'public-denied'):
    require((b / (label + '.bin')).read_bytes() == b'\xfeoperation unavailable on selected socket', f'{label} transport refusal changed')
for label in ('trailing-claim', 'mismatched-committed'):
    require((b / (label + '.bin')).read_bytes()[:1] == b'\xff', f'{label} source refusal changed')
source = Path('/othersys/oracle-acceptance-20261027/run-v4-r2/world/store/base/workroom')
for path, expected in ((source/'store/forward-link.sqlite3','8780ec2c405566c767a2da7c6ac4d3c02fcdf59e70ddb0396090ce6d537f5ac6'),(root/'store/forward-link.sqlite3','8780ec2c405566c767a2da7c6ac4d3c02fcdf59e70ddb0396090ce6d537f5ac6'),(source/'store.head-anchor','6b044de9fa9adc47e8820ce4a67609aa19996672e12c4d8d352b3502e8ee0e27'),(root/'store.head-anchor','6b044de9fa9adc47e8820ce4a67609aa19996672e12c4d8d352b3502e8ee0e27')):
    require(file_digest(path) == expected, f'physical history changed: {path}')
pid, ticks = (root/'services/operator.pid').read_text().split()
require(Path('/proc', pid, 'stat').read_text().split()[21] == ticks, 'resident identity changed')
receipt = {'schema':'mini-stop-inspection-continuation-v1', 'passed':True,
  'scope':'Saved cold comparison plus later controls in the same unchanged resident; no additional cold replay or append',
  'original_report_sha256':file_digest(a/'report.json'), 'resident_report_sha256':file_digest(b/'report.json'),
  'cold_sha256':digest(cold), 'operator_pid':int(pid), 'operator_start_ticks':int(ticks),
  'host_sha256':new['host_sha256'], 'config_sha256':new['config_sha256'], 'plan_sha256':new['plan_sha256'], 'committed_sha256':new['committed_sha256'],
  'cold_seconds':old['measurements']['cold']['seconds'], 'first_served_seconds':old['measurements']['served-first']['seconds'],
  'warm_repeat_seconds':old['measurements']['served-repeat']['seconds'],
  'controls':new['refusal_boundaries'], 'canonical_wrong_claim_checked':True,
  'source_and_copied_store_and_anchor':'hashes unchanged'}
out = root/'continuation-receipt.json'
with out.open('x') as f: json.dump(receipt, f, indent=2); f.write('\n')
print(json.dumps(receipt, indent=2))

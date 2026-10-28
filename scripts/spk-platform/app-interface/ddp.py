"""Bounded DDP conformance transport: per-member connection, no reconnect/replay.

WebSocket framing is delegated to websocket-client in the live row. This state
machine consumes decoded DDP messages, so its races are testable without a grain.
"""
import json
import time
import uuid
from binding import Refusal, Uncertain, resolve


class DDP:
    def __init__(self, channel, limit=1000, seconds=30):
        self.channel, self.limit, self.seconds = channel, limit, seconds
        self.documents = {}
        self.result = {}
        self.updated = set()
        self.received_bytes = 0

    def send(self, value):
        self.channel.send(json.dumps(value, separators=(',', ':')))

    def pump(self, deadline):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('DDP deadline')
        self.channel.settimeout(remaining)
        raw = self.channel.recv()
        if not isinstance(raw, str) or len(raw.encode()) > 1048576:
            raise Refusal('ddp-frame-invalid-or-oversize')
        self.received_bytes += len(raw.encode())
        if self.received_bytes > 4 * 1048576:
            raise Refusal('ddp-buffer-over-bound')
        try:
            m = json.loads(raw)
        except ValueError:
            raise Refusal('ddp-frame-invalid') from None
        if not isinstance(m, dict):
            raise Refusal('ddp-frame-invalid')
        kind = m.get('msg')
        if kind in ('result', 'added', 'changed', 'removed', 'nosub') and not isinstance(m.get('id'), str):
            raise Refusal('ddp-frame-invalid')
        if kind in ('added', 'changed', 'removed') and (
                not isinstance(m.get('collection'), str) or not isinstance(m.get('fields', {}), dict)):
            raise Refusal('ddp-frame-invalid')
        for field in ('methods', 'subs', 'cleared'):
            if field in m and (not isinstance(m[field], list) or any(not isinstance(v, str) for v in m[field])):
                raise Refusal('ddp-frame-invalid')
        if kind == 'result' and 'error' in m and not isinstance(m['error'], dict):
            raise Refusal('ddp-frame-invalid')
        if kind == 'ping':
            self.send({'msg': 'pong', **({'id': m['id']} if 'id' in m else {})})
        elif kind == 'result':
            self.result[m['id']] = m
        elif kind == 'updated':
            self.updated.update(m.get('methods', []))
        elif kind in ('added', 'changed', 'removed'):
            key = (m['collection'], m['id'])
            if kind == 'removed':
                self.documents.pop(key, None)
            elif kind == 'added':
                self.documents[key] = {**m.get('fields', {}), 'id': m['id']}
            elif key not in self.documents:
                raise Refusal('ddp-change-without-document')
            else:
                self.documents[key].update(m.get('fields', {}))
                for field in m.get('cleared', []):
                    self.documents[key].pop(field, None)
                self.documents[key]['id'] = m['id']
            if len(self.documents) > self.limit or len(json.dumps(list(self.documents.values())).encode()) > 1048576:
                raise Refusal('ddp-snapshot-over-bound')
        elif kind in ('failed', 'error'):
            raise Refusal('ddp-protocol-refused')
        if len(self.result) + len(self.updated) > self.limit * 2:
            raise Refusal('ddp-buffer-over-bound')
        return m

    def connect(self):
        self.send({'msg': 'connect', 'version': '1', 'support': ['1']})
        end = time.monotonic() + self.seconds
        while self.pump(end).get('msg') != 'connected':
            pass

    def begin(self, method, params, mid=None):
        mid = mid or uuid.uuid4().hex
        self.send({'msg': 'method', 'method': method, 'id': mid, 'params': params})
        return mid

    def finish(self, mid, mutation=False):
        end = time.monotonic() + self.seconds
        try:
            while True:
                result = self.result.get(mid)
                if result and 'error' in result:
                    # Preserve the app's error code, never echo private error text.
                    raise Refusal('ddp-method-refused', str(result['error'].get('error', 'unknown')))
                if result is not None and mid in self.updated:
                    return result.get('result')
                self.pump(end)
        except (OSError, EOFError, Refusal) as e:
            if mutation and not (isinstance(e, Refusal) and e.name == 'ddp-method-refused'):
                raise Uncertain('dispatch-uncertain', 'DDP result/updated incomplete') from e
            raise

    def authenticate(self, auth, post):
        token = uuid.uuid4().hex + uuid.uuid4().hex
        mid = self.begin(auth['method'], [token])
        # Upstream client.js delays 10ms and retries rendezvous XHRs (NOT the DDP
        # method) when HTTP beats registration. Keep a bounded version of that.
        for attempt in range(4):
            time.sleep(0.01 if attempt == 0 else 1)
            status, _, _ = post({'method': 'POST', 'path': auth['postPath'].lstrip('/'), 'query': '',
                                 'headers': {'content-type': auth['contentType']}, 'body': token.encode()})
            if status == 204:
                break
            if status != 500 or attempt == 3:
                raise Refusal('auth-rendezvous-refused', str(status))
        info = self.finish(mid)
        if not isinstance(info, dict) or not isinstance(info.get(auth['userIdField']), str) or not info[auth['userIdField']]:
            raise Refusal('auth-member-required')
        return info[auth['userIdField']]

    def snapshot(self, binding, args, context):
        sid = uuid.uuid4().hex
        self.send({'msg': 'sub', 'id': sid, 'name': binding['publication'],
                   'params': resolve(binding['params'], args, context)})
        end = time.monotonic() + self.seconds
        while True:
            m = self.pump(end)
            if m.get('msg') == 'nosub' and m.get('id') == sid:
                raise Refusal('ddp-subscription-refused')
            if m.get('msg') == 'ready' and sid in m.get('subs', []):
                return {c: [v for (coll, _), v in self.documents.items() if coll == c]
                        for c in binding['collections']}

import json, sys, time, urllib.request, urllib.error
base = sys.argv[1]
H = {"X-Sandstorm-User-Id": "smokeowner1", "Accept": "application/json", "Content-Type": "application/json"}
def call(method, path, body=None):
    req = urllib.request.Request(base + path, method=method, headers=H, data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]
for _ in range(60):
    try:
        st, _ = call("GET", "/")
        if st < 500: break
    except Exception:
        pass
    time.sleep(1)
st, body = call("GET", "/api/v1/about")
print("about", st, body[:200], file=sys.stderr)
assert st == 200, (st, body)
acct = {"name": "Smoke checking", "type": "asset", "account_role": "defaultAsset", "currency_code": "USD", "opening_balance": "10.00", "opening_balance_date": "2026-01-01"}
st, body = call("POST", "/api/v1/accounts", acct)
assert st == 200, (st, body)
st, body = call("GET", "/api/v1/accounts")
assert "Smoke checking" in body, body[:300]
print(json.dumps({"status": "PASS"}))

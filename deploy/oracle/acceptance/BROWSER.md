# Private browser qualification

Fresh v6 qualification may set `ORACLE_BROWSER_B=1`, an explicit
`ORACLE_BROWSER_PORT` between 1024 and 65535, and the absolute
`ORACLE_CADDY_BIN` / `ORACLE_CADDY_SHA256` pair. Defaults keep both API routes
and do not run a browser probe. Retained v5 continuation refuses this switch.

B receives an ordinary source web session, ticket and enrollment. Its native
route pins `localhost:PORT`; the HTTP helpers use that same Host and Origin.
Caddy binds only `127.0.0.1`, uses a fixture certificate for localhost, and
forwards to B's native Unix HTTP entrance without rewriting Host or Origin.
Every application request still passes through Mini admission.

After B enrollment the journey writes `RUN/browser/ready.json` and waits up to
30 minutes. The operator forwards the same port with an owned SSH process:

```
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:PORT:127.0.0.1:PORT dregg-build
```

Use a fresh browser context at the declared HTTPS URL. Trust only this fixture
certificate/context. Check anonymous refusal, then open `/__mini/bootstrap`
and submit the token from `bootstrap_token_path` through the actual form.
Keep the token and cookie out of reports and screenshots. Inspect the rendered
root UI, use its operation catalog, and ask “Who wrote Leaves of Grass?”.
Retain the browser's response statuses and rendered answer. An authenticated
request with a different Origin must also be refused; it can be a bounded
negative transport probe through this same private TLS entrance.

Write `RUN/browser/result.json` atomically with protocol
`mini-oracle-browser-probe-v1`, the exact `url` and
`route_custodian_sha256` from readiness, `root_status`, `catalog_status`,
`query_status`, `anonymous_status`, `wrong_origin_status`,
`bootstrap_used: true`, `root_ui_rendered: true`, and `query_answer`.
This is browser evidence, not a replacement for native admission receipts.
The fixture requires successful UI/catalog/query responses, both refusal
controls, and the native bootstrap-used marker before continuing.

The edge is stopped by its recorded process identity on success or failure;
stop the separately owned SSH process by its recorded PID too. No public
listener or production deployment is created.

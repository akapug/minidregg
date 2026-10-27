# Participant HTTP entrance (custodian)

Present state of `native/spk-host/src/http_entrance.rs` and
`grain_route.rs`. Every route of a grain is served by that grain's resident
process (`spk-host resident-bootstrap`, the operator uid), one Unix socket per
route; nothing here opens a TCP listener.

## Creating a route

`spk-host grain route PROFILE APP ROUTE_REQUEST.json` derives the fixed Mini
coordinates (app, subject, session, ticket) from the participant's retained,
Mini-accepted session birth and ticket issue, and creates the route directory
`<store>/host/apps/<app>/routes/<name>/` (mode 0700) holding:

- `custodian.json` (0600, `mini-spk-custodian-v1`): the exact lowercase HTTPS
  host, the fixed coordinates as canonical decimals, the session kind
  (`web`/`api`), optional export capture, the SHA-256 of three 256-bit tokens,
  and an optional `edgeGid` (below);
- `bootstrap.token`, `browser.token`, `api.token` (0600; never printed);
- `dispatch-custody.json`, naming the participant signer the resident uses.

The request cannot choose coordinates, a key or a signing subject.

## Transport

`http.sock` is mode 0600 and admits only a peer whose SO_PEERCRED uid is the
operator. When `custodian.json` carries `"edgeGid": "<decimal, not 0>"`, the
socket is group-owned by that gid with mode 0660 and a peer whose gid is the
edge group is admitted as well (W6, for a TLS edge such as Caddy). The edge
also needs search permission on the route directory, which `hostd` requires to
be 0700; granting it is a deploy step that is not yet designed.

One HTTP/1.1 request per connection, `Connection: close`, one absolute 10 s
frame deadline, at most 64 KiB of head, 128 headers, 8 MiB of body and an
8,192-byte relative path plus query. Duplicate headers, Transfer-Encoding,
Expect, Content-Encoding, pipelining, control bytes and every caller
`X-Sandstorm-*` header are refused. Headers outside the native `requestSafe`
allowlist are dropped; Lean re-checks what remains.

`Host` must equal `expectedHost`. Browser writes and every WebSocket open need
exact `Origin: https://<expectedHost>`; `Sec-Fetch-Site`, when present, must be
`same-origin` (or `none` for a safe top-level navigation).

## Credentials

The browser visits `/__mini/bootstrap`, POSTs the bootstrap token from a
tokenless form, and receives the `__Host-mini_spk_session` cookie (Secure,
HttpOnly, SameSite=Strict, Path=/); `bootstrap.used` is written durably before
the 303. API clients send `Authorization: Bearer`. A request carrying both is
refused. Tokens authenticate use of this route's custodian only; they grant no
Mini permission, and they currently have no expiry or rotation.

## Dispatch

Each authenticated request is authored, signed by the route's custodial signer
and admitted by Lean (ops 36, 37, then 34 or route-bound 164) before one fd 3
delivery; see `MINI-CLAIM-DISPATCH-CONTRACT.md`. A failure the member can act
on is answered `mini-spk-dispatch-outcome-v1` with its status and exact retry.

Admission limits per resident: 16 queued requests (2 per subject) and 64
waiting connections (16 per subject); past them the answer is 503 `busy`.
An accept or reader-thread failure fails that connection only.

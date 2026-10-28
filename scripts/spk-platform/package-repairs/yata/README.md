# YATA semantic read endpoint repair (not a qualified package)

Apply `main.patch` and add `api.go`, `api_test.go`, `go.mod` and `go.sum` to
[upstream tag 0.1.2](https://github.com/zenhack/yata/tree/ec525b294d425675c8bcea67928d98533b4253ae).
Existing browser and form routes stay connected to the same SQLite task table.
GET `/api/todos` supplies semantic data instead of parsing the rendered UI:

- `after`: nonnegative exclusive task-ID cursor, default 0.
- `limit`: 1..1000, default 100.
- `done`: `true`, `false` or `all`, default `all`.
- Reply: `{entries:[{id,done,description}],next:integer|null}`. `next` is the last
  returned ID when more matching data exists. An empty page uses `entries:[]`.

Pages are independent reads, not an atomic multi-page database snapshot. Existing
POST forms can perform typed writes once this read endpoint is in a signed
package; the original package does not have this endpoint.

The endpoint test exercised filtered pagination, exact page end, empty results,
completed task identity/data and invalid cursor/limit/filter refusal on
`dregg-build`, under `swarm-build`. The test and a static app build passed on
2026-10-28: 47 seconds, peak 732 MiB, covering this repaired source and pinned
module inputs. No Mini/Lean build was run. The build used Go 1.27.3, official
[archive metadata](https://go.dev/dl/?mode=json), archive SHA256
`65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40`.

The experimental binary SHA256 was
`536a1beedaee771cf260acef00be78af9687957d63f719896f3a9d3ee8ac4ddd`.
Static CGO linking emitted glibc `dlopen`/`getaddrinfo` warnings; this binary is
not claimed portable or ready to package. Prefer a reviewed compatible build
or static build tags disabling unused SQLite extension loading/name resolution.

Remaining work: package the repaired app with a distinct developer signing key,
remove the old publisher's identity attestation from the changed manifest, pin
new appId/packageId, then run signed intake/lifecycle, typed writes/read-back,
native receiving-path refusals and a real agent on the same human browser grain.
The original packageId `346bff4bc867afd54320af244dc64e9c` cannot be used to claim
this new endpoint. No build was started after the build-box disk guard was
reported; artifacts and caches were preserved without deleting other work.

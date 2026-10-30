# Per-Store broker runtime adoption

Present state of `native/spk-host/src/broker_runtime_adoption.rs` and
`broker_endpoint.rs`. The broker is the operator's per-world user unit
`mini-spk-broker@STORE.service` (`USER-TENANCY.md`); nothing here is root.

## The endpoint

The broker's socket is exactly `WORLD/runtime-STORE/broker.sock`, operator-owned
mode 0600, where `WORLD` is the canonical grains root whose last component is
the Store key. A config, profile or resident config that names any other path
is refused (`broker_endpoint.rs:6-27`, `resolve`); there is no fallback
endpoint, and a client call (`call_at`) derives its endpoint from the world
root and the pinned config, never from the environment. The broker refuses to
run as root (`broker.rs:1219`) and answers only the operator's peer uid
(`broker.rs:1244`); a client connects only to an operator-owned 0600 socket in
an operator-owned 0700 directory and compares the broker's `identify` reply with
its pinned root and socket (`broker_endpoint.rs:33-52,69-96`). A broker binds
its socket before rendering units (`broker.rs:1226-1227`); an existing listener
is never unlinked, and only an operator-owned socket with no listener is
recovered, under the broker's exclusive lifetime lock
(`broker_endpoint.rs:111-155`).

START copies the endpoint into the generation's immutable resident config
(`grain.rs:1167`); the broker renders the same pin into the resident unit as
`MINI_SPK_BROKER_SOCKET` (`broker.rs:1068`), which the resident reads and
refuses unless it equals the endpoint derived from its own config
(`resident_service.rs:1295-1302`). STOP uses the retained generation's config.

## Changing the runtime (profile rebind)

A profile rebind changes the operator's pinned executables; the broker's
resident and supervisor executable changes only by adoption:

1. Restart `mini-spk-broker@STORE.service` with the manifest-pinned target
   `mini-spk-broker` (the deployment controller owns quiescence and drain; no
   consumer edits the unit).
2. `spk-host grain rebind-profile OLD_PROFILE ADMISSION` (`grain.rs:1554`); keep the returned
   immutable successor profile.
3. `spk-host grain adopt-runtime PROFILE ADMISSION` (`grain.rs:1539`); require the typed ready
   response before START under that profile.

Adoption records `broker/runtimes/STORE.json` under the world (`broker_runtime_adoption.rs:29-34`), renders the
Store's exact supervisor instance units, reloads the user manager, and only then
records `ready`. An interrupted render or reload leaves `pending`; the identical
admission completes it, a changed one refuses, and a ready retry returns the
retained supervisor set without touching active units. The response is
`mini-spk-runtime-adoption-v1` (broker protocol `mini-spk-broker-runtime-v1`)
carrying the Store, state, target executable path and SHA-256, the admission
path and SHA-256, and the supervisor instance names; the controller compares
these, never a bare exit status. `grain runtime-status PROFILE` (`grain.rs:1534`) reports
`baseline`, `pending` or `ready` (`broker_runtime_adoption.rs:115`).

Before changing runtime the broker requires the admitted original profile and
physical identity hashes, exact target image hashes, completed STOP records for
every retained generation, and stopped resident and supervisor units with empty
cgroups and no queued job; an unknown installed generation refuses. Pending
adoption refuses launch, ingestion, placement and class changes
(`require_not_pending`, `broker.rs:865,910`). Every new
resident installation carries its expected runtime hash, so a historical unit
cannot start under a newly adopted runtime.

`grain current-profile BASELINE` (as the operator, with the original
`STATE_ROOT/grain-host.json`) prints `mini-spk-current-profile-v1` (`grain_profile_upgrade.rs:486`) with the
Store, profile and its SHA-256, executing no Host.

None of this has a recorded run on a deployed world: a joined-candidate
upgrade, adoption, START and browser journey is still required.

# Agent dispatch event21 lower source checkpoint

This records an earlier component-only checkpoint. The later source-qualified
Replay/receiver/authoring cut is [AGENT-EVENT21-REPLAY.md](AGENT-EVENT21-REPLAY.md);
its hashes and scope supersede the pending-work statements below.

The five new Lean modules compile in dependency order in the private Persvati
snapshot `/home/ember/build/minidregg-dispatch-final-20260927-spkcompat`. This
is a **component-only** gate. It does not prove that either historical event
belongs to the current verified replay, does not perform CAS, does not mint a
delivery permit, and has no native HTTP/app integration test.

| Source | SHA-256 | Compiled OLean SHA-256 |
| --- | --- | --- |
| `Kernel/ApplicationDispatchAgentReserveContext.lean` | `e6fc053f1c9665d35a5cbd35d39eda2657d9e3bef9ade17fcc513e446c057798` | `b06239ef0b64e3b95b2e744f541f35354ca63b532dac986536d53feb3265073c` |
| `Kernel/ApplicationDispatchAgentPayer.lean` | `47e217555b4d4165c635c3b2a8951b7730acb3b7158c46129d45c27ec7359b00` | `b8641eb33b9e3fec99bcc1600339fff7d2efb3aba731e6dbcb3a0895a0e3301b` |
| `Kernel/ApplicationDispatchAgentReserveCore.lean` | `3a06b8398448ea48fb9c2c9605bf274d8ccc1e90ae74e7d3acea3288e3edc6c7` | `04fa5207650bc304979fc6530c434ed1ca74a06241e0905fcc7b961e137fcdcc` |
| `Kernel/ApplicationDispatchAgentIngress.lean` | `f12062899371abee8a76e03cc78535060eb4e6550d757454d85035c915a8d951` | `9785980a7dc70bbdf9efcfda7d2439227f11c2639e5379ff5f91c0aa91935aa6` |
| `Kernel/ApplicationDispatchAgentCore.lean` | `b8f6ba3cba0870c4b2467087f9564b8bf3da9c32c9cec56f9373bd14fd9c5344` | `e87e851f6d47e22d1d7aeb91c694c862d5a907ec717ab1096d6ea49a27131328` |

Each module was copied to that snapshot and compiled serially with
`LEAN_NUM_THREADS=2 /home/ember/.elan/bin/lake env lean
Kernel/<Module>.lean -o <matching OLean>`. Final `Core` log is
`/tmp/ApplicationDispatchAgentCore-spkcompat.log`, empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
No `sorry` occurs in the five sources. This does not certify a whole-project
build or a source-matched native Host route.

The private snapshot's `NativeHostContext.lean` source is SHA-256
`4a3e30ae9a9d0fcf17e80ae0b24f725cfa71edde7871b2c10f24819a4b98583d`,
while the current shared source is
`e88927f66ab0b1e806e9842e6d67c0f74b551a433acd83318eeeb0bd81c036d4`
after completion-custodian changes. Thus this gate is explicitly **not** a
current-HEAD dependency-closure verdict. AdmissionIngress, HistoricalCore,
Projection, and Pending source hashes do match the shared tree. A coherent
recompile after the current NativeHostContext cut is required before routing.

That recheck subsequently passed against the certified 589b62c source/OLean
snapshot `/home/ember/build/minidregg-overnight-20260927-completion-next`
without modifying it. A separate tiny overlay at
`/home/ember/build/minidregg-event21-lower-check` symlinks its certified
OLEANS and contains only these five new sources and their emitted OLEANS.
The base pins `NativeHostContext` source/OLean
`e88927f66ab0b1e806e9842e6d67c0f74b551a433acd83318eeeb0bd81c036d4` /
`57f2364ea0a1d960328aa4a4e6c8f961d0072b662c45e54f359e615a3b637616`
and `NativeHostReplay` source/OLean
`1f2c08b57982a71da594c1e58d288f34859cecb49b76cbe4710e1b81ec35ac5b` /
`f713c0dcd4ac30c2f642362e28f4ec99a7bc33a6ca65607a8fe0c554f18546f8`.
Serial direct Lean PASS produced overlay OLean hashes, in the table order above:
`b06239ef0b64e3b95b2e744f541f35354ca63b532dac986536d53feb3265073c`,
`903a42774e02fb02f12754ee77660a163e1af94101bc6164c54b39ee9706ebb3`,
`f096a634305c67f8328c031e803d4059c86932acda5a0e85e690d3ab501dd3b0`,
`9785980a7dc70bbdf9efcfda7d2439227f11c2639e5379ff5f91c0aa91935aa6`,
`635a3c63f0dc104517564af86e882fb4f5a223f317470c776e25bad5b306bbf6`.
`/tmp/ApplicationDispatchAgentCore-event21-head.log` is empty (SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
This qualifies the lower source chain on the current native closure, still
without event21 replay/CAS/permit or physical integration.

`ReserveContext` binds exact deployment/profile, app/session/ticket, parent,
dedicated purse and payer, charge, operation and the source-derived digest of
the canonical HTTP bytes into the ordinary reserve nonce. Its named
`matches_request` theorem pins that digest and operation ID to the one full
request in the event21 wrapper. `Payer` checks a separate current signed AgentGrain
no-op against the held purse at the same image. `ReserveCore` requires native
accepted original reserve, complete record equality, and selected receipt
transaction/event equality but deliberately does
not assert chronological membership. `Core` combines current app and payer
checks into a candidate event21 intent with a physical purse read guard and
one-use original-reserve claim nullifier. Its named theorem proves the purse
guard's expected root equals the same durable image's current root, and another
excludes mistaking
event21 for a human event11. Replay must insert original reserve
evidence only after an admitted step advances and validates, retain no-later-
purse-write continuity, and use this same lower intent for original event21
replay and live admission. The committed permit remains a separate receiver
cut after exact CAS/readback.

The canonical event21 wrapper contains the full HTTP request once. The reserve
context carries only its source-derived digest and explicit operation ID. The
host author/assembly route must compute this exact context from the fixed
custodian and canonical request, not accept a caller-authored digest as proof.

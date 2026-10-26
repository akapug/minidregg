# Resource transaction encoding benchmark image (2026-09-27 UTC)

This Mac image derives from the certified [qualified fn-only own-R stable
host](../2026-09-26-mini-provider-ownr-stable/README.md). The source changes
are `Kernel/ResourceTransaction.lean` SHA-256
`9f46c56f8eb50e0660c8b499b1b1ab5e8b4d8b3f1c81d877eacdb2b1a7034f38`
(committed `8a81fa8`), which reuses canonical command encoding and framing,
and a proof-only `Kernel/DeclaredResourceController.lean` update (committed
`751d0d6`) SHA-256
`2767840bcf40820a0a54816ba572ff7a7d28010f227e7e6fd5cc1326750cd35e`.
The latter rewrites through the general `requestFor_eq_reference` theorem to
preserve the existing effect digest equality. The changed request theorem and
the controller proof passed narrow Lean checks before the native build.

The guarded build validated 128 earlier source/Lean artifacts, 42 unchanged
later sources, 2,933 package modules, the baseline binary, and the toolchain.
It compiled the complete 44-module dependent suffix (129–172), linked 3,105
response objects, and rechecked all 172 source modules and recorded output
artifacts. The no-argument `usage_exit=1` is expected.

The immutable executable is
`/tmp/minidregg-overnight-20260926/minidregg-host-provider-ownr-resource-transaction-v2`,
SHA-256 `67dc3a390e3a40ad99081c249b6102c753d45b30cb36e478c391039e3e4bf251`.
The [manifest](mac-manifest.txt), [source hashes](mac-source-sha256.txt),
[artifact hashes](mac-artifact-sha256.txt), and
[incremental validation](mac-incremental-validation.txt) pin its build.

This is source and build certification for an isolated copied-Store timing
comparison. It does not claim a performance gain, byte-equivalent runtime
outcome, or deployment until that separate benchmark completes.

# perf-codec-writer: continuation state (2026-10-28)

## Commits on lane/perf-codec-writer
- 9c205b57c: StreamCodec writer (`encodeInto`, with `encodeInto_spec`, both defaulted). Native writers
  for nat/byte/bool/literal/option/sum/product/xmap/refine/list/bytesStream/entryStream/unitStream.
  Plus `@[csimp] encode_eq_encodeViaWriter`, placed before `toLawful`.
- 00580de11: StoreCodec `@[csimp]` `leavesUnder_eq_written` / `rootOfLeaves_eq_written` (buffers
  plus the cSHAKE/KMAC kernels, so the `pushList` copy is gone).
- 7869fb8ec (UNCHECKED, never built): moves `tagCursor`/`withTagCursor`/`one_octet_tag` from StoreCodec
  into Tower256ConcreteBackend and wraps the one-octet tag codecs drawRole/columnRole/reprEqRole/
  workKind (Tower), scalarCodec/discipline (WorldKindDescriptor) and instanceSpace (WorldKindCell)
  in them. It deletes the three identical non-native `finStream`s (WorldKindDescriptor,
  HyperdocumentCell, Tower256AdditiveFriRawDeployment) in favour of `StreamCodec.fin` = `xmap (refine nat (· < size))`.
  Likely reds: `one_octet_tag` on an inline struct literal (the Kernel users `unfold` a named def
  first); the `wireRoundtrip` `rfl` in `StreamCodec.fin`.

## Checked
On dregg-build, at 9c205b57c plus the StoreCodec part: Compiler.Tower256ConcreteBackend,
Compiler.FiniteDependentMapCodec, Compiler.StoreCodec and 13 downstream modules (WorldSystemCodec,
SystemCell, StreamCell, HyperdocumentCell, CredentialAuthorityCell, DeclaredEffectCell,
ObjectAudienceCodec, DeclaredResourceProjection, PolicyRecordCodec, FieldClosure,
WorldKindDescriptor, ProtectedCell, PayCell, PolicySourceCell, NockProgramCodec) are green.
The emitted C confirms that the product writer threads one buffer and that leavesFast/rootOfLeaves
call the written variants.

## Unchecked
Compiler.DurableReceiverCore, Kernel.NativeHostReplay, Host.Main and the rest of the tree, for all
three commits. 7869fb8ec is entirely unbuilt: it touches Tower256ConcreteBackend, StoreCodec,
WorldKindDescriptor, WorldKindCell, HyperdocumentCell, Tower256AdditiveFriRawDeployment, plus the
Kernel users of withTagCursor (ClockCell, PlatformCellLayout, PayCell, SystemCell).

## Closure run in flight (dregg-ref)
- Worktree: /srv/lanes/perf-codec-writer, a `git clone --shared` of /build/minidregg, at 00580de11
  (its .lake was seeded from un-enroll-renew).
- Unit `pcw-before2` (lanes user unit), MainPID in /srv/lanes/pcw-state/before.pid. It runs
  /srv/lanes/pcw-state/pcw-closure.sh: a closure-lock'd `swarm-build lake build -j 4` (24G) of the
  modules above plus Host.Main, then the census, then the compiled bench. Logs:
  /srv/lanes/pcw-state/before.{build.log,census.txt,bench-build.log,bench.txt}.
- The first attempt was OOM-killed at 20G with the default -j.
- The script temporarily appends a bench lean_exe to lakefile.toml and restores it from
  /srv/lanes/pcw-state/lakefile.toml.orig at the end. If the unit dies mid-way, restore that file
  and delete BenchCodecWriter.lean from the worktree.

## Next steps
1. Read before.build.log. For reds, fix forward on 9c205b57c/00580de11.
2. before.census.txt: CursorCensus.lean evaluates `cursorNative` for every closed StreamCodec and
   `cursorReady` for every closed StoreCodec.Wire under Compiler/Kernel/Host. That is the "before"
   list. The batch-018 claim about intStream/charStream/stringStream looks wrong by construction
   (they are xmap/retract/list over nat, so native); the census decides it.
3. Check out 7869fb8ec there (`git fetch origin lane/perf-codec-writer`), lane-check the touched
   files, run the closure again (`pcw-closure.sh after`), and diff the census. Then give native
   `decodeAt` to whatever the census still lists, in the bool/sum pattern.
4. before.bench.txt is the compiled number (writer vs a closure-free list encoder, which is a
   lower bound on the old cost). Publish only the compiled number.

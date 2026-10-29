# Certify-prefix: continuation state (lane/qualify-certify-prefix)

## Goal
Under sustained writes, the certify rule starved certification: it accepted only the
exact head. It now accepts any held log prefix past the certified height. The kernel
reads past chain values only through the interface `Kernel.ChainHistory`, a class it
is generic over.

## Statement: c71fa04ec (checked)
- `Kernel/ChainHistory.lean` holds the interface, the `Faithful` contract, the rule
  `certifiable` (this is decideCertifyPrefix), and the witnesses. lane-check rc 0 on
  dregg-ref.
- The auditor af7a93e7b8ba729d4 read it as sound, with nothing vacuous. Its two asks
  are addressed in the WIP commit:
  - The doc states the liveness limit: a prefix more than L below the head reopens
    no writes.
  - The durable `holdsHead` uses the same head the tail gate reads. The gate now
    derives the record height from the history (`TailBound.recordHeight`).

## Implementation: WIP commits after c71fa04ec, partly elaborated
Checked green with lane-check on dregg-ref: Kernel/ChainHistory, Kernel/TailBound and
Compiler/DurableLogTags. Everything else below is unelaborated.
1. **One rule.** Written; unchecked except ChainHistory.
   - `TailBound.judge` and `TailBound.gate` are generic over `[ChainHistory H]` and
     call `certifiable`. New theorems: `certified_true` and
     `prefix_certify_reopens_writes`.
   - `CertifyReceiver.decideCertify` is generic over the history and maps the
     refusals. `certified_advances` is restated, and `certified_true` is new.
   - Callers now pass the history:
     - DurableReceiverIO passes `loaded`;
     - DurableServed passes a head-only `Kernel.Tip`, which is sound and certifies
       the head only;
     - NativeHostReplay passes `opened.durable`.
2. **Durable chain-at-height store.** Written; unchecked.
   - `Loaded` has two new fields, `chainLog : Array Digest` and `chainLogExact`
     (equal to `chainPrefixes logStart accepted`). Every constructor is updated:
     open, extend (push), rebase, build, prefixAt, prefixOwn and loadImage.
   - The `ChainHistory (Loaded _)` instance and `Loaded.faithful` (against
     `chainAfter`) live in Compiler/DurableReceiverCore.lean.
   - DurableLogTags gains `chainPrefixes_length`, `chainPrefixes_take` and
     `chainPrefixes_snoc`.
   - TokenCensus prose is updated for `certified_advances` and
     `AcceptedCertify.sound`.
3. **Client.** Written; Rust untested. `native/resource-client/src/checkpoint.rs`
   re-plans only on staleAuthority, staleSystem, factoryUnavailable and notAdvancing.
   chainMismatch and heightUnavailable are now final. The client still names the head
   from the view (op 173), which is the newest certifiable prefix.

## Reject.headMismatch: wire/codec question
`CertifyReceiver.Reject.headMismatch` is renamed `heightUnavailable`, at the same
position. I checked whether it is on the wire or persisted:
- No codec or persisted identity: there is no rejectCodec, and the name appears in
  no TokenCensus or codec-shapes entry.
- It reaches clients only as `repr` text in the refusal detail, and the only reader is
  checkpoint.rs, updated in the same lane.
- An old client reads the new name as unnamed, which makes the refusal final. That is
  safe.

## Next steps
- Run per-file lane-check in dependency order on dregg-ref, in the warm tree
  /build/lanes/qualify-certify-prefix (cloned from thin-birth; user lanes):
  1. Compiler/DurableReceiverCore (TailBound and DurableLogTags are green)
  4. Compiler/DurableReceiverIO
  5. Compiler/DurableServed
  6. Kernel/CertifyReceiver
  7. Kernel/NativeHostReplay (`AdmittedStep.tail_bounded` relies on the defeq
     `recordHeight durable = durable.height + 1`)
- Then the closure through closure-lock, which lane-check must not be wrapped in.
- Rust:
  `cargo test -p minidregg-resource-client --bin mini -- checkpoint::tests clock::tests`.
- Planted row: dregg-infra jcertify "certify under concurrent writes". It should
  report racedRefusals 0 for headMismatch once this lands.

## Running jobs
None. The lane-check is finished, and the imports of TailBound and DurableLogTags are
built in the warm tree.

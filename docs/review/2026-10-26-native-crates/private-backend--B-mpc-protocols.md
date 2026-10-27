# private-backend, shard B: the MPC protocol modules

| Field | Value |
| --- | --- |
| Shard | private-backend B ("the MPC protocol modules") |
| Crate | `native/private-backend` (package `mini-private-backend` 0.1.0; own `[workspace]` table at `native/private-backend/Cargo.toml` and own `Cargo.lock`; not a member of the root workspace) |
| Date | 2026-10-26 |
| Reader | Opus reader, fan-out review. Read-only: nothing built, nothing run, no test executed. Every "red", "dead" or "unreachable" claim below is by reading, with the line that shows it. |
| Files covered | 18 files, **14,944 lines**, every one read in full (table below) |
| Context read | `native/private-backend/CONSTRUCTION.txt` (406, in full), `docs/MPC-PROFILE-P2.md` (113, in full), `docs/PRIVATE-CELL.md` (94, in full: it is about `resource-client` private rooms, not this crate), `README.md` "Honest state" rows, the shard-A report (executive summary, sections 2 to 5), and, from shard A's files, the parts my modules call: `asks.rs:1-130` (Bracha), `transition_journal.rs` (all), `custody.rs:186-235`, `entropy.rs`, `private_view.rs` (all), `arithmetic_reference.rs:40-260`, `authenticated_ingress.rs:15-35,395-480`, `private_output.rs:75-100,325-345`, `native_worker.rs` (fn list), `scripts/check-rust-tests.sh` private-backend rows, `.config/nextest.toml`, `fixtures/` (listed; JSON profile read) |
| Lean searched | `Kernel/`, `Compiler/`, `Theory/`, `Assurance/`, `Selvage/`, `Host/`, `Verify/`, `Pred/`, `Effects/` for Bracha, VABA, ACS, ACSS, Sh2t, King, dZK, Beaver, secret sharing, `PrivateWorldIR`, `ObliviousEvaluator`, `JointBackend`, `MpcSealedCell`, `PrivateSuccessorCustody`; headers of the six candidate files read |

Files and line counts. "Test" counts `#[cfg(test)]` regions by brace matching (script at `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/pb-B/count.py`, output `.../pb-B/sizes.tsv`); `vaba/byz.rs` and `vaba/byz_targeted.rs` are mounted only under `#[cfg(test)]` (`vaba.rs:616-619`) so they count as test in full. Single-line `#[cfg(test)]` fields and lets inside production structs are counted approximately (plus or minus 10 lines per file).

| File | Lines | Test | Code | Protocol (paper, as the doc comment cites it) |
| --- | ---: | ---: | ---: | --- |
| `src/gather.rs` | 415 | 145 | 270 | IndexGather and IndexCoverGather, "ePrint2024/677 Algorithms3-4" (`gather.rs:1`) |
| `src/vaba.rs` | 847 | 281 | 566 | IndexVABA, "ePrint2024/677 Algorithms5-6" (`vaba.rs:1`), with two deliberate deviations from the printed predicates (`vaba.rs:4-15`) |
| `src/vaba/byz.rs` | 2,268 | 2,268 | 0 | Seeded Byzantine schedule harness for IndexVABA and IndexACS (`byz.rs:1-32`) |
| `src/vaba/byz_targeted.rs` | 273 | 273 | 0 | Constructed adversary for the Gather ACK quorum (`byz_targeted.rs:1-47`) |
| `src/acs.rs` | 335 | 158 | 177 | IndexACS "Algorithm7: selector RBC + concrete IndexVABA" (`acs.rs:1`) |
| `src/acs_store.rs` | 166 | 54 | 112 | Crash WAL driver for ACS (`acs_store.rs:1-4`) |
| `src/reconstruction.rs` | 301 | 89 | 212 | GF(2^128) `Field`, plus a hash-bound reconstruction of a committed vector that is "NOT AVSS qualification" (`reconstruction.rs:1-4`) |
| `src/dzk.rs` | 1,134 | 237 | 897 | "Appendix B hash-based distributed degree proof, compression u=2" (`dzk.rs:1`) |
| `src/dzk_store.rs` | 387 | 97 | 290 | dZK wire codec and crash WAL |
| `src/acss_id.rs` | 1,111 | 298 | 813 | "bivariate ACSS-Id consumer for Appendix B dZK + recipient PrivSend" (`acss_id.rs:1`) |
| `src/acss_id_store.rs` | 370 | 71 | 299 | ACSS-Id wire codec and crash WAL |
| `src/sh2t_id.rs` | 1,425 | 373 | 1,052 | "§6.1 Sh2t-Id: degree-2f values with random degree-2f masks" (`sh2t_id.rs:1`) |
| `src/sh2t_id_store.rs` | 498 | 142 | 356 | Sh2t-Id wire codec and crash WAL |
| `src/triple_king.rs` | 1,813 | 618 | 1,195 | "TripleKingDN random extraction and asynchronous polynomial check" (`triple_king.rs:1`) |
| `src/king_store.rs` | 1,204 | 562 | 642 | One crash WAL per holder over three ACSS-Id, three Sh2t-Id, the burn receipt and the King (`king_store.rs:1-19`) |
| `src/field_network.rs` | 1,267 | 379 | 888 | Beaver-triple evaluator of a public AND/XOR DAG over checked triples (`field_network.rs:1-5`) |
| `src/field_network_store.rs` | 428 | 127 | 301 | Initial-file plus WAL for the two evaluator runtimes |
| `src/field_network_layers.rs` | 702 | 280 | 422 | Vector masked openings by AND-depth layer (`field_network_layers.rs:1-6`) |
| **Total** | **14,944** | **6,452 (43%)** | **8,492** | |

Paper citations recorded, not fetched: the module headers name only ePrint 2024/677 (ASKS, Reliable Agreement, IndexGather, IndexCoverGather, IndexVABA, IndexACS; `asks.rs:1`, `gather.rs:1`, `vaba.rs:1`, `acs.rs:1`, and the erratum notes at `CONSTRUCTION.txt:116-138`). The dZK, ACSS-Id, Sh2t-Id and TripleKingDN headers name sections ("Appendix B", "§6.1") but no ePrint number. `CONSTRUCTION.txt:149-151` lists two "primary construction references", 2024/677 and 2024/1666; that the Appendix B / §6.1 / TripleKingDN material is from 2024/1666 is my inference from that list, not a citation in the code.

**Crate total correction.** `wc -l src/*.rs src/vaba/*.rs` gives **26,139** lines in 41 files: shard A's 11,195 plus this shard's 14,944. Shard A's "about 24.7K" undercounts by about 1.4K. With the three `#[path]`-included shared files (1,096 lines) the compiled crate is **27,235** lines.

## Executive summary

1. **Everything in this shard is test-driven research code.** No `fn main` arm, journey, systemd unit or root script reaches any protocol constructor here. The worker binary links four small items from the shard: `reconstruction::Field`, `vaba::Set` (a `BTreeSet<u16>` alias), `acss_id::correct_polynomials` and `field_network::fields` (via `private_output.rs:11,338` and `private_send.rs:12`). There are no Host operations and no network code; every message moves through in-process `VecDeque`s in tests.
2. **Protocol inventory:** Bracha RBC and Reliable Agreement (shard A's `asks.rs:40-123`) under IndexGather/IndexCoverGather, IndexVABA and IndexACS (2024/677); ACSS-Id over PrivSend rows plus dZK column degree proofs; Sh2t-Id degree-2f masked zero sharings; TripleKingDN extraction, multiplication and polynomial check; then a Beaver evaluator (sequential and layered). Every constructor requires n = 3f+1 and n <= 16. ACSS, dZK and Sh2t also require n >= 4. Every King, evaluator and output test runs at n = 4, f = 1. ACSS-Id, dZK, Sh2t-Id, VABA and ACS also have n = 7, f = 2 tests.
3. **The executed MPC path the README cites** (`README.md` MPC row, commit `cf6a4c1d`) is the single test `private_view::curious_holder_view_is_consistent_with_three_input_pairs_and_recipient_gets_256` (`private_view.rs:323-379`) and its falsifier (`:384-405`). They run `asks`, `private_send`, `dzk`, `acss_id`, `sh2t_id`, `triple_king`, `field_network::Engine::reserve*`, `field_network_layers::LayerEngine` and `private_output(_store)`. They do **not** run ACS, VABA, Gather, `reconstruction::recover`, `dzk_store`, `acss_id_store::Store`, `sh2t_id_store::Store`, `king_store` or `field_network_store`. No agreement on input sets or King sources is ever executed.
4. **No Lean statement of any of these protocols exists.** There is no Lean model of Bracha, VABA, ACS, ACSS, dZK, Sh2t, King or Beaver multiplication (grep, section 8). The Rust plus the cited papers is the only specification. The nearest Lean files are `Assurance/MpcSealedCellExecution.lean`, a 3-party threshold-2 semantic cell that disclaims MPC security (`:17-21`), and `Kernel/PrivateSuccessorCustody.lean`, a one-use journal model that is "not MPC" (`:1-5`). Neither is joined to this code.
5. **The Byzantine harness (`vaba/byz.rs`) is a meaningful test, not a tautology.** Its oracles are protocol properties checked across honest parties: agreement, Lemma 5.2 lock, Lemma 5.3 RA-input agreement, RBC and ASKS agreement, ICG binding core and cover, validity and termination. Both poles exist: the literal printed predicates stall where the implemented ones decide (`byz.rs:2101-2200`), and a lowered ACK quorum splits the core under a constructed adversary (`byz_targeted.rs:259-272`). Its limits: static corruption; Byzantine parties are mutated copies of honest machines plus a bounded fuzzer; the mutation-kill list (`byz.rs:28-32`) is prose with no mutant code in the tree; the ASKS-validity oracle uses production `dealer_key` (`byz.rs:1470-1480`).
6. **Where "spent" is decided:** `triple_king::burn_preparation` (`triple_king.rs:367-407`) pre-checks freshness in Rust (`before.reserve_batch`, `:376`), then asks the Rust anchor (shard A's `custody.rs`, request byte 2) to reserve the whole manifest. `field_network::Engine::reserve_inner` reuses the same function for every plan row (`field_network.rs:433`). No Lean export is called. `PrivateSuccessorCustody.reserve` is mirrored, not run (shard A D1). What counts as "the same material" is decided **only in Rust**: the King row identities (`triple_king.rs:216-238`) and the inventory pool id (`field_network.rs:78-99`).
7. **One-use discipline is real within a single holder's anchor.** Preparation rows are burned before any accepted share is read (`triple_king.rs:121-133`), and plan rows before any input or triple getter (`field_network.rs:433-468`). Retries replay journaled outboxes or refuse; they never re-deal: `acss_id_store.rs:268-277` refuses at the state machine (`acss_id.rs:298-303`), `dzk_store.rs:234-240` and `sh2t_id_store.rs:304-310` replay, `king_store.rs:494-517` keeps dealt flags.
8. **The one re-deal path is the shared WAL's torn-tail truncation (shard A F2), and a test asserts it as correct.** `sh2t_id_store.rs:403-436` truncates the last byte of a dealer record whose outbox had already been returned, then asserts that the dealer deals again with a fresh `/dev/urandom` seed. Under anything but honest crash-prefix storage, that is dealer equivocation.
9. **A test in this shard is red by reading, and no gate runs it.** `dzk_store::tests::store_retains_proof_randomness_and_outboxes_and_refuses_changed_identity` appends one byte to a WAL and asserts that `open` fails (`dzk_store.rs:340-346`). Since `fa84160e`, `transition_journal.rs:87-90` truncates a tail shorter than 8 bytes and opens successfully. No row of `scripts/check-rust-tests.sh` names this test.
10. **"WouldBlock after burn" is a permanent loss with a retryable error kind.** `Engine::reserve_inner` burns the full plan, then returns `ErrorKind::WouldBlock` if an input sharing is incomplete (`field_network.rs:458-461`). A retry can never succeed: the anchor refuses spent rows, and unlike `PreparedBasis::from_burned` the Engine has no rebuild-from-receipt path. The King has the same shape (`triple_king.rs:283,293`) but `KingStore::burn` recovers it through the local receipt (`king_store.rs:575-577`).
11. **Liveness against a single malicious party is absent, as the docs admit.** The King's initial opening interpolates the first 2f+1 points with no error correction (`triple_king.rs:765-779`). One bad point from any holder fails the check and burns the 6 preparation rows per holder. Fault localization yields a `Dispute` that nothing consumes (`triple_king.rs:1094-1131`; "dispute elimination ... remain open", `:4-6`). ACS exists but nothing selects King sources or input dealers with it.
12. **Committee-internal resource flaws:** unbounded retention of future-view VABA frames is pushed onto a transport that does not exist (`vaba.rs:330-337`). `correct_polynomials` does an exhaustive C(m, f+1) search on every received frame (`acss_id.rs:768-812`). The sequential Engine creates one Bracha per (AND gate, holder) on first sight (`field_network.rs:556-560`). The WAL clones the whole machine on every append (`transition_journal.rs:147`). No panic on peer bytes was found in non-test code.
13. **Secrets:** dealer seeds and input polynomials (including the input values as constant terms) are journaled in plaintext. So are input shares and triples (`field_network.rs:686-714`). There is no zeroize anywhere in the shard. Secret-bearing Sh2t and dZK structs derive `Debug` (`sh2t_id.rs:66,168,204,296`; `dzk.rs:235,474,525`). Field multiplication branches on data (`reconstruction.rs:18-32`, admitted at `:10-11`).
14. **Dead or unconsumed code:** `reconstruction.rs` except `Field` (about 250 lines); the four `IngressMachine` impls for ACS, ACSS, dZK and field runtimes, which no `Receiver` instantiates (`authenticated_ingress.rs:410-475`, `field_network_store.rs:177-192`); no ingress tag exists for Sh2t or King frames (`authenticated_ingress.rs:20-27`). Also: King fault localization, ACSS open and public reconstruction, the whole ACS/VABA/Gather stack (4,304 lines) as far as the MPC is concerned, the sequential Engine runtime (a twin of `LayerEngine`), and the doc reference to a nonexistent `vaba_store` (`vaba.rs:17`).
15. **Size verdict.** For the Hetzner demo the whole shard goes (14,944 lines; nothing on the box would run it). A research-only trim that keeps the executed MPC path plus the King crash store keeps about 9.7K lines of this shard and drops about 5.2K (section 6). The fixture producer for the width-8 adder (`emitPairs`, `Compiler.ObliviousNatRipple [deleted 212c79af]`) was deleted on 2026-10-04 in `212c79af`, so the "Lean-emitted" plan the executed path consumes is now a frozen artifact with no in-tree producer.

---

## 1. What this code is and does

### 1.0 Shared substrate this shard stands on (owned by shard A, summarized only to make the protocols readable)

- **`asks::Bracha`** (`asks.rs:40-123`) is the one reliable-broadcast primitive. `dealer: Some(d)` makes it Bracha RBC (an Echo is sent only on an Init from `d`, `:79-83`). `dealer: None` makes it Reliable Agreement (`input_ra` sends an Echo of the local input, `:67-74`). Thresholds: Ready on n-f matching Echoes or f+1 matching Readies (`:95-111`); output on n-f matching Readies (`:113-120`). Each sender is counted once per phase (`echo_senders`/`ready_senders`, `:84-93`), so equivocation cannot double-count. Every protocol in this shard is a composition of these instances plus local computation.
- **`asks::Asks`** is ASKS (ePrint 2024/677 Alg. 2). VABA uses one per (view, dealer) for rank keys (`vaba.rs:217-219`).
- **`private_send::PrivateSend`** (PrivSend) disperses a ciphertext by RBC and gates delivery of the key sharing on f+1 requests. ACSS-Id rows, dZK private proofs and Sh2t payloads all ride on it (`acss_id.rs:219-221`, `dzk.rs:617-628`, `sh2t_id.rs:367-369`).
- **`transition_journal::Journal<M: Machine>`** (`transition_journal.rs`) is the WAL under every store here. Record = 8-byte LE length + (bytes(event) ‖ bytes(outbox)) + SHA-256. On open it replays every event and requires the identical outbox (`:117-124`). `append` clones the state, applies, writes, fsyncs, then commits (`:143-166`). A failed `apply` writes nothing (`:148`). A tail shorter than 8 bytes, a length past EOF, or a bad checksum on the final record is truncated (`:87-114`).
- **`codec`** supplies the base-255 `Nat`, `Generation {invocation, command, attempt, generation, configuration}` (`codec.rs:111-124`), `Correlation {pool, row}` (`:137`), `Purpose {Triple, Coin, HolderPad, AudiencePad}` (`:154-159`), the Rust copy of the custody `Journal` with `reserve_batch` (`:245`), `extends` (`:290`) and `preserves_allocations` (`:294`), and `MAX` = 16 MiB (`:6`). **`custody::rpc`** (`custody.rs:218-229`) talks to the anchor Unix socket: request byte 0 = read the journal, 2 = batch reserve.

### 1.1 `gather.rs` (415): IndexGather and IndexCoverGather

- **`Gather`** (`:36-158`) is coin-free IndexGather. State: `valid` (locally validated indices), `informs`/`prepares` (first set per sender wins, `:112,116`), `acked`, `acks`, `accepted`, `output`.
  - Progress (`:124-154`): send INFORM(valid) to all once |valid| >= n-f. ACK any INFORM whose set is a subset of `valid`. Send PREPARE(valid) once n-f ACKs are in. Accept any PREPARE whose set is a subset of `valid`.
  - Once n-f PREPAREs are accepted, freeze the output as the union of the PREPARE sets of the first n-f accepted senders in index order (`:144-152`).
  - Set quality: every INFORM or PREPARE must have >= n-f members, all < n (`:91-97`).
  - The ACK quorum is `n - f - slack`, where `slack` is a `#[cfg(test)]` field (`:49-54,81-87`). Production is always n-f; the field exists only so `byz_targeted.rs` can build a mutant.
- **`CoverGather`** (`:160-274`) is IndexCoverGather (ICG). It has one RA (`Bracha::new(n, f, None)`) per index (`:182`).
  - Validating index j inputs 1 into RA_j (`:212-224`). An RA_j output of 1 adds j to `ig_valid` and feeds `gather.validate(j)` (`:257-264`).
  - Once |ig_valid| >= n-f the node broadcasts WITHDRAW (`:265-268`). Once n-f WITHDRAWs arrive, the ICG output is the Gather output (`:269-271`).
  - Ready relay continues after withdrawal (`:245-248`). The RA domain is `[1]` only and Init is refused (`:239-244`).
- **Messages:** `Body::{Gather(IgBody::{Inform, Ack, Prepare}), Ra(index, PhaseMessage), Withdraw}` with a 32-byte context (`:13-34`). Bytes are encoded by shard A's `consensus_wire.rs:89-128`.
- **Tests (4):** withheld party and cover freeze (`:298-326`); ready relay after withdrawal (`:327-341`); malformed and foreign sets refuse (`:342-363`). The fourth (`:364-414`) shows that a dealer outside the external-valid set can still complete ASKS: "availability is not external validity".

### 1.2 `vaba.rs` (847): IndexVABA

- **Construction** (`:183-209`): the context is SHA-256(`DREGG.INDEX.VABA.V1` ‖ Generation ‖ n ‖ f). View 0 is created at once.
- **Per view** (`View`, `:131-148`):
  - n ASKS instances (dealer j, own instance id per view via `DREGG.VABA.VIEW.V1`, `:210-219`) and `shared` (dealers whose ASKS sharing completed);
  - n prevote RBCs (`pre`) and n vote RBCs (`votes`);
  - `proposals`, a `CoverGather`, and `locally_validated`;
  - `tally` (vote RBC outputs that were admitted), `local_pre` (this node's prevote value) and `justification`.
- **Global state:** `valid` (external validity), `first` (the first validated index, which becomes view 0's prevote, `:305-315`), a single `final_ra` (RA on the decided value), `stop_after` and `output`.
- **Events:**
  - `dealer(v, coeffs)` deals this node's ASKS for view v exactly once (`:291-304`; "cannot regenerate view entropy", `:296-297`).
  - `validate(j)` (`:305-315`).
  - `receive(sender, m)` (`:316-375`): Final frames go to `final_ra` (Init refused, vote range checked, `:321-328`). Any other frame for an unentered view returns `ErrorKind::WouldBlock` "view not entered; retain reliable frame" (`:330-337`).
- **Progress** (`:376-565`), per view in order:
  1. Prevote once local_pre is set and more than f ASKS dealers have completed. Keys = the f+1 lowest completed dealers (`:397-405`).
  2. Collect prevote RBC outputs (`:406-412`).
  3. Locally validate proposal j if: its value is externally valid; it has more than f keys; its keys are all completed ASKS (**implemented predicate, not printed Alg6 L11 "P_j subset Valid_i"**, `:415-432`); and its justification is empty in view 0, or in later views has n-f entries matching the previous view's tally with the value most frequent (`:416-425`). Validated proposals are fed into the view's ICG (`:433-436`).
  4. Once the ICG outputs, start reconstruction of every completed ASKS (`:438-446`). Once every member of the ICG output is validated and all its keys are reconstructed, vote for the value of the max-rank member (`:447-489`). Rank = sum of SHA-256(`DREGG.VABA.RANK.V1` ‖ ctx ‖ j ‖ key) over its keys in Z/2^256 (`rank`, `:597-615`).
  5. Admit vote RBC outputs into the tally only if some locally validated, IG-valid proposal carries that value (**implemented: value membership, not printed Alg5 L18 "vote_j in IGValid_i"**, `:491-511`).
  6. If n-f tally entries match, input that value to `final_ra` and set `stop_after = v+1` (`:512-523`).
  7. Once the current view's tally has n-f entries, start view v+1 with the first n-f tally entries as justification and their most frequent value as prevote (`:524-545`).
- **Decision:** the `final_ra` output, if externally valid, is the output (`:558-563`).
- **Test instruments:** `Knobs` (`:166-181`) are `#[cfg(test)]` fields: `chaos` (adversarial leader choice), `printed_availability` and `printed_vote_membership` (the literal paper predicates). They are read at `:427-432`, `:462-482` and `:501-506`.
- **Tests (4)** (`:677-846`): a silent broadcaster of a valid value does not stall votes; reconstruction is gated by ICG and view binding (a future-view frame returns WouldBlock); view keys are independent and a prevote waits for availability; a real view change with an equivocating Byzantine prevote/vote and held Final traffic does not split. The last is armed in gate row `private-backend-recovery` (`scripts/check-rust-tests.sh:147-153`).
- **Doc defect:** the module comment says "Use vaba_store" (`:17`). No such module exists; the only durable driver is `acs_store` (VABA inside ACS).

### 1.3 `vaba/byz.rs` (2,268, test-only): seeded Byzantine schedule harness

- **Model stated** (`:7-19`): static corruption of at most f of n = 3f+1; authenticated reliable channels unless a `Fault` is injected (then only safety is checked); monotone, complete external validation.
- **`Proto`** (`:80-97`) abstracts Vaba and Acs. Both are implemented, including a fuzz-frame generator per protocol (`:146-148`, `:203-228`, `fuzz_vaba` `:249-336`).
- **Scheduling** (`Sched`, `:353-373`): FIFO, LIFO, Random or per-link Latency (scales 1/4/64/4096), optional `hold_final`, starved honest parties, and a view-preference bias.
- **Adversary** (`ByzSpec`, `:410-421`):
  - behaviours: silent, crash after k sends, hold traffic until view v, a twin (two real honest copies serving disjoint recipient groups = equivocation, `:404-408`), replay of banked frames under the Byzantine identity, a future-view flood, and a fuzzer;
  - mutations (`Mut`, `:377-402`): FlipShare, SplitCommit, FlipRecon, ForgeVote, ForgePre (optionally with a forged n-f justification), ForgeFinal, ForgeSelector, Relabel (view shift), NonPoly (non-polynomial ASKS shares with recomputed matching commitments, `:964-1005`), Minority (a vote plus a proposal justified by one real vote);
  - noise budget of 600 injections per party (`:518-519`, `:600`).
- **Engine** (`Sim`, `:547-1670`):
  - `apply` (`:702-748`) applies events to a backup when the sender is Byzantine, so a refused Byzantine frame leaves honest state untouched. This models `Journal::append`'s apply-to-clone.
  - It auto-deals fresh coefficients for newly entered views and flags "RUNAWAY" past 64 views per event (`:715-735`).
  - WouldBlock frames are parked per slot and re-delivered when the slot's view advances (`:766-793`).
  - A refusal of an honest-origin frame is a violation (`:796-806`).
- **Invariants:**
  - every step (`quick_checks`, `:1349-1382`): agreement on decisions; RA-input agreement (Lemma 5.3, honest `final_ra.echo_sent` all equal);
  - every 256 steps and at the end (`deep_checks`, `:1419-1590`): per-view prevote/vote RBC agreement, ASKS commitment agreement, ASKS key agreement, ASKS validity for honest dealers (`:1470-1480`, using `Asks::dealer_key` on the known coefficients), ICG binding core (intersection of honest outputs >= n-f, `:1491-1508`), binding cover against the corrected Y (`:1509-1518`), tally equals vote RBC output (`:1519-1531`), Lemma 5.2 lock on all later views and outputs (`:1540-1568`), ACS selector RBC agreement (`:1569-1588`);
  - at finish (`:1592-1669`): VABA validity, ACS validity (>= n-f indices, all validated at the decider), termination when assumptions hold, and the literal-cover escapes recorded (`:1644-1655`).
- Panics in protocol code are caught and reported as violations with the seed (`guarded`, `:1847-1871`).
- **Configuration generation** from one seed (`gen_config`, `:1693-1815`; `gen_chaos` `:1818-1822`; `gen_faulty` `:1825-1843`). Seeds come from `BYZ_FROM`/`BYZ_SEEDS`; the default is 12, and n = 7 runs get a third (`:1918-1933`).
- **Tests:**
  - sweeps (`:1949-2050`): VABA and ACS at n = 4 and n = 7, chaos at 500, 1000 and 2000 per mille, each asserting the sweep actually changed views; faulty-channel safety sweeps;
  - `printed_predicates` (`:2101-2200`): each literal paper predicate must stay safe and stall in at least one (availability) or in all 48 (vote membership) schedules where the implementation decides;
  - `pinned` (`:2203-2268`): pinned seeds with a scan fallback so a pin cannot go stale vacuously (`:2206-2228`): a decision after a view change with honest ranks, and the Lemma 4.5 cover erratum (`:2256-2267`, pinned seed 100458; matches `CONSTRUCTION.txt:116-138`).

### 1.4 `vaba/byz_targeted.rs` (273, test-only)

- A constructed n = 7, f = 2 adversary (honest 0..4, Byzantine 5 and 6) against bare `Gather` (`:48-226`). Groups validate sets a, b and c (`:172-183`). ACKs are delivered so that each honest PREPARE is sent on exactly the quorum (`collect`, `:133-148`). Byzantine PREPAREs keep each victim inside its exclusion (`:196-207`). The schedule is then completed fairly (`:209-220`).
- `byz_gather_n7_ack_quorum_targeted_core` (`:237-257`): with the real quorum the core stays >= n-f, the first PREPARE came on exactly n-f ACKs, and no victim output early. This is the non-vacuity pole.
- `byz_gather_n7_lowered_ack_quorum_splits_core` (`:262-272`): with slack 1 and 2 the three victims freeze the sets above and the core is {3,4,5,6}, size 4 < n-f.

### 1.5 `acs.rs` (335): IndexACS

- **Construction** (`:57-79`): the context is SHA-256(`DREGG.INDEX.ACS.V1` ‖ g ‖ n ‖ f). An inner VABA is built with `invocation` = that context. There is one selector RBC per party.
- **Selector payload:** `set_bytes` = count byte plus u16 LE members (`:24-30`). `read_set` (`:31-43`) refuses a count > n, a wrong length, out-of-range members and non-canonical bytes (duplicates or unsorted, by re-encoding).
- **Progress** (`:149-180`):
  - once n-f indices are validated, broadcast this node's selector Init: the first n-f validated indices, in index order (`:151-158`);
  - when selector j delivers a set with >= n-f members, all validated locally, admit j as VABA-valid (`:159-170`);
  - when VABA outputs j and selector j's set is locally validated, the ACS output is that set (`:171-178`).
- **Tests (3):** three honest parties exclude a withholding party; a malformed selector cannot admit a VABA input; an equivocating selector with duplicate faulty Echoes does not split ACS (`:202-334`).

### 1.6 `acs_store.rs` (166): ACS crash driver

- **`AcsMachine`** events (`:21-54`): tag 0 = validate(u16); tag 1 = dealer(view u64, 2 x (f+1) x 16-byte coefficients); tag 2 = receive(sender u16, bytes(ACS frame via `consensus_wire::decode_acs`)). The outbox is `consensus_wire::encode_outbox`.
- WAL identity: `DREGG.ACS.PARTY.V1` ‖ g ‖ me ‖ n ‖ f (`:59-69`).
- **`start_pending`** reads `2*(f+1)*16` bytes from `/dev/urandom` for each view needing entropy and journals them before any share leaves (`:91-102`). `replay_outboxes` is "safe to duplicate" (`:103-111`).
- **Tests (2):** a dropped dealer reply replays exact messages; a changed command refuses (`:142-165`).
- **No caller outside its own tests**, other than an `IngressMachine` impl that nothing instantiates (`authenticated_ingress.rs:410-423`).

### 1.7 `reconstruction.rs` (301)

- **`Field(u128)`** is GF(2^128) modulo x^128+x^7+x^2+x+1 (`:10-49`). Add is XOR. `mul` is shift-and-add with data-dependent branches (`:18-32`). `inv` is exponentiation to 2^128-2 (`:33-48`). The comment says functional, not constant-time (`:10-11`). This is the field of the whole MPC.
- **The rest is dead in production:**
  - `RecoveryBinding` (`:58-100`) with a commitment over generation, descriptor, holders and words (`DREGG.PRIVATE.COMMITTED.VECTOR\x01`);
  - `dealer_shares`, "Used by provisioning experiments only" (`:101-131`);
  - `recover`: exhaustive (f+1)-subset interpolation checked against the commitment, bounded by n <= 16 (`:149-198`);
  - `StockState` and `stock_state` (`:199-212`).
  - grep finds no caller of any of these outside this file's tests (section 5).
- **Tests (6),** on the field and the dead recovery.

### 1.8 `dzk.rs` (1,134): Appendix B distributed degree proof

- **`Profile`** (`:21-91`): n = 3f+1 with 4 <= n <= 16, 1 <= count <= 128, degree < n. The context is `DREGG.DZK.GF128.U2.V1` over g, n, f, count, degree and dealer.
  - `degrees()` halves until degree 1 (`:62-68`); `path_len` = log2 of next_pow2(n) (`:69-71`).
  - Private and public proof lengths are fixed functions of the profile (`:72-82`), so decoders check exact sizes.
- **`prove`** (`:325-407`):
  - a random mask polynomial from SHA-256(`DREGG.DZK.RANDOM.V1` ‖ seed ‖ ctx ‖ tag ‖ index);
  - per holder i, row = (mask(i), f_1(i), ..., f_count(i)), committed in a salted Merkle tree over next_pow2(n) leaves (padding leaves empty) (`tree`, `:161-206`);
  - Fiat-Shamir challenge mu = first 16 bytes of SHA-256(`DREGG.DZK.CHALLENGE.V1` ‖ ctx ‖ roots) (`:129-137`);
  - fold mask + sum of mu^k f_k, then repeatedly split into g0 + X^shift g1, commit each holder's (g0(i), g1(i)) and fold with a new challenge, down to degree 1;
  - the public proof is (roots, final_poly); private proof i is (mask(i), blocks, openings).
- **`verify`** (`:408-456`) checks holder i's openings against the roots and the fold chain at x = i+1, ending at final_poly(x).
- **`Dzk`** (`:591-897`): the public proof by RBC from the dealer (`:632`); one PrivateSend per holder carrying its private proof (`:617-628`).
  - `dealer` (`:667-695`) uses PrivSend key coefficients derived from the seed (`:674-683`).
  - `authorize_verification(holder, receiver)` requests delivery of holder's private proof to receiver (`:697-705`).
  - `verify_private`, `open_proof` and `transfer`/`transferred` (`:826-896`): a holder can transfer its verified values plus proof to a receiver, who re-verifies against the delivered public proof. Early transfers are queued in `pending` (`:727-748,763-773`).
  - "Delivered means bytes AVAILABLE, not valid" (`:7`). Verification yields `Accepted(VerifiedShares)` or `Rejected(RejectedProof{evidence_hash})` (`:786-822`).
- **Codecs:** `encode_public`/`decode_public` (`DREGG.DZK.PUBLIC\x01`, `:242-272`) and `encode_private`/`decode_private` (`DREGG.DZK.PRIVATE\x01`, `:273-322`), all exact-length.
- **Tests (6),** including a 7-party pipeline with two withheld parties and a malformed public proof that is delivered but rejected (`:936-1133`).
- **Soundness accounting** (CONSTRUCTION, not code): "No uniform 128-bit soundness"; about 27 bits lost at n = 16, N = 128, tau <= 4 (`CONSTRUCTION.txt:193-197`).

### 1.9 `dzk_store.rs` (387)

- **Wire** `DREGG.DZK.WIRE\x01` ‖ ctx ‖ tag (`:67-122`): tag 0 Public(phase); tag 1 Private{holder, bytes(PrivSend frame)}; tag 2 Transfer{receiver, holder, fields (<= 128), bytes(proof)}. Decoding is canonical by re-encode. `count` re-parses a Nat by scanning to 255 (`:44-57`).
- **Outbox** = Nat count (<= MAX/40) + (u16 to, bytes msg) (`:123-154`).
- **`DzkMachine`** events (`:155-202`): 0 = dealer(seed, polys); 1 = authorize_verification; 2 = receive; 3 = transfer.
- **`Store`** (`:203-290`): identity `DREGG.DZK.PARTY.WAL.V1` ‖ g ‖ profile ctx ‖ me.
  - `dealer` reads a seed from `/dev/urandom` (`:244-245`). A retry with the same polys replays **all** journal outboxes; changed polys refuse (`:234-240`).
  - `transfer` computes the receipt on the current state, then journals (`:266-276`).
- **Callers outside its tests:** only the codec, used by `acss_id_store.rs:63,114`. The `Store`/`DzkMachine` are used by tests and by an `IngressMachine` impl nobody instantiates (`authenticated_ingress.rs:460-475`).
- **Tests (2).** The first is red by reading (section 4, F-B1).

### 1.10 `acss_id.rs` (1,111): bivariate ACSS-Id

- **Construction** (`:193-255`): n = 3f+1 with 4 <= n <= 16; `count` secrets, a multiple of f+1, `groups = count/(f+1) <= 128`.
  - Per holder j: a PrivSend row instance (payload count x 16 bytes) and a dZK column instance (degree f, `groups` polynomials), each with a child generation `DREGG.ACSS.ID.CHILD.V1` (`:21-29`).
  - RBC/RA instances: one termination RA; per-holder complaint RBCs; n x n open-request RBCs; per-requester reconstruction-request RBCs.
- **Packing:** polynomials are "group-major, ell-minor, exactly f+1 coefficients each" (`:295-296`). The bivariate g(X,Y) has row g(alpha_j, Y) with coefficient k = f^(k)_ell(alpha_j) (`:306-314`), and column g(X, alpha_j) (`:330-341`). Secret k of group ell is polynomial `k*groups+ell`'s constant term; each holder's accepted share vector is laid out k-major (`:487-492`).
- **`dealer(polys, seed)`** (`:297-348`): per holder, the row by PrivSend with key coefficients from SHA-256(`DREGG.ACSS.ID.RANDOM.V1` ‖ seed ‖ ctx ‖ tag ‖ index) (`:30-37`, `:315-327`), and the column by dZK with seed `random(seed, ctx, 1, j)`. Refuses a non-dealer, a second call or wrong dimensions (`:298-304`).
- **Progress** (`:457-649`):
  - once all rows are dispersed and all columns delivered, request delivery of row i to i and of each column's proof i to i (`:461-473`);
  - verify own row against all n column proofs (`verification`, `:440-456`). All accepted: freeze `accepted_row` **before** the RA input and send termination RA 1 (`:486-502`). Any rejected: `Rejected` plus a complaint RBC (`:503-516`);
  - sharing complete = termination RA output 1 and local decided (`:650-652`);
  - **open** for a complained holder after f+1 open requests: deliver its row to everyone, build `OpenProof`s per column, and decide `FaultParty::Dealer` if any proof rejects, else `Accuser` (`:524-588`);
  - **public reconstruction** after f+1 reconstruction requests: transfer the verified column values (`:589-607`); interpolate own column at 0 from f+1 transferred points and broadcast `PublicColumn` (`:608-626`); robustly decode n-f matching points (`correct_polynomials`) (`:627-646`).
- **Helpers used crate-wide:** `polynomial` (Lagrange to coefficient form, `:737-767`) and `correct_polynomials` (`:768-812`, exhaustive (degree+1)-subset search accepting the first candidate with >= `required` supporters). The worker binary reaches `correct_polynomials` through `private_output.rs:338`.
- **Tests (6):** honest bivariate distribution; dealer disappearance plus one bad public column; complaint plus f+1 requests gating an opening and naming a false accuser; robust decoding waits for n-f; a corrupt dealer row is identified and reconstruction survives a local abort; 7-party with two faults and two local aborts (`:869-1110`).

### 1.11 `acss_id_store.rs` (370)

- **Wire** `DREGG.ACSS.ID.WIRE\x01` ‖ ctx ‖ tag 0..6 (`:51-149`); PublicColumn vectors are capped at 128.
- `count` (`:18-31`), `parse_outbox` (`:159-181`) and `dealer_event` (`:183-193`) are `pub(crate)` and reused by `king_store`.
- **`AcssMachine`** events (`:194-238`): 0 = dealer(seed, polys); 1 = request_open(holder); 2 = receive; 3 = request_public_reconstruction.
- **`Store`** (`:239-299`): identity `DREGG.ACSS.ID.PARTY.WAL.V1` ‖ g ‖ ctx ‖ me. The seed comes from `/dev/urandom` (`:273-274`). A second `dealer` refuses at the state machine (`acss_id.rs:298-303`), so a retry never re-deals; the exact outbox is in `replay_outboxes`.
- **Tests (2).** No use outside tests besides `king_store` (codec and machine) and the uninstantiated ingress impl.

### 1.12 `sh2t_id.rs` (1,425): Sh2t-Id

- **Construction** (`:334-404`): n = 3f+1 with 4 <= n <= 16; `per_group` in 1..=128; n x n groups (group/n = receiver), `count = n*n*per_group`.
  - Payload length `32*(count + n*n)` <= 65,536, plus an aggregate WAL capacity check against `codec::MAX` (`:351-359`).
  - Per holder: a PrivSend instance carrying (values, masks, n x n point hashes) (`:367-369`).
  - RBC/RA instances: a matrix RBC from the dealer; a termination RA; complaints; n x n open requests; per-holder agreement RAs; per-group recon-request RBCs (`:379-388`).
- **`dealer(polys, seed)`** (`:510-598`): count polynomials of degree 2f, plus random degree-2f mask polynomials from SHA-256(`DREGG.SH2T.ID.RANDOM.V1` ‖ seed ‖ ...) (`:518-530`).
  - Point hash = SHA-256(`DREGG.SH2T.ID.POINT.V1` ‖ ctx ‖ group ‖ holder ‖ values ‖ masks) (`:39-55`). Block hash per (holder, receiver) over n point hashes (`:56-65`).
  - The n x n commitment matrix goes by RBC (`:567`). Each holder's payload goes by PrivSend with seeded keys (`:568-593`).
  - The caller supplies zero-constant polynomials for zero sharings. **The state machine does not check the constant**; `king_store.rs:505-516` builds them with constant 0.
- **Acceptance** (`:745-784`): a holder accepts if its payload matches both its row and column blocks in the matrix (`valid_payload`, `:478-508`), freezing `accepted` **before** the RA input (`:766-769`); otherwise it rejects and complains.
- **Opening** of a complained holder after f+1 requests decides Dealer or Accuser from `valid_payload` (`:788-824`).
- **Recipient-restricted reconstruction** (`:825-923`): after f+1 `ReconRequest` RBCs for a group (`authorized`, `:719-725`), each accepted holder sends its point to the group's receiver only (`:829-846`). The receiver accepts points matching the committed hashes (`accept_point`, `:726-744`). With 2f+1 points it interpolates and checks **all n** committed positions: `Verified` or `Invalid` with evidence (`:853-910`). Otherwise, if any holder-accusation agreement RA has output, the group is terminally `AgreedAccusation` (`:911-922`).
- **Tests (7),** including coherent non-polynomial points accepted then failing the all-position check, an accusation replacing missing points, a false accuser, and 7-party degree-4 (`:1110-1424`).

### 1.13 `sh2t_id_store.rs` (498)

- **Wire** `DREGG.SH2T.ID.WIRE\x01` tags 0..7 (`:66-177`). `count`, `put_phase`, `phase`, `put_fields`, `fields` (<= 128), `parse_outbox` and `dealer_event` are `pub(crate)` and reused by `king_store`.
- **`Sh2tMachine`** events (`:222-274`): 0 = dealer; 1 = request_open; 2 = receive; 3 = request_private_reconstruction(group Nat, receiver); 4 = request_accusation.
- **`Store`** (`:275-355`): identity `DREGG.SH2T.ID.PARTY.WAL.V1`. The seed comes from `/dev/urandom` (`:317-318`). A retry with the same polys replays all outboxes; changed polys refuse (`:304-310`).
- **Tests (2).** The first asserts a re-deal after truncation (F-B2).

### 1.14 `triple_king.rs` (1,813): TripleKingDN

- **Sizes:** `per_group(n_triples, f)` = ceil((2·n_triples+1)/(f+1)) with 1 <= n_triples <= 32 and f != 0 (`:27-32`). `acss_seed_count` = (3·per_group + 1) rounded up to a multiple of f+1 (`:33-36`).
- **`PreparedSource`** (`:37-84`) pairs one dealer's `AcssId` and `Sh2tId` states with their declared generations and checks the contexts are exactly derived from those generations.
- **`PreparedBasis`** (`:100-364`):
  - `manifest` (`:172-245`) requires exactly 2f+1 sources with distinct dealers, sorted. It derives two one-use row ids per source: `Correlation{pool = SHA-256(bytes(domain) ‖ generation ‖ context), row}`, with domain `DREGG.PREPARATION.ACSS.SEEDS.V1` (row 0) or `DREGG.PREPARATION.SH2T.GROUP.V1` (row = group) (`:216-238`). IDs omit the consumer attempt so relabeling cannot refresh them (`:200-202`). The binding bytes (`DREGG.TRIPLE.KING.PREPARED.V2`) bind every source, n, f, count, group and king.
  - `reserve_new` = manifest, then `burn_preparation`, then `extract` (`:121-133`). `from_burned` = manifest, then `open_burn_receipt`, then `extract`, allocating nothing (`:139-150`). `verify_burn_standing` checks the live anchor still extends the receipt's journal (`:153-165`).
  - `extract` (`:248-354`) reads accepted ACSS shares and the group slice of Sh2t values. A rejected local sharing returns `InvalidData` "requires accusation continuation"; an incomplete one returns `WouldBlock` (`:275-294`). Randomness extraction is a Vandermonde-style combination over the 2f+1 dealers: output (index, row) = sum over column of (column+1)^row times seed (`:315-327`). This yields a, b, r (degree f), o (degree 2f zero) and `check_r` (`:328-332`).
- **`burn_preparation`** (`:367-407`) takes a file lock, reads the anchor journal, pre-checks `reserve_batch` locally, sends request 2 with `batch_request(ids, g, Purpose::Triple)`, and verifies the confirmed journal extends the old one and allocates every id to g/Triple, unconsumed. It writes the receipt (`DREGG.PREPARATION.BURN.V1` ‖ bytes(binding) ‖ g ‖ bytes(journal)) by `custody::snapshot`, reads it back, and re-reads the anchor for regression.
- **`TripleKing`** (`:547-1148`), king = `basis.king`, context `DREGG.TRIPLE.KING.DN.V1`:
  1. `start` sends z_i = a_i·b_i + r_i + o_i (degree 2f) to the king (`:648-660`).
  2. The king interpolates the **first 2f+1** points and broadcasts z by RBC (`:765-780`; "optimistic ... NOT accepted as a coin or qualified value").
  3. Each party computes c = z + r (DN multiplication; in characteristic 2, z - r = z + r). It interpolates f(X), g(X) through (a_i, b_i) for i in 0..=count, and sends the king the masked evaluations at count+1..2count (`:781-808`).
  4. The king robustly decodes the masked points (n-f matching) and broadcasts them (`:809-820`).
  5. Each party forms h(X) of degree 2count through the c_i and the products of the opened masked points, and sends `check_r` to the king (`:821-842`).
  6. The king robustly opens the challenge polynomial and broadcasts it. A party agrees (RA) only if the polynomial matches its own `check_r` (`:843-862`).
  7. After challenge agreement, refuse a challenge inside the interpolation set (`ChallengeInInterpolationSet`), else send (f(r), g(r), h(r)) to the king (`:863-886`).
  8. The king robustly decodes and broadcasts. A party RA-agrees if the polynomials match its own evaluations (`:887-915`).
  9. After check agreement: if h(r) = f(r)·g(r), output `CheckedTriples` (indices 1..=count), else `PolynomialIdentityFailed` (`:916-942`).
- **Fault localization** (`:960-1133`): the environment calls `begin_fault_localization` after a failed check. Every party sends (a, b, r) shares to the king and requests private reconstruction of every source's Sh2t group to the king (`:962-987`).
  - The king checks each Sh2t reconstruction: a nonzero constant or `Invalid` gives `Dispute{party: dealer, king}`; `AgreedAccusation` gives `Accusation{dealer, holder}` (`:1017-1057`). Otherwise it recomputes the zero shares and finds a party whose z point is inconsistent: `Dispute{party, king}` (`:1058-1092`).
  - The result goes by RBC. An `Accusation` is accepted with the verified Sh2t `Accusation` attached, after requesting an open if needed (`:1094-1131`).
- **Tests (6)** with per-holder `AnchorFixture` servers (`:1231-1294`): exact product plus refused consumer reuse; delayed local challenge; a malicious king's changed export refused; a bad initial point localized; a nonzero Sh2t dealer localized by an honest king; incomplete preparation burns before the first share read (`:1523-1741`). `prepared_from` and `checked_from_material` are the test-side material producers used by `private_view` (`:1364-1440`, `:1757-1800`).

### 1.15 `king_store.rs` (1,204)

- **Wire** `DREGG.TRIPLE.KING.WIRE\x01` tags 0..12 (`:44-142`).
- **`Shape`** (`:186-220`) is the public composite shape; its identity is hashed into `DREGG.TRIPLE.KING.PARTY.WAL.IDENTITY\x01`.
- **`KingMachine`** (`:287-433`) has 3 `AcssMachine`, 3 `Sh2tMachine`, dealt flags, `Option<TripleKing>`, `king_started`, and `seen` (hashes of applied receive events). Events:
  - 0/1 = an inner ACSS or Sh2t event for source k (receive events are deduplicated by `note_receive`);
  - 2 = burn receipt, then `from_burned`, then `TripleKing::new`;
  - 3 = King start;
  - 4 = King receive (deduplicated);
  - 5 = begin fault localization.
- **`KingStore`** (`:440-641`):
  - `open` verifies the burn still stands at the anchor (`:448-467`);
  - `apply_receive` drops an already-seen event before journaling (`:473-478`);
  - `deal_preparation` draws ACSS and Sh2t (constant-zero) polynomials and seeds from the caller's `Entropy` and deals only what is missing (`:494-517`);
  - `burn` reuses the local receipt if present, else `reserve_new`, then journals tag 2 (`:573-595`).
- **Tests (6, one `#[ignore]` child):** codec round-trip; clean reopen; dedupe; burn repaired from the local receipt; a receipt for another generation or with a flipped byte refused; kill -9 mid-King recovered with one dealer event per instance, no new allocation and an exact product (`:879-1203`). Five are armed in gate row `private-king-store` (`scripts/check-rust-tests.sh:478-487`).

### 1.16 `field_network.rs` (1,267): checked-triple evaluator

- **`InputRef`** (`:21-55`): an ACSS-Id state plus generation plus index, checked only for public context (no share getter).
- **`TripleManifest`** (`:56-100`) is the public inventory of one `CheckedTriples`. `pool_id` = SHA-256(`DREGG.CHECKED.TRIPLE.INVENTORY\x01` ‖ consumer generation ‖ ctx ‖ basis ‖ n ‖ f ‖ count), and `row(i)` = (pool, i).
- **Binding bytes:**
  - `binding` v1 (`DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01`, single inventory, `:104-120`);
  - `binding_many` v2 (`...\x02`, `:154-182`): ordered by pool id, retaining every inventory's original preparation rows; `catalog` refuses duplicate pools and aliased preparation seeds, at most 2,048 inventories, 1..=32 triples each (`:123-149`).
- **`with_boolean_inputs`** (`:187-248`) prepends Constant(true) and, for each input, Xor(x, 1) and And(x, x+1). It shifts the source graph and keeps gate order; total <= 65,536. `bit_prefix` recognizes exactly that prefix (`:249-268`).
- **`Engine`** (`:307-682`):
  - `reserve`/`reserve_many` and then `reserve_inner` (`:355-495`): `Plan::validate`, `public_ticks == 1`, input count, exact binding bytes, roster checks, row-to-stock mapping (every referenced inventory used), then **burn every plan row** through `triple_king::burn_preparation(&plan.rows, &plan.generation, &plan.encode(), ...)` (`:433`), re-read the anchor (`:434-448`), and only then read accepted input shares and triples (`:449-472`);
  - `progress` (`:582-681`) evaluates the DAG in order. Each AND broadcasts (x+a, y+b) by per-holder RBC, waits until one degree-f polynomial has n-f matching holders, and computes c + d·b + e·a + d·e (= xy in characteristic 2) (`:594-631`);
  - after the whole graph, every holder broadcasts its shares of the x·(x+1) bit checks. If the robustly opened checks are all zero, the output wires become local shares; otherwise `BitnessFailure` publishes the opened checks (`:637-678`).
  - `initial_bytes`/`restore_initial` (`:686-805`) serialize the pristine engine (plan, holder, n, f, burn journal prefix, input shares, triples) and restore it after checking the live anchor still holds every plan row.
- **Wire** `DREGG.PRIVATE.FIELD.WIRE\x01` (`:808-887`).
- **Tests (5):** two inventories with unselected tails unused; all rows burn before an incomplete input; Boolean AND for all four input pairs; a corrupt early point waits for late honest support; a non-Boolean input refused after full consumption (`:1083-1266`).

### 1.17 `field_network_store.rs` (428)

- **`FieldRuntime`** (`:25-37`) is a sealed trait over `Engine` and `LayerEngine`. `RuntimeMachine<R>` events (`:158-176`): 0 = start, 2 = receive.
- An `IngressMachine` impl binds to `Protocol::FieldNetwork` (`:177-192`); nothing instantiates it.
- **`RuntimeStore<R>`** (`:193-300`):
  - `create` writes `P.initial` = file domain ‖ bytes(initial) ‖ SHA-256 with `create_new` and mode 0600, fsyncs the file and its directory, reads it back, then opens the WAL with an identity over the initial bytes (`:212-248`);
  - `reopen` checks the checksum and frame and runs `restore_initial` against the anchor (`:249-278`).
- **Tests (2).**

### 1.18 `field_network_layers.rs` (702)

- **`Schedule::for_network`** (`:30-75`) computes AND depth per gate, groups ANDs by depth into batches of at most `MAX_BATCH_ANDS` = 1024, and keeps tuple positions in canonical gate order.
- **`LayerEngine`** (`:107-401`) takes a pristine burned `Engine` (`pristine_material`, `:129`). Per batch it broadcasts all masked (x+a, y+b) pairs as one vector RBC and requires **one** degree-f polynomial matching n-f holders across all components (`:319-335`); the bit check is as in the Engine.
- **Wire** wraps the Engine wire in `DREGG.PRIVATE.FIELD.LAYERS.WIRE\x01`, so the two cannot be confused (`:402-421`).
- **Tests (4),** including the 142,645-byte public plan: 13,237 gates, 9,418 rows, AND depth 29, batch sizes pinned (`:534-578`).

### 1.19 Data model and state machines (summary)

| Protocol | Instance per | Sub-instances | Terminal states | Durable driver |
| --- | --- | --- | --- | --- |
| Gather | ICG | INFORM/ACK/PREPARE | `output: Set` | none (inside VABA) |
| CoverGather | VABA view | n RA + Gather | `output: Set` | none |
| VABA | ACS | per view: n ASKS, 2n RBC, ICG; one final RA | `output: u16` | `acs_store` via ACS |
| ACS | generation | n selector RBC + VABA | `output: Set` | `acs_store` |
| dZK | (dealer, context) | 1 RBC + n PrivSend | Accepted / Rejected per holder | `dzk_store` |
| ACSS-Id | (dealer, generation) | n PrivSend + n dZK + 1 RA + n + n² + n RBC | Local Accepted / Rejected; Accusation per holder; PublicReconstruction | `acss_id_store`, `king_store` |
| Sh2t-Id | (dealer, generation) | n PrivSend + matrix RBC + RA + n + n² + n + n³ RBC/RA | Local Accepted / Rejected; per group Verified / Invalid / AgreedAccusation | `sh2t_id_store`, `king_store` |
| TripleKing | (consumer generation, basis) | 4 king RBC + 2 RA + fault RBC | CheckedTriples / CheckFailure; VerifiedLocalization | `king_store` |
| Engine | plan | per (gate, holder) RBC + n bit RBC | BooleanSharedOutput / BitnessFailure | `field_network_store::Store` |
| LayerEngine | plan | per (batch, holder) RBC + n bit RBC | SharedOutput / BitnessFailure | `field_network_store::LayerStore` |

`Sh2tId` recon-request RBCs number n² groups x n requesters (`sh2t_id.rs:386-388`), so the per-instance Bracha count is about n³ (4,096 at n = 16). All are allocated eagerly in `new`.

### 1.20 Wire formats and domain strings emitted by this shard

All codecs share four rules: canonical by re-encode; fixed-width u16 LE party fields; base-255 `Nat` for counts and indices; `bytes` = Nat length + bytes.

| Domain string | Where | Use |
| --- | --- | --- |
| `DREGG.INDEX.ACS.V1`, `DREGG.ACS.PARTY.V1` | `acs.rs:59`, `acs_store.rs:61` | ACS context, WAL identity |
| `DREGG.INDEX.VABA.V1`, `DREGG.VABA.VIEW.V1`, `DREGG.VABA.RANK.V1` | `vaba.rs:187,211,602` | VABA context, view, rank |
| `DREGG.PRIVATE.COMMITTED.VECTOR\x01` | `reconstruction.rs:86` | dead commitment |
| `DREGG.DZK.GF128.U2.V1`, `.PRIVATE.INSTANCE.V1`, `.RANDOM.V1`, `.CHALLENGE.V1`, `.LEAF.V1`, `.NODE.V1`, `.PUBLIC\x01`, `.PRIVATE\x01`, `.REJECTION.V1` | `dzk.rs:47,84,122,130,139,149,243,274,808` | dZK |
| `DREGG.DZK.WIRE\x01`, `DREGG.DZK.PARTY.WAL.V1` | `dzk_store.rs:68,218` | wire, WAL |
| `DREGG.ACSS.ID.V1`, `.CHILD.V1`, `.RANDOM.V1` | `acss_id.rs:212,22,31` | ACSS-Id |
| `DREGG.ACSS.ID.WIRE\x01`, `DREGG.ACSS.ID.PARTY.WAL.V1` | `acss_id_store.rs:52,253` | wire, WAL |
| `DREGG.SH2T.ID.GF128.V1`, `.RANDOM.V1`, `.CHILD.V1`, `.POINT.V1`, `.BLOCK.V1`, `.INVALID.V1` | `sh2t_id.rs:360,24,32,46,57,885` | Sh2t-Id |
| `DREGG.SH2T.ID.WIRE\x01`, `DREGG.SH2T.ID.PARTY.WAL.V1` | `sh2t_id_store.rs:67,289` | wire, WAL |
| `DREGG.TRIPLE.KING.PREPARED.V2`, `DREGG.PREPARATION.ACSS.SEEDS.V1`, `DREGG.PREPARATION.SH2T.GROUP.V1`, `DREGG.PREPARATION.BURN.V1`, `DREGG.TRIPLE.KING.DN.V1` | `triple_king.rs:203,218,224,409,585` | King binding, row ids, receipt, context |
| `DREGG.TRIPLE.KING.WIRE\x01`, `DREGG.TRIPLE.KING.PARTY.WAL.V1`, `...IDENTITY\x01` | `king_store.rs:44,198,216` | wire, WAL |
| `DREGG.CHECKED.TRIPLE.INVENTORY\x01`, `DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01`/`\x02`, `DREGG.PRIVATE.FIELD.NETWORK\x01`, `DREGG.PRIVATE.FIELD.INITIAL\x01`, `DREGG.PRIVATE.FIELD.WIRE\x01` | `field_network.rs:79,112,163,473,697,828` | inventory, plan binding, context, initial, wire |
| `DREGG.PRIVATE.FIELD.PARTY.WAL\x01`, `.INIT.FILE\x01`, `DREGG.PRIVATE.FIELD.LAYERS.PARTY.WAL\x01`, `.LAYERS.INIT.FILE\x01` | `field_network_store.rs:67,70,102,105` | WAL and initial files |
| `DREGG.PRIVATE.FIELD.LAYERS.SCHEDULE\x01`, `DREGG.PRIVATE.FIELD.LAYERS\x01`, `DREGG.PRIVATE.FIELD.LAYERS.WIRE\x01` | `field_network_layers.rs:77,143,405` | schedule, context, wire |

None of these strings appears in any `.lean` file (grep), so no Lean decoder exists for any of them.

### 1.21 Processes, sockets, files, directories, environment

- **Processes:** none in production code. In tests: `king_store::tests::kill9_mid_king...` re-executes the test binary (`std::env::current_exe()`) with `--ignored --exact` and SIGKILLs it (`king_store.rs:1098-1131`); the parent waits up to 600 s for a marker file (`:1118-1121`).
- **Sockets:** the anchor Unix socket through `custody::rpc` (request 0 = read the whole journal, 2 = batch reserve) from `burn_preparation`, `verify_burn_standing`, `Engine::reserve_inner` and `Engine::restore_initial` (`triple_king.rs:160,375,379,402`; `field_network.rs:434,761`). Tests serve it with a thread (`AnchorFixture`, `triple_king.rs:1231-1294`).
- **Files** per store path P:
  - `P` (WAL) and `P.lock` (`transition_journal.rs:44-53`);
  - for field stores, `P.initial` and `P.initial.lock` (`field_network_store.rs:200-202,213,250`);
  - for burns, the local receipt file `local` and `local.preparation.lock` (`triple_king.rs:374,398`).
  - All are created mode 0600 (via shard A helpers).
- **Randomness:** `/dev/urandom` read directly in `acs_store.rs:97`, `acss_id_store.rs:274`, `dzk_store.rs:245` and `sh2t_id_store.rs:318`; `king_store` takes an `Entropy` from the caller (`king_store.rs:494`).
- **Environment** (tests only): `BYZ_SEEDS`, `BYZ_FROM` (`byz.rs:1919-1926`), `MINI_KING_STORE_DIR` (`king_store.rs:659,1075`), and `MINI_PRIVATE_TEST_ENTROPY` through `entropy::test_root` (`entropy.rs:55-58`, `#[cfg(test)]`).
- **Test directories:** 20 `std::env::temp_dir()` uses across the shard (grep), named `mini-acs-store-*`, `mini-dzk-*`, `mini-acss-store-*`, `mini-sh2t-*`, `mini-king-*`, `mini-king-store-*`, `mini-field-store-*`, `mini-layer-*`. **None is removed** (the only removal is the test anchor socket, `triple_king.rs:1241`), so every run leaves WALs and anchor logs under the system temp directory.

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations used

**None.** No file in this shard frames a Host request, opens a Host socket or links `native/host-operations.rs`. That agrees with shard A's section 2.1 for the crate. There is no Lean receiver to cross-check against: no domain string in section 1.20 occurs in any `.lean` file (grep). The `Protocol` tags that tie committee packets to protocols (`authenticated_ingress.rs:20-27`: Acs 0, PrivateSend 1, AcssId 2, Dzk 3, FieldNetwork 4, PrivateOutput 5) correspond on the Lean side only to `Compiler/JointBackendPartyCodec.lean`. There `Party.bounded` admits protocol < 4 only (shard A F15), and that module is research-only (`ResearchWip.lean`).

### 2.2 The Lean question, narrowed: is there a Lean specification of these protocols?

**No. The Rust is the only specification. The external specifications are the papers.**

- Grep of `Kernel/`, `Compiler/`, `Theory/`, `Assurance/`, `Selvage/`, `Host/`, `Verify/`, `Pred/` and `Effects/` (`*.lean`) finds **zero** files mentioning any of: `Beaver`, `secretShar`/`SecretShar`, `Bracha`, `VABA`/`Vaba`, `ACSS`/`Acss`, `Sh2t`/`DoubleShar`.
- `King` appears in two files about fn replies (`Kernel/FnReplyConsumption.lean`, `Host/FnSelectiveReleaseFnAck.lean`), unrelated. `dZK` matches two Selvage files about oracle logs, unrelated.
- Candidate files read:
  - `Assurance/MpcSealedCellExecution.lean` (801): "a three-party, threshold-two declaration with an executable Lean portal". "The agreement proved here is deliberately only agreement of the submitted, portal-checked party views. It is not malicious-MPC security. Transcript hiding ... are separate laws" (`:1-25`). n = 3, t = 2 is not this backend's n = 3f+1 committee, and no Rust in `native/` names `sharedMpc` or `MpcSealedCell` (grep).
  - `Kernel/PrivateSuccessorCustody.lean` (203): "an executable journal model, not MPC, disk durability or a sharing proof" (`:1-5`). It models one-use reservation and `Purpose` (`triple | agreementCoin | holderOutputPad | audienceReleasePad`, `:44`). This is the Lean counterpart of the burn bookkeeping only (section 3).
  - `Compiler/ObliviousEvaluator.lean` (267) and `Compiler/PrivateWorldIR.lean` (65): lowering of the registered evaluator to a data-independent schedule. "This is NOT a claim that Lean's branching/Nock oracle is a constant-time MPC circuit" (`ObliviousEvaluator.lean:1-6`); "Secret-PC evaluation and malicious MPC remain separate backend refinements" (`PrivateWorldIR.lean:1-5`). They produce no Plan bytes this crate reads.
  - `Assurance/PrivateEvaluatorCustodyJoin.lean` (84): a native-binding join for holder-private material, "adds no authority and no audience release". No protocol statement.
  - `Kernel/PrivateTurn.lean` (287): `privateTurn_public_indistinguishable`, a kernel model that public views ignore witnesses. It is a model fact at the turn level, not a statement about this protocol's transcripts.
- `Compiler/PrivateCircuitAllocation.lean` defines the `Plan` structure (`:15-24`) whose bytes `circuit_batch::Plan` mirrors (shard A section 2.2). It treats `bindingBytes` as opaque and says it is "NOT authority to release material, a malicious-MPC qualification, or an implementation of durable batch anchoring" (`:1-5`).

So the curious-holder transcript check (`private_view.rs`), the King checks and the Byzantine harness are the only correctness and secrecy evidence. MPC-PROFILE-P2.md says "There is no simulator proof" (`:8-10`).

### 2.3 OS facilities

- **Unix only:** `UnixStream` through `custody::rpc`, `flock` through `custody::lock` and `transition_journal`, `OpenOptionsExt::mode` (`field_network_store.rs:16,225-229`), `std::os::unix::process::ExitStatusExt` and SIGKILL in tests (`king_store.rs:652,1124-1130`). Nothing is Linux-specific in this shard.
- Assumes honest crash-prefix storage and meaningful `fsync` (inherited from `transition_journal.rs:1-11`).
- No bwrap, seccomp, cgroups, systemd, `SO_PEERCRED`, SQLite or Cap'n Proto.

### 2.4 Network services

None. Every protocol assumes "authenticated confidential reliable party channels" (`CONSTRUCTION.txt:35-36`; `vaba.rs:2`; `acss_id.rs:2`; `field_network.rs:536-538`: "Sender MUST be independently end-to-end authenticated"). **No channel exists**: no TCP or Unix transport, no retry loop, no delivery cursor. Every test moves frames between in-process state machines through `VecDeque`s (for example `acss_id.rs:830-842`, `byz.rs:1165-1242`, `king_store.rs:742-775`).

### 2.5 File layouts and config

- Each store needs a caller-chosen path plus an anchor socket path. Nothing in the repository creates these for a deployment.
- `KingStore::open` takes a `Shape` (holders, king, count, group, consumer generation and three sources with generations, `king_store.rs:178-195`). No tool produces a Shape outside tests.
- Fixtures (`include_bytes!`):
  - `fixtures/public-minimal-plan.bin` (142,645 B; `field_network_layers.rs:536`);
  - `addition-network-8-plan.bin` (379 B; `private_view.rs:191,340`, `private_output_store.rs:361,649`);
  - `addition-network-2-plan.bin` (139 B; `private_output_store.rs:715`);
  - `objective-identity-{source,network,input,expected}.bin` plus a profile JSON (`private_output_store.rs:471-476`; the heavy test filtered out by default in `.config/nextest.toml`).
- **Fixture provenance:** the Lean producer of the width-8 adder cited at `CONSTRUCTION.txt:367-372` ("generic all-width Lean emitPairs integer/origin proof and width8 Plan producer") was `emitPairs` in `Compiler.ObliviousNatRipple [deleted 212c79af]` and `Host.ObliviousNatAddEmit [deleted 212c79af]`. Both were deleted on 2026-10-04 in `212c79af` ("bendtt-delete(1)!") (`git show 212c79af`). No `.lean`, `.sh` or `.py` file in the tree references any fixture file name (grep). The fixtures are now frozen artifacts.

### 2.6 Other crates

No path dependencies, and no other crate depends on this one. Within the crate, this shard depends on shard A's `asks`, `private_send`, `private_send_store` (PrivSend wire), `codec`, `consensus_wire::Cursor`, `custody` (`hash`, `rpc`, `lock`, `snapshot`), `transition_journal`, `circuit_batch::{Plan, Network, Op}`, `entropy`, `authenticated_ingress` (the `IngressMachine` trait) and, in tests, `transcript`.

---

## 3. Does it decide anything semantic?

Protocol thresholds (Bracha n-f/f+1, ICG quorums, ACSS/Sh2t opening quorums, robust decoding with n-f matching points) are cryptographic-protocol mechanics with paper references. They are legitimately Rust under the "hosted-service adapters" carve and have no Lean owner. They are not listed as violations. The table lists only the places where this shard decides something that touches Mini custody, authority, value or declassification, where ATLAS section 7 says the decision point should be a Lean export or a Lean-emitted artifact.

### 3.1 Decisions a Lean admission should own (violations or unowned decisions)

| # | path:line | What Rust decides | Lean counterpart | Blast radius if wrong |
| --- | --- | --- | --- | --- |
| B-S1 | `triple_king.rs:367-407` (`burn_preparation`), reused by `field_network.rs:433` | **Whether preprocessing and plan material is spent.** A local Rust pre-check (`before.reserve_batch`, `:376`) plus the Rust anchor's batch reserve; the receipt is verified in Rust (`open_burn_receipt`, `:418-444`; `verify_burn_standing`, `:153-165`). Extends shard A D1 to the two MPC material paths | `Kernel.PrivateSuccessorCustody.reserve` with `Purpose.triple` (`Kernel/PrivateSuccessorCustody.lean:44,77-82`); not called | Re-issuing a checked triple to two Beaver openings reveals the difference of the two masked operands to every holder: a privacy break of the wires the triple masked |
| B-S2 | `triple_king.rs:216-238`; `field_network.rs:78-99` | **What counts as "the same material".** Row identities are SHA-256 over (domain, source generation, context), with row 0 for an ACSS seed set and row = group for Sh2t. The inventory pool id is SHA-256 over the whole manifest. Excluding the consumer attempt from ids is a policy choice ("IDs omit consumer attempt and purpose relabeling", `CONSTRUCTION.txt:88-90`) | None. Lean `CorrelationId` is abstract; no Lean def derives these ids. The domain strings occur in no `.lean` file | A derivation that maps one stock to two pool ids would let the anchor accept the same triple twice (B-S1's privacy break). Today `catalog` (`field_network.rs:123-149`) and the receipt binding prevent this only within one plan or one receipt |
| B-S3 | `field_network.rs:104-120,154-182`; checked at `:396` | **The Plan binding format** (`DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01/\x02`): which inventories, which preparation rows and which inputs a plan consumes. `source_binding` is caller bytes ("does not turn caller source_binding bytes into source authority", `:101-103`) | Lean `Plan.bindingBytes` is opaque (`Compiler/PrivateCircuitAllocation.lean:20-23`); no Lean producer or approver of this format exists | A wrong binding consumes the wrong stock or binds inputs from another generation; the burn then makes the mistake permanent |
| B-S4 | `acss_id.rs:524-533,589-595,662-704`; `sh2t_id.rs:719-725,788-803,937-1000`; `dzk.rs:697-705,852-896` | **Declassification gates:** f+1 environment requests open a complained holder's row to everyone (ACSS, Sh2t), publicly reconstruct ACSS secrets, or privately reconstruct a Sh2t group to its receiver. The doc comments call these "Exact current-source environment request" (`acss_id.rs:660`) and "Only source-authorized callers may publicly release this private view" (`dzk.rs:852-853`), but the methods are plain `pub fn`s; nothing checks a source admission | None. CONSTRUCTION names "ReleaseAdmission" (`CONSTRUCTION.txt:292-295`); no such Lean declaration exists (shard A D5) | Any process holding f+1 committee members' store handles can publicly reconstruct dealt inputs. Test-only today |
| B-S5 | `triple_king.rs:1008-1133` | **Blame:** `Dispute{party, king}` / `Accusation{dealer, holder}` names a faulty member | None | Nothing consumes the decision today (no elimination). If a future roster update used it, a Rust bug would expel an honest member |
| B-S6 | `field_network.rs:637-678`; `field_network_layers.rs:349-397` | **Privacy policy on invalid input:** a non-Boolean input publicly opens x·(x+1) to every holder ("privacy of an arbitrary invalid honest field input is NOT claimed", `CONSTRUCTION.txt:210-211`) | None | Leaks a function of an honest party's mistaken input. Documented |
| B-S7 | `triple_king.rs:28` (<= 32 triples per King), `field_network.rs:126,133` (<= 2,048 inventories), `:189-200` (<= 65,536 gates), `field_network_layers.rs:22` (1,024 per batch), `sh2t_id.rs:351-359` (<= 64 KiB payload), `acss_id.rs:207` (<= 128 groups), `dzk.rs:42` (count <= 128) | **Public capacity limits**, decided only in Rust | Lean `Plan.valid` has no numeric bounds (shard A D9) | Shape limits only; no value |

### 3.2 Places that correctly defer or stay physical

- Every output is "recipient-local shares only. This is NOT authority to reveal them" (`field_network.rs:341-345`; `field_network_layers.rs:102-104`). No function mints a `Qualified`, a `YES` or a release token. The README and docs repeat this (`MPC-PROFILE-P2.md:110-113`; `CONSTRUCTION.txt:3-5`).
- Accusation guilt comes "from the actual verified Sh2t opening, never from the king's accusation-label alone" (`triple_king.rs:540-544`).
- Decoded claims never become verified objects. `VerifiedShares`, `AcceptedSharing` and `CheckedTriples` have private fields and are built only inside verification paths (`dzk.rs:475-498`, `acss_id.rs:38-58`, `triple_king.rs:474-513`).
- `TripleKing::new` refuses a basis burned for another consumer generation (`triple_king.rs:582-584`). `PreparedBasis::from_burned` refuses a receipt for another generation or with a flipped byte (`king_store.rs:1024-1067`).
- **Balances, prices, tariffs, quotas of value:** none in this shard.

---

## 4. Flaws noticed

Severity is relative to the crate's stated purpose (research, unreachable from production). Every peer-supplied byte in this shard is **committee-internal**: it comes from another committee member through a channel the crate does not implement. "Byzantine" below means one of the f static corruptions.

**F-B1. A test is red by reading, and no gate runs it.**
- Where: `dzk_store.rs:335-346`. After `drop(store)` it appends one byte to the WAL (`:340-345`) and asserts `Store::open(...).is_err()` (`:346`).
- Why it is red: since `fa84160e`, `transition_journal.rs:87-90` truncates any tail shorter than 8 bytes and opens successfully. The shared WAL's own test `every_append_crash_cut_recovers_prior_prefix_and_replays_complete_record` cuts at every byte and expects success. `sh2t_id_store.rs:428-430` was updated for the same change ("recovery truncates it (transition_journal, fa84160e)"); `dzk_store.rs` was not.
- Gate: no row of `scripts/check-rust-tests.sh` names `dzk_store::tests` (rows `private-backend-recovery`, `private-transition-wal`, `private-king-store`, `private-backend-hybrid` are the only private-backend rows, `:147-153,432-437,474-487`).
- Inferred (not run): the test fails, and the failure is invisible to the gate.

**F-B2. A test asserts dealer re-dealing after a published record is truncated.**
- Where: `sh2t_id_store.rs:403-436`.
- `out = s.dealer(&polys())` returns the dealer's outbox (`:408`). By the store contract it is now publishable.
- The test cuts the last byte of the WAL (`:421-427`). It asserts the store reopens with no dealer inputs and **deals again** (`:431-435`). The new deal draws a fresh `/dev/urandom` seed (`:317-318`), so the masks and PrivSend keys differ.
- The comment's premise, "it was never fsynced and never published" (`:428-430`), is true only under honest crash-prefix storage, where a completed `sync_all` cannot lose bytes. Under bit rot or a lying disk it is exactly shard A's F2: the same Sh2t context gets two different sharings to parties that may have received the first. This breaks the commitment matrix's binding, and every King basis that used the instance becomes incoherent.
- The test makes the equivocation path a regression-protected behaviour.

**F-B3. "WouldBlock after burn" is a permanent loss with a retryable error kind.**
- Where: `field_network.rs:449-462`. The whole plan is burned at `:433`; if any input's ACSS sharing is not yet complete, the function returns `Error::new(ErrorKind::WouldBlock, "input sharing incomplete; full plan remains spent")`.
- Scenario: input dealer 2 is slow (asynchrony, not a fault). Holder 1 calls `Engine::reserve`, burns 9,418 rows, gets WouldBlock and retries later. `burn_preparation` now fails at `before.reserve_batch` (`triple_king.rs:376`) because every row is spent.
- Unlike the King, the Engine has no `from_burned` rebuild (no `PreparedBasis::from_burned` analogue), although `burn_preparation` wrote the receipt file. The stock is lost, and the WouldBlock kind invites exactly the retry that cannot work.
- The same kind is returned by `PreparedBasis::extract` (`triple_king.rs:283,293`) and asserted by tests (`triple_king.rs:1727`, `field_network.rs:1199`). There `KingStore::burn` does recover through the local receipt (`king_store.rs:575-577`), but a direct `reserve_new` caller has no such path.

**F-B4. No liveness against one malicious party in preprocessing.**
- The king reconstructs z from the **first** 2f+1 points by holder id, with no error correction (`triple_king.rs:765-779`).
- One Byzantine non-king holder whose id is among the lowest 2f+1 sends a wrong z. The check fails (`PolynomialIdentityFailed`, `:940`, test `:1591-1646`) after the preparation rows were burned (`:121-133`).
- Localization ends in `Dispute{party, king}` (`:1084-1088`), which nothing consumes. No roster change, no exclusion and no retry with fresh material exist; "dispute elimination/ACS, simulator and GOD MPC remain open" (`:4-6`).
- So a single malicious member can make every King run fail, permanently burning 6 rows per holder per run. A malicious king can likewise broadcast a wrong z (test `:1559-1590`).
- This is consistent with the docs ("no guaranteed output delivery", `MPC-PROFILE-P2.md:50-51`). The point for the deletion plan is that "TripleKing with localization" buys detection, not progress.

**F-B5. Nothing agrees on input sets or King sources; ACS is never used.**
- `PreparedBasis::manifest` requires exactly 2f+1 named sources (`triple_king.rs:186-192`), chosen by the caller (tests use dealers 0, 1, 2, `king_store.rs:672-678`).
- `Engine::reserve*` requires every listed input's sharing to complete (F-B3).
- In the protocol literature ACS selects which sharings to use. Here ACS (`acs.rs`) has no consumer.
- A withholding source dealer stalls `KingStore::burn` (WouldBlock forever, though recoverable via the receipt). A withholding input dealer burns the plan.

**F-B6. Unbounded retention obligation for future-view VABA frames (committee-internal).**
- `Vaba::receive` returns WouldBlock for any frame whose `view` is not yet entered and documents that the transport "MUST retain/retry" (`vaba.rs:330-337`). `view` is a u64 chosen by the sender (`vaba.rs:121-125`).
- One Byzantine member can send frames for views 1..2^64 that honest parties must keep forever. `acs_store` journals nothing on error (`transition_journal.rs:148`), so the burden falls on a transport that does not exist.
- The harness keeps blocked frames in an unbounded `Vec` and only reports `blocked_max` (`byz.rs:785-793`). A fix would bound acceptance to current+1 (views are entered one at a time, `vaba.rs:524-545`).

**F-B7. Per-frame CPU blow-up in robust decoding (committee-internal).**
- `correct_polynomials` (`acss_id.rs:768-812`) enumerates every (f+1)-subset of the received points, interpolates a candidate for all `count` components (`polynomial`, `:737-767`), and evaluates it at every point. It runs on **every** received frame once at least n-f points are present:
  - `field_network.rs:620-624`, `field_network_layers.rs:331-335`, `triple_king.rs:811,845,888,1059`, `private_output.rs:338` (which the worker binary reaches).
- At n = 16, f = 5 that is C(16,6) = 8,008 candidates. A layer batch has up to 2 x 1,024 components. Each candidate costs about 6² multiplications per component to build plus 16 x 6 to check, so roughly 8,008 x 2,048 x 132, about 2.2 x 10^9 `Field::mul`, each a 128-iteration loop (`reconstruction.rs:18-32`).
- A Byzantine member that sends inconsistent points makes every later arrival re-run the full search until enough honest points arrive. This is bounded but slow; at n = 4 it is negligible (C(4,2) = 6).

**F-B8. Whole-state clone per WAL append, and outbox retention.**
- `Journal::append` clones the machine before applying (`transition_journal.rs:147`) and keeps every outbox in memory for the life of the store (`:164`).
- For `KingMachine` (3 `AcssId` + 3 `Sh2tId`, each with on the order of n² to n³ Bracha instances, plus a `TripleKing` and the `seen` set) every received frame clones all of it. Cost is O(frames x state) time plus a transient doubling of memory.
- MPC-PROFILE measured a 902 MB peak RSS for the King-store tests at n = 4, count 1 (`MPC-PROFILE-P2.md:87`). That is consistent, though the doc does not attribute the cause.

**F-B9. Secrets at rest in plaintext.** Under mode 0600 and nothing else (inherits shard A F8):
- ACSS dealer events hold the dealing seed and every input polynomial, so the dealer's private input values sit in the clear as constant terms (`acss_id_store.rs:183-193`, journaled by `Store::dealer` `:268-277` and by `KingStore::acss_dealer` `king_store.rs:519-529`);
- Sh2t dealer events (`sh2t_id_store.rs:211-221`), dZK dealer events (`dzk_store.rs:244-252`), ACS coefficient events (`acs_store.rs:93-99`);
- the field-network `.initial` file with this holder's input shares and every triple (`field_network.rs:686-714`, written by `field_network_store.rs:212-240`);
- the replayable receive events, from which every derived share is recomputed on open.
- `MPC-PROFILE-P2.md:46-49` states the same.

**F-B10. No zeroization; `Debug` on secret-bearing types.**
- grep for `zeroize`/`Zeroiz` over the shard finds nothing.
- `#[derive(..., Debug, ...)]` on: `sh2t_id::AcceptedSharing` (values and masks, `sh2t_id.rs:66`), `PrivateReconstructed` (the reconstructed polynomials, `:168`), `InvalidReconstruction` (`:204`), `Payload` (`:296`); `dzk::PrivateProof` (mask evaluation, `dzk.rs:235`), `VerifiedShares` (share values, `:474`), `OpenProof` (`:525`).
- By contrast `acss_id::AcceptedSharing` and `triple_king::RandomShares`/`CheckedTriples` derive only `Clone` (`acss_id.rs:38`, `triple_king.rs:85,474`): the discipline is inconsistent.
- Any `{:?}` of these, in a panic message or a future log line, prints shares. Plain `Vec<Field>` copies are duplicated by every WAL append (F-B8) and never wiped.

**F-B11. Variable-time field arithmetic.** `Field::mul` branches on each bit of one operand and on the top bit of the other (`reconstruction.rs:20-28`). `inv` uses it (`:33-48`). Admitted (`reconstruction.rs:10-11`, `CONSTRUCTION.txt:34`, `MPC-PROFILE-P2.md:45`). Every share computation in the shard is timing-observable to a co-located process.

**F-B12. Twin anchor service loop in tests.**
- `triple_king::tests::AnchorFixture` (`triple_king.rs:1231-1294`) re-implements the anchor server loop: nonblocking accept, `unwrap` on read and write at `:1253-1254,1267`, the same reply framing.
- Production `custody::run_anchor` (`custody.rs:191-216`) is blocking with 10 s timeouts and ignores write errors.
- Every King, evaluator and output test exercises the twin, never `run_anchor`. Shard A's F1, F7 and F13 anchor behaviours (torn-tail brick, no peer auth, quadratic log) are therefore never exercised by the MPC path's tests.

**F-B13. The executed path never shares one anchor between preparation and plan.**
- King burns go to per-holder anchors created in `checked_from_material` (`triple_king.rs:1765-1767`).
- Plan burns go to a **different** fresh per-holder anchor (`arithmetic_reference.rs:244-246`, `evaluator_anchor`).
- No test shows one anchor holding both kinds of rows, nor the journal growth such a combined anchor would see (shard A D3: the 16 MiB lifetime cliff).

**F-B14. `AgreedAccusation` makes a group's outcome schedule-dependent.**
- In `sh2t_id.rs:847-922`, once any holder-accusation agreement RA has output 1, every authorized group with fewer than 2f+1 points is terminally marked `AgreedAccusation` (`:911-921`). Later honest points are ignored (`:847`).
- The agreement needs only that a complaint was delivered and f+1 parties requested it (`require_complaint`, `:951-962`). The verified fault may be `Accuser` (a false complaint, test `:1345-1362`), yet the group outcome still aborts reconstruction.
- In the King this becomes `LocalizationDecision::Accusation{dealer, holder}` (`triple_king.rs:1047-1053`). The label names the dealer even when the opening later shows the accuser lied; consumers must read `verified_accusation()` (`:540-544`).

**F-B15. Degenerate f = 0 accepted by some constructors.** `Gather::new` (`gather.rs:57`), `Vaba::new` (`vaba.rs:184`), `RecoveryBinding::validate` (`reconstruction.rs:70`) and `Engine::reserve_inner` (`field_network.rs:409`) accept n = 1, f = 0. ACSS, dZK and Sh2t require n >= 4 (`acss_id.rs:202`, `dzk.rs:40`, `sh2t_id.rs:343`), and `per_group` refuses f = 0 (`triple_king.rs:28`). Harmless (the composition fails at ACSS) but inconsistent.

**F-B16. Sequential Engine opening map grows on peer input (committee-internal).** `Engine::receive` creates a Bracha for any (AND-gate index, holder) on the first frame (`field_network.rs:556-560`). One Byzantine member can allocate up to (AND gates) x n instances (65,536 x 16 at the bounds) before the honest evaluation reaches them. `LayerEngine` is bounded by the batch count (`field_network_layers.rs:236-248`).

**F-B17. One fsync per received frame.** Every store journals every receive event with `sync_all` (`transition_journal.rs:153-158`). The width-8 run delivers 8,067 frames to one holder (`MPC-PROFILE-P2.md:59`). Done durably, that is thousands of fsyncs per holder per computation, and the King store adds dedupe hashing per frame. This is not measured anywhere: the measured runs are in-memory except the King store.

**F-B18. `field_network_store::create` ordering.**
- `.initial` is written with `create_new` before the WAL exists (`field_network_store.rs:224-242`).
- A crash after the `.initial` write and before `Journal::open` leaves `create` failing with EEXIST forever. `reopen` recovers, which is fine.
- A crash before `sync_all` (`:231`) can leave a torn `.initial`. Then `reopen` fails "field initial checksum" (`:261-263`) forever, while the plan rows are already burned (`Engine::reserve_inner` ran before `create`). The material is lost and the store bricked. This mirrors shard A F3 (`private_initial.rs`) in a second file.

**F-B19. Doc references to code that does not exist.**
- `vaba.rs:17` "Use vaba_store": no such module.
- `CONSTRUCTION.txt:367-372` and `:329-336` cite a Lean `emitPairs` producer deleted in `212c79af` (section 2.5).
- `private_view.rs:27` says "at least two distinct input pairs" while its test name and MPC-PROFILE say three (A plus two B worlds, `private_view.rs:344-378`).

**F-B20. Panics on peer bytes: none found in non-test code.** Checked:
- every `try_into().unwrap()` follows a fixed-length `take` or `chunks_exact` (`acs.rs:37`, `vaba.rs:54,65,74-75,101`, `dzk.rs:113`, `acss_id_store.rs:137`, `sh2t_id_store.rs:63`, `king_store.rs:122`, `triple_king.rs:1158-1159,1177`);
- indexing after a range check: `sh2t_id.rs:709-718` before `recon_requests[group]`, `acss_id.rs:389-394`, `field_network.rs:550-553`, `field_network_layers.rs:236-243`;
- `vaba.rs:60-67` checks `end >= b.len()` before `b[end]`;
- logically guarded unwraps: `vaba.rs:312` (view 0 always exists), `:386` (views are contiguous from 0), `:461` (ICG output non-empty), `:605` (keys checked by `all_open`); `dzk.rs:741,764` (`delivered()` implies a public output); `sh2t_id.rs:771-772,818-819` (sharing complete implies matrix and payload); `triple_king.rs:878-879` (`h` implies `fg`);
- interpolation denominators are x_i + x_j over distinct holder ids or distinct small indices, never zero.
- `field_network_layers.rs:346-348` and `:301-308` return `Err` (not panic) on an unresolved wire.

**F-B21. Randomness sources are scattered (a twin, not a defect).** There are four direct `/dev/urandom` reads (section 1.21) beside `entropy::Entropy`. Seeded derivation uses three copies of SHA-256(domain ‖ seed ‖ context ‖ tag ‖ u64 index): `acss_id.rs:30-37`, `dzk.rs:121-128`, `sh2t_id.rs:23-30`. All are classical-ROM PRGs, the profile's stated assumption (`entropy.rs:1-12`). Shard A recommended routing through `Entropy`; `king_store` already does (`king_store.rs:494-517`).

**F-B22. Lost reply on burn: burn, not retry (inherits shard A F14).** If the anchor commits the batch but the reply is lost, `burn_preparation` errors (`triple_king.rs:379`) without writing the local receipt (`:396-398`). The next `reserve_new` is refused (rows spent), and with no receipt `KingStore::burn` cannot use `from_burned` (`king_store.rs:575-589`). The preparation is lost. No "return my existing allocation" request exists at the anchor, although `open_burn_receipt` (`triple_king.rs:418-444`) has the shape to verify one.

---

## 5. Unwired / undone

### 5.1 Reachability

| Module | Reached by a `fn main` arm | Reached by journey, unit, deploy or root script | Reached by gate rows | Verdict |
| --- | --- | --- | --- | --- |
| `gather`, `vaba`, `acs`, `acs_store` | no (`main.rs` arms: shard A 5.1) | no (`crash-probes.py` and `check-boundary.sh` name none, grep) | `vaba::tests::real_view_change_...` (`check-rust-tests.sh:150`) | test-only; not on the executed MPC path |
| `vaba/byz.rs`, `vaba/byz_targeted.rs` | `#[cfg(test)]` | no | none | test instruments; not gated |
| `reconstruction` | `Field` only, through `private_send`/`private_output` in the worker | no | n/a | `Field` live; everything else dead (5.2) |
| `dzk` | no (types only, through `acss_id`) | no | none directly | test-only; inside ACSS-Id on the executed path |
| `dzk_store` | no | no | none | codec used by `acss_id_store`; `Store` test-only; one test red (F-B1) |
| `acss_id` | `correct_polynomials` via `private_output.rs:338` in the worker | no | via `private_king_store` and `private_view` rows | protocol test-only; one helper binary-live |
| `acss_id_store` | no | no | via `king_store` rows | codec and machine used by `king_store`; `Store` test-only |
| `sh2t_id`, `sh2t_id_store` | no | no | via `king_store` rows | test-only |
| `triple_king` | no | no | via `king_store` and `private_view` rows | test-only |
| `king_store` | no | no | 5 tests in `private-king-store` (`check-rust-tests.sh:480-485`) | test-only, gated |
| `field_network` | `fields` helper via `private_output.rs:11` | no | via `private_view` row | test-only (protocol); helper binary-live |
| `field_network_layers` | type only (`private_output.rs:12,84`); `PrivateOutput::reserve` is test-only (shard A 5.1) | no | via `private_view` row | test-only |
| `field_network_store` | no | no | none | test-only; not on the executed path |

**The executed MPC path** (what the README row "a width-8 adder ... and a curious-holder transcript check over 8,067 frames, in `native/private-backend` tests (`cf6a4c1d`)" consists of):
- `private_view.rs:184-260` `run_world`, which calls:
  - `triple_king::tests::prepared_from` (3 dealers x (ACSS-Id + Sh2t-Id), `triple_king.rs:1364-1440`);
  - `triple_king::tests::checked_from_material` (King among 4 holders with per-holder test anchors, `:1757-1800`);
  - `arithmetic_reference::tests::completed_private_inputs_with_states` (input ACSS-Id by dealers 0 and 2; `Engine::reserve`/`reserve_many` on fresh anchors; `LayerEngine`; `arithmetic_reference.rs:183-260`);
  - `private_output_store::tests::stores_from_completed_descriptor` plus `drive_tapped` (PrivSend output to holder 1);
- on the width-8 fixture with the counted Boolean prefix (`private_view.rs:191-193`).
- Every delivery passes `transcript::Tap` for holder 3 (`private_view.rs:195`).
- The simulator moves honest dealings by delta·L(X) (`equivocate_preparation`, `:114-177`; `InputParty::equivocate`) and re-runs the worlds; transcripts must match except PrivSend ciphertexts of other holders' rows and dZK column frames (`rom_hidden`, `:285-297`; `compare`, `:299-321`).
- The falsifier (`:384-405`) shows the retired public-coefficient dealing decoded by holder 3.
- **Not on the path:** ACS, VABA, Gather, `reconstruction::recover`, `acs_store`, `dzk_store::Store`, `acss_id_store::Store`, `sh2t_id_store::Store`, `king_store`, `field_network_store`, King fault localization, ACSS open and public reconstruction.

**Nothing in this shard is a deployable service.** There is no service loop, socket listener, configuration loader or CLI arm for any protocol. Every state machine is driven by a test's queue.

### 5.2 Dead or unconsumed code (grep-verified)

- **`reconstruction.rs:50-212`:** `Share`, `RecoveryBinding`, `dealer_shares`, `interpolate`, `recover`, `StockState`, `stock_state`. No caller outside the file's tests.
- **Four `IngressMachine` impls never instantiated:** `authenticated_ingress.rs:410-423` (ACS), `:445-459` (ACSS), `:460-475` (dZK), and `field_network_store.rs:177-192` (field runtimes). The only non-test `Receiver` is `Receiver<OutputMachine>` in `native_worker.rs:487-492`. grep for `AcsMachine`/`AcssMachine`/`DzkMachine`/`RuntimeMachine` outside their modules finds only the impl lines.
- **No ingress protocol tag for Sh2t-Id or King frames:** `Protocol` (`authenticated_ingress.rs:20-27`). `KingStore::king_receive`/`acss_receive`/`sh2t_receive` take a bare `sender: u16` (`king_store.rs:541-607`) with no authenticated path even in design.
- **`field_network_store::FieldMachine` and `decode_outbox`** (`:112,122-124`): no external user.
- **King fault localization** (`triple_king.rs:946-1171`, `VerifiedLocalization` `:527-545`): exercised by two tests (`:1591-1698`) and `KingMachine` event 5; its decision is consumed by nothing.
- **ACSS-Id open, accusation and public reconstruction** (`acss_id.rs:523-649,660-704`; `PublicColumn`; `interpolate_at` `:717-736`), and **dZK `transfer`/`transferred`/`open_proof`** (`dzk.rs:852-896`), used only by the former: exercised by their own tests and by `acss_id_store` events 1 and 3, never by the King, the evaluator or the output path.
- **`acs_store` in full,** and **ACS/VABA/Gather** for the MPC (5.1).
- **Doc-only module:** `vaba_store` (`vaba.rs:17`).
- **No TODO/FIXME/`todo!`/`unimplemented!`/`#[allow(dead_code)]` in the shard** (grep). "Open", "pending" and "WIP" live in prose (`CONSTRUCTION.txt:48,286,309,336,357,375`) and in doc comments ("remain open", `triple_king.rs:6`).

### 5.3 Twins and versioned siblings

| Twin | Site A | Site B | Reachable | Delete |
| --- | --- | --- | --- | --- |
| Opening runtime | `Engine` sequential opening (`field_network.rs:529-682`) | `LayerEngine` vector opening (`field_network_layers.rs:218-401`) | Both test-only; the executed path uses `LayerEngine`, which needs `Engine` only as the burned material container (`pristine_material`, `field_network.rs:496-499`) | A's runtime half (start/receive/progress) and `field_network_store::Store`; keep `Engine::reserve*` as the material builder |
| Plan binding | `binding` v1 (`...BINDING\x01`, `field_network.rs:104-120`) | `binding_many` v2 (`...\x02`, `:154-182`) | Both (single vs multi stock, `arithmetic_reference.rs:229-236`) | A: v2 with one inventory covers it |
| Robust decoding | `acss_id::correct_polynomials` (`acss_id.rs:768-812`, n-f matching support) | `reconstruction::recover` (`reconstruction.rs:154-198`, commitment-checked subsets) | A live (worker); B dead | B |
| Lagrange interpolation | `acss_id::polynomial` (`:737-767`), `acss_id::interpolate_at` (`:717-736`) | `sh2t_id::interpolate` (`sh2t_id.rs:1017-1051`, the same as `polynomial` with a value/mask selector), `reconstruction::interpolate` (`:132-148`) | all | keep one `polynomial` plus one `evaluate_at` |
| Horner `eval` | `acss_id.rs:18-20` | `dzk.rs:92-94`, `sh2t_id.rs:17-19`, `triple_king.rs:21-23`, inline folds `reconstruction.rs:122`, `king_store.rs:862-865`, `field_network.rs:1076-1079` | all | one `Field::eval_poly` |
| Seeded randomness | `acss_id::random` (`:30-37`) | `dzk::entropy` (`dzk.rs:121-128`), `sh2t_id::entropy` (`sh2t_id.rs:23-30`) | all | one helper (or `Entropy::fork`) |
| OS randomness | `entropy::Entropy::os` (shard A) | `/dev/urandom` reads in `acs_store.rs:97`, `acss_id_store.rs:274`, `dzk_store.rs:245`, `sh2t_id_store.rs:318` | all | route through `Entropy` |
| Child generation derivation | `acss_id::child` (`:21-29`) | `sh2t_id::child` (`:31-38`), `dzk::Profile::holder_generation` (`dzk.rs:83-90`), `Vaba::add_view` (`vaba.rs:211-216`), `Acs::new` (`acs.rs:59-65`) | all | one `Generation::derive(domain, ctx, index)` |
| Phase codec | `sh2t_id_store::{put_phase, phase}` (`:32-50`, reused by `king_store`) | `dzk_store.rs:19-37`, `acss_id_store.rs:32-50`, `field_network.rs:808-826`, shard A `consensus_wire` | all | one codec |
| "Nat from cursor by scanning to 255" | `acss_id_store::count` (`:18-31`) | `dzk_store::count` (`:44-57`), `sh2t_id_store::count` (`:18-31`), `field_network_store.rs:127-137`, `field_network.rs:724-737` (`restore_initial::nat`), `:858-868` (`decode_message`) | all | shard A's single `Cursor::nat` recommendation applies; six more copies here |
| Outbox codec | `acss_id_store::{outbox, parse_outbox}` | `dzk_store.rs:123-154`, `sh2t_id_store.rs:178-209`, `king_store.rs:143-174`, `field_network_store.rs:113-157` (bound 65,536 instead of MAX/40), shard A `consensus_wire::encode_outbox` | all | one generic `Outbox<M: WireCodec>` |
| Anchor server loop | `custody::run_anchor` (`custody.rs:191-216`) | `triple_king::tests::AnchorFixture` (`triple_king.rs:1231-1294`) | A in the binary (`anchor` arm), B in every MPC test | B: tests should run A in a thread |
| WAL format | `transition_journal` (all stores here) | shard A's `protocol_store` and the anchor log | this shard uses only A | see shard A |
| Material release | `field_network::Engine::reserve*` + `triple_king::burn_preparation` (here) | shard A's `custody::reserve_release` + `circuit_batch::reserve_plan_release` + `allocation_receipt::reserve_material` | A is the executed path; B is the CLI and crash-probe only | B (shard A agrees) |

### 5.4 Tests that do not test, or test only their own fixture

- **`vaba/byz.rs`: meaningful, with stated limits.**
  - The oracles (section 1.3) are protocol-level properties evaluated across honest parties, not restatements of the implementation's branches. Both poles exist: implemented versus printed predicates, each required to stay safe while the printed one stalls (`byz.rs:2109-2149`, `:2156-2198`); real versus lowered ACK quorum under one constructed adversary (`byz_targeted.rs:237-272`); pinned seeds re-scanned if they go stale (`byz.rs:2209-2228`).
  - Limits:
    1. Corruption is static and Byzantine parties are honest machines with mutated or rerouted outputs plus a bounded fuzzer (600 injections, `:518-519`). A Byzantine party never computes a message from honest parties' secrets beyond what its own copy holds; adversarial ranks are modelled by a knob (`vaba.rs:171-176`).
    2. The ASKS-validity oracle recomputes the honest dealer's key with production `Asks::dealer_key` (`byz.rs:1472-1474`). A bug in `dealer_key` would be mirrored, not caught.
    3. The "mutation controls" claim (`byz.rs:28-32`) has no mutant code or log in the tree; only the ACK-quorum mutant is reproducible (via `ack_slack`).
    4. Faulty-channel runs check safety only (`Config::expects_termination`, `:457-459`).
    5. None of these tests is in a gate row; only one VABA unit test is.
- **King, evaluator and private_view tests: independent oracles.** `verify_exact_product` reconstructs (a, b, c) from two holders and checks c = a·b and that every holder lies on the polynomial (`triple_king.rs:1499-1522`; `king_store.rs:840-869`). Evaluator tests reconstruct the output and compare with x AND y (`field_network.rs:1066-1082,1212-1223`). `private_view` compares two independently run worlds byte for byte and has a red falsifier (`private_view.rs:384-405`).
- **Fixture-only tests:**
  - `field_network_layers::tests::actual_native_full_controller_plan_codec_and_public_layer_schedule_match` (`:534-578`) checks codec round-trip and schedule counts on the 142,645-byte public plan. It never executes it ("This fixture is public synthetic inventory, not a qualified execution", `:576-577`).
  - `king_wire_codec_roundtrips_every_body_and_refuses_noncanonical` (`king_store.rs:879-917`) is a codec round-trip.
  - The codec tests in every store are round-trips plus "trailing byte refused".
- **The `#[ignore]` child** `kill9_child_runs_the_king_until_killed` (`king_store.rs:1069-1096`) is meaningful only under its parent; that is documented.
- **Red by reading:** F-B1.

### 5.5 Versioned siblings

- `DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01` and `\x02` (both used).
- `DREGG.TRIPLE.KING.PREPARED.V2` (no V1 present; fine).
- `DREGG.ASKS.H.V2` mirrored in the harness (`byz.rs:1672-1680`, "Mirror of `Asks::h`", with a drift assertion at `:991-995`).
- The sequential Engine and `LayerEngine` (5.3).
- `PROGRESS\x01`/`\x02` and the other siblings in shard A's files.

---

## 6. Size and shape

### 6.1 Per-file table

See the header table: 14,944 lines, 6,452 test (43%), 8,492 code. Breakdown by role:

| Group | Files | Lines | Test | Code |
| --- | --- | ---: | ---: | ---: |
| Agreement layer (2024/677) | `gather`, `vaba`, `acs`, `acs_store` | 1,763 | 638 | 1,125 |
| Byzantine harness | `vaba/byz`, `vaba/byz_targeted` | 2,541 | 2,541 | 0 |
| Field and dead recovery | `reconstruction` | 301 | 89 | 212 |
| Sharing (ACSS-Id + dZK) | `dzk`, `dzk_store`, `acss_id`, `acss_id_store` | 3,002 | 703 | 2,299 |
| Zero sharing (Sh2t-Id) | `sh2t_id`, `sh2t_id_store` | 1,923 | 515 | 1,408 |
| Preprocessing (King) | `triple_king`, `king_store` | 3,017 | 1,180 | 1,837 |
| Online evaluation | `field_network`, `field_network_store`, `field_network_layers` | 2,397 | 786 | 1,611 |

The largest code files are `triple_king.rs` (1,195), `sh2t_id.rs` (1,052), `dzk.rs` (897) and `field_network.rs` (888).

### 6.2 What the demo-critical version keeps

**Nothing.** No binary, unit or journey of the Hetzner demo can reach this shard (5.1), and the crate sends no Host operation (2.1). Dropping the shard removes **14,944 lines**. Dropping the whole crate removes **26,139** (41 files) plus the single-consumer `native/pinned_execution.rs` (245). `hybrid_kem.rs` and `crypto_transit.rs` stay for `resource-client`. The worker's four links into this shard (summary point 1) go with the worker.

### 6.3 What a research-only trim would keep (if the MPC stays as research)

**Keep the executed MPC path plus the King crash store**, with the proposed cuts applied (about 9.7K of the shard):

| Kept | Lines (current) | Note |
| --- | ---: | --- |
| `dzk.rs` | 1,134 | inside ACSS-Id; optionally drop `transfer`/`open_proof` with ACSS public reconstruction (about 120 lines with tests) |
| `dzk_store.rs` codec part | 122 | lines 1-122 only (`acss_id_store` needs `encode_message`/`decode_message`) |
| `acss_id.rs` | 1,111 | optionally drop open, accusation and public reconstruction (about 200 code + about 200 test) |
| `acss_id_store.rs` | 370 | codec and machine used by `king_store` |
| `sh2t_id.rs`, `sh2t_id_store.rs` | 1,923 | |
| `triple_king.rs` | 1,813 | optionally drop fault localization (about 230 code + about 110 test) until something consumes it |
| `king_store.rs` | 1,204 | the only gated crash-recovery evidence for the MPC |
| `field_network.rs` | 1,267 | optionally drop the sequential runtime (about 155 code + its tests) |
| `field_network_layers.rs` | 702 | |
| `reconstruction.rs` (`Field` only) | 49 | |
| **Sum** | **about 9,695** | before the optional cuts |

**Drop from this shard in the research trim:**

| Dropped | Lines | Why |
| --- | ---: | --- |
| `acs.rs`, `acs_store.rs`, `gather.rs`, `vaba.rs` | 1,763 | no consumer; not on the executed path (keep elsewhere as a VABA research artifact only if the 2024/677 errata work matters) |
| `vaba/byz.rs`, `vaba/byz_targeted.rs` | 2,541 | test harness for the dropped layer |
| `field_network_store.rs` | 428 | not on the executed path; the online phase runs in memory in every evidence run |
| `reconstruction.rs` lines 50-301 | 252 | dead |
| `dzk_store.rs` lines 123-387 | 265 | `Store`/`DzkMachine` and tests; no consumer |
| **Total dropped** | **5,249** | plus, in shard A's files: the ACS/VABA/Gather codecs in `consensus_wire.rs` and the four unused `IngressMachine` impls (about 70 lines) |

With all the optional cuts (sequential runtime, King localization, ACSS open and public reconstruction, dZK transfer: roughly 1.1K with tests) the kept MPC protocol core is roughly 8.5K lines of this shard.

---

## 7. Deployability on a small public Linux VM (the near goal)

- **What must exist on the box:** nothing from this shard. No binary arm, systemd unit or journey uses it (5.1).
- **If someone ran it anyway:** there is no transport, so the protocols cannot run between machines. A deployment would need a committee of n = 3f+1 >= 4 independent hosts, authenticated confidential channels (absent), an anchor per holder (shard A's `anchor` arm, with F1/F7/F13 open), operator-written `Shape`s and Plans, and fixture producers (the width-8 producer was deleted, 2.5).
- **What is dangerous to expose:** everything at rest is plaintext secret material (F-B9). The declassification methods are ungated `pub fn`s (B-S4).
- **What a stranger on the internet could exercise:** nothing; no listener exists in this shard.
- **What a malicious enrolled member could exercise:** nothing; no Host op or member path reaches it.
- **Inside a hypothetical committee:** a single Byzantine member can stall every King run (F-B4), force re-search CPU costs (F-B7), demand unbounded frame retention (F-B6), and inflate the sequential Engine's maps (F-B16). These are committee-internal by design.

---

## 8. Questions for the Lean side

Each is phrased so a Lean reader can answer by pointing at a declaration, or by confirming there is none.

1. **Protocol specification.** Is there any Lean declaration stating correctness, agreement or secrecy for Bracha RBC, Reliable Agreement, IndexGather, IndexCoverGather, IndexVABA, IndexACS, ACSS-Id, the Appendix B dZK, Sh2t-Id, TripleKingDN or Beaver multiplication? My grep of `Kernel/ Compiler/ Theory/ Assurance/ Selvage/ Host/ Verify/ Pred/ Effects/` found none. If one exists under another name, which declaration, and which Rust function does it claim to model?
2. **`Assurance.MpcSealedCellExecution`.** Is its three-party, threshold-two `sharedMpc` cell meant to be the semantic counterpart of this backend? If so, which declaration fixes the committee shape? (The Rust requires n = 3f+1 >= 4; the cell is n = 3, t = 2.)
3. **Correlation identity derivation.** `Kernel.PrivateSuccessorCustody.CorrelationId` is abstract. Which Lean def should own the derivation of King preparation row ids (Rust: `DREGG.PREPARATION.ACSS.SEEDS.V1` row 0 and `DREGG.PREPARATION.SH2T.GROUP.V1` row = group over (generation, context), `triple_king.rs:216-238`) and of the checked-inventory pool id (`DREGG.CHECKED.TRIPLE.INVENTORY\x01`, `field_network.rs:78-99`)? Is "IDs omit the consumer attempt" (`CONSTRUCTION.txt:88-90`) a Lean policy anywhere?
4. **Plan binding.** `Compiler.PrivateCircuitAllocation.Plan.bindingBytes` is opaque. Is there, or should there be, a Lean producer or approver of the `DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01/\x02` format (`field_network.rs:104-182`)? Which receiver would refuse a plan whose binding names inventories or inputs the source did not admit?
5. **Declassification admission.** Which Lean declaration (CONSTRUCTION calls it "ReleaseAdmission" and "allAppliedReady", `CONSTRUCTION.txt:292-295`) should gate `AcssId::request_open`/`request_public_reconstruction`, `Sh2tId::request_open`/`request_private_reconstruction`/`request_accusation`, `Dzk::authorize_verification`/`open_proof`, and `TripleKing::begin_fault_localization`? Shard A found none by those names; is there one by another name?
6. **Protocol tags.** `Compiler.JointBackendPartyCodec` `Party.bounded` admits protocol < 4 (shard A F15). Is its intended coverage exactly Acs 0, PrivateSend 1, AcssId 2, Dzk 3? Is the absence of tags for FieldNetwork (4), PrivateOutput (5), Sh2t-Id and King frames intended? Rust has the first two and has no tag at all for the last two (`authenticated_ingress.rs:20-27`).
7. **Fixture producers.** After `212c79af` deleted `Compiler.ObliviousNatRipple [deleted 212c79af]` (`emitPairs`) and `Host.ObliviousNatAddEmit [deleted 212c79af]`, which current Lean declaration emits `fixtures/addition-network-8-plan.bin` and `addition-network-2-plan.bin`? Which emits `public-minimal-plan.bin` (142,645 B) and `objective-identity-network.bin` (the profile names edition `DREGG.OBJECTIVE.GRAPH.APPLICATION1`)? Is `Compiler/ObjectiveThunkNetwork.lean` or `Compiler/PrivateCircuitAllocationFast.lean` the producer?
8. **Burn after consumption.** `PrivateSuccessorCustody.burn` exists (`Kernel/PrivateSuccessorCustody.lean:86-89`). Rust never records a burn (shard A D2). For triples consumed by `field_network`, is a burn expected after the opening? Which declaration says when a reserved `Purpose.triple` row becomes consumed?
9. **Indistinguishability.** Is `Kernel.PrivateTurn.privateTurn_public_indistinguishable` meant to be refined by a transcript statement like the one `private_view.rs` checks empirically ("holder 3's view, apart from ROM-hidden frames, is consistent with at least three input pairs")? If so, which Assurance declaration names that refinement obligation?
10. **Lifetime.** Is there a Lean bound or retirement rule for the per-holder anchor journal that King burns and plan burns share? Rust refuses at 16 MiB forever (shard A D3), and one 429-stock Objective run reserves 13,563 plan rows plus 6 x 429 preparation rows per holder (`objective-identity-profile.json`).

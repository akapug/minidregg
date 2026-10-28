# CHANNELS: constant-rate broadcast domains

What the channel design left in this tree. The Lean modules are the authority; this document says
what they state and where they are. Section numbers and lane names follow the design of
2026-10-01 (its "revision 2"), so the `CHANNELS §N` citations in `Theory/Channel*.lean`,
`Kernel/DomainEpoch*.lean` and `native/resource-client/journey.d/jchan-epoch.sh` resolve here.

Each section is marked **shipped** (on main, module named), **deleted** (built, then removed) or
**design** (never built).

## 0. Summary

A *domain* is a room whose members each hold a lease on a slot of a fixed schedule. At every tick
every slot holder sends exactly one fixed-size cell, real or padding, to the domain's relay. The
relay assembles the tick's vector in slot order, puts a fill cell where nothing arrived, and sends
the whole vector to every slot. What an observer sees then depends on who is a member, not on who
spoke or who was online. Once per epoch the relay appends one record to the Store, so the kernel
sees one write per domain per epoch.

On main this exists as a Lean model with its theorems, the epoch record with its kernel law, and the
byte entry points a relay would link. The native relay and member client (`mini relay`,
`mini channel`, `relay.rs`, `channel.rs`, `channel-lib/`) were deleted on 2026-10-26 (874a0012c,
"traffic stack 1"). Nothing in the demo runs a channel. The journey step `KCH` exercises the epoch
record on a fresh Store.

## 2. The objects

### 2.1 Tick and class. **Shipped** (`Theory/Channel/Cell.lean`).

A class is `Profile = (C, r, E, δ, δ_relay, μ)`: cell size in bytes, tick rate, ticks per epoch,
the member's send deadline before the tick ends, the relay's deadline, and the sealing budget. The
published classes are `P0` (256 B, one tick per 10 s, E = 16), `P1` (256 B, one tick per second,
E = 16), `P1phone` (P1 with δ = 600 ms) and `P2` (1,024 B, five ticks per second, E = 64).
`Profile.fits` requires `δ + μ ≤ tick length` and `δ_relay < δ`.

### 2.2 Cell. **Shipped** (`Theory/Channel/Cell.lean`, `Theory/Channel/Envelope.lean`).

Every cell of a class is exactly `C` bytes (`cell_size_exact`), and a decoded cell re-encodes to the
same bytes (`cell_decode_canonical`). Two layouts share the size:

```
regular   header 8 | sealed (C − 24)                                  | tag 16
duty      header 8 | vrf 96 | verdictRoot 32 | accRoot 32 | sealed (C − 184) | tag 16
```

The header is `domain 2 | epoch 2 | tick 2 | slot 2`. A cell is a duty cell exactly when its tick
is 0, so the header alone decides the layout. The sealed plaintext is
`viewTag 1 | frag 4 | [epk 32] | payload`, which gives 195 or 227 payload bytes at P1 and 963 or
995 at P2 (X25519 or ML-KEM mode). `Theory/Channel/Envelope.lean` places the X25519 sealing fields
in a cell and exports `minidregg_channel_seal_cell`, `_open_cell` and `_payload_cap`. The
cryptography itself (X25519, cSHAKE256 key derivation, ChaCha20-Poly1305) is outside Lean. That a
non-recipient cannot tell payload from padding is the hypothesis `PayloadHidden` (§2.4), never a
theorem. The duty fields are placed but nothing fills them (duties are **design**).

### 2.3 Slot and lease. **Shipped** (`Theory/Channel/Lease.lean`).

A slot is a position `ρ < n` in the schedule; a `Lease` names its holder for a window of epochs.
`assemble` builds a tick's vector: at each position, the first cell the slot's live lease holder
sent under that position's header, otherwise a fill cell from the relay's PRF stream. `fanout` sends
the vector to every slot. Theorems: `header_is_schedule`, `slot_rate_bounded` (a subject's cells
per tick are bounded by the slots it holds), `no_lease_no_cell` (a non-fill cell at a position
without a live lease is not in the vector), `fill_is_cell_shaped`. Capacity above the class rate is
bought as more slots; there is no per-lease cell count. Leases paid through the kernel, and a relay
that checks them, are **design**.

### 2.4 Domain, trace and epoch record. **Shipped** (`Theory/Channel/Trace.lean`, `Kernel/DomainEpoch*.lean`).

The trace theorems model a run and five observers (wire, relay, operator, witness, non-recipient
member):

- `observable_trace_depends_only_on_membership`: with membership fixed, what the observers see does
  not depend on the traffic.
- `member_view_independent_of_presence` and `fanout_independent_of_presence`: a member's view and
  the fan-out do not depend on which members are online.

Both rest on two hypotheses: `PayloadHidden` (sealing hides the payload) and `FillHidden` (a fill
looks like a sealed body at a regular position). Each hypothesis is shown satisfiable on a toy
sealing, and each theorem is shown to fail when its hypothesis fails (the `Example.*` poles).

The epoch record (`Kernel/DomainEpoch.lean`) is `domain | epoch | class | n | E tick roots |
absentCommit`, with a canonical codec. `absentCommit` is a hiding commitment
(cSHAKE256 at `DREGG.CHANNEL.ABSENT/v1`) to the mask of absent positions. Its opening (`AbsentOpening`,
mask plus salt) goes to the operator and witnesses and never into the Store. `ChannelLaw`
(`Kernel/DomainEpochLaw.lean`) admits a record only if the class is known, it carries exactly `E`
roots, and after a previous record the domain is the same, the epoch is exactly one more and the
author is the same sequencer. `Kernel/DomainEpochStream.lean` runs the law at the stream append, and
a refusal is `Reject.channel` with the clause named. What a record proves, and to whom:
`committed_cells_agree` (any two holders), `own_omission_evident` (a member about its own slot),
`omission_evident` (holders of the opening), `relay_equivocation_transferable` (anyone with the
sequencer's key), and the limit `silent_and_dropped_indistinguishable`. Binding is always "equal, or
a collision of the named cSHAKE256 instance".

## 3. The class menu. **Shipped as data** (`Theory/Channel/Cell.lean`).

The design ranked privacy tiers T1 to T5 and priced each class. Only the class parameters of §2.1
exist in code; tiers, pricing and class switching are **design**.

## 4. Order. **Partly shipped.**

The relay is the domain's sequencer: the order is (epoch, tick, slot), and the epoch record is the
head. Shipped: the byte entry points a relay and a member link (`Kernel/DomainEpochExport.lean`:
`minidregg_channel_profile`, `_header`, `_tick_root`, `_seal`, `_open`, `_topic`, and the record's
tick roots for a member's own-slot check, the design's member loop step 6), tied to the definitions
by `relay_pipeline_is_sealEpoch` and the per-export theorems. Deleted: the relay process, the signed
tick frame and the member loop. Design: the witness's inclusion veto and any certificate over epoch
records.

## 9. Lanes

The code names these lanes of the design; only these were built:

| row | lane | what remains on main |
|---|---|---|
| 5 | CH-CELL | `Theory/Channel/{Cell,Lease,Trace}.lean`, pins in `Theory/Channel/Audit.lean` |
| 8 | CH-EPOCH | `Kernel/DomainEpoch.lean`, `DomainEpochLaw.lean`, `DomainEpochStream.lean`, `DomainEpochAudit.lean`; journey step `KCH` (`jchan-epoch.sh`) |
| 9 | CH-RELAY-1 | `Kernel/DomainEpochExport.lean`; the relay itself was deleted |
| 10 | CH-CLIENT-1 | `Theory/Channel/Envelope.lean`; the client and the Mathlib-free split of the channel modules; the client itself was deleted |

Every other row of the design (leases through the kernel, duties, pricing, two-node witnesses, DC-net
tiers, coded exchange) is **design**.

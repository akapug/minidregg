# Independent composition review — 27 October

Three focused reviews followed the actual current consumers across the Lean,
Rust and operating-system boundaries. They include offline reproductions and
state where only source reasoning, rather than a full receiving run, supports
a finding. These reports are integrated; the reported production defects are
not repaired by this review commit.

| Priority | Finding and next repair | Report |
| --- | --- | --- |
| First | Preserve uncertainty when a broker fails after sending; never turn it into a zero-charge no-send settlement. | [Provider recovery](provider-recovery.md) |
| First | Open publication references once without following links; make destination publication exclusive and directory-relative. Fence active terminals when revoking their session. | [Authority boundaries](authority.md) |
| Next | Preserve the entire selected atom sequence when quoting document lines; old published ranges must not silently add removed or unselected text. | [Content semantics](semantic-boundaries.md) |
| Next | Serialize exact authorization retries; sweep terminal replies during service without permitting another send. | [Provider recovery](provider-recovery.md) |
| Next | Check durable session deletion and verify process identity before signalling persisted PIDs. | [Authority boundaries](authority.md) |
| Next | Render wide scalar fields without loss; retain encrypted/object types in historical presentation. | [Content semantics](semantic-boundaries.md) |

Root re-read the provider send/journal/refusal mapping and the selection and
scalar consumers against main after the lane reviews. The reproductions do not
establish deployed exploits or replace receiving-path qualification. In
particular, the publication report establishes a root-to-public-UID file-copy
problem, not remote retrieval of those bytes. The provider member-attribution
collision and missing durable ticket handle remain separately scoped leads.

The appliance work is already integrated independently of this review. Its
[current checkpoint](../../oracle-appliance.md#checked-state--27-october-2026)
records the stopped v7 grant-planning failure and retained-world recovery
timeout. Full agent/browser use still awaits the lifetime-grant repair and a
coherent new Mini build. No additional Host build or live provider call was
started for these reviews.

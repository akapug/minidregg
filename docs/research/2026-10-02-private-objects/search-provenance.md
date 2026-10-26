# Search and evidence provenance

October 2, 2026. Four GPT-6.1 Sol research lanes used Kagi and Scry, followed by primary source inspection; a fifth Sol reviewed cross-contract counterexamples against Mini source. Root reconciled their findings and independently checked the critical field-write ABI, signed-command authority distinction and new paper text. No credentials are retained here.

Kagi discovery ran through the existing `claudesplosion/tools/kagi-q.sh` setup. Scry requests used its documented API and `academic.catalog` metadata, with a 15-second request ceiling. The saved [Scry records](scry-records.json) retain query IDs and coverage metadata, not full paper blobs. Coverage reported an observed maximum of September 26, 2026; it cannot establish absence of newer papers. “Complete” describes a query response, not an exhaustive literature review.

| Lane | Discovery scope | Reproducibility record |
|---|---|---|
| Messaging | Durable actor/state-machine messages, retries and asynchronous delivery | Scry `3b39d998-355f-4e1b-ae1c-589603797231`; three identities resolved; primary sections in [messaging](messaging.md) |
| Audience | Grappa persistent keys, fork-resilient CGKA, concurrent update costs | Exact Scry query, zero-result limit, source/PDF hashes and inspected sections in [audience provenance](audience-provenance.json) |
| Semantics | Capability-preserving migration, schema evolution, dynamic software updates | Two recorded exact Kagi queries, Scry scope/ID and primary sections in [semantics provenance](semantics-provenance.md) |
| Agreement | Byzantine generic/causal broadcast, invariant confluence, escrow and dependency privacy | Scry `6585efc3-f4a7-4d7d-8d60-ad7917e1c577`; primary sections and discovery limits in [agreement](agreement.md) |

The discovery scope above is a topic description where an exact query string was not retained. It must not be presented as an exhaustive or independently repeated search. Scry's zero result for fork-resilient CGKA and its misses for the two September causal papers were checked against primary sources, not treated as absence claims. The September 29 preprint was found through Kagi and read at its explicit arXiv v1 URL.

Primary citations, versions and inspected sections are embedded beside claims in each report. The new causal-broadcast and dynamic-update works are preprints; no mechanized correctness or deployment evidence was established. Older work is retained when it answers the architectural question more directly. Faré's selected source texts and the earlier local audit supplied vocabulary and counterexamples; the audit's older Mini observations were not treated as current facts.

The [source manifest](sources.json) lists full commits and Git blob identities for selected inspected files. Reproduce these with `git show COMMIT:PATH` in the named repository. The room implementation is separately pinned to feature revisions. Source scratch and downloaded papers remain temporary research conveniences; durable claims do not rely on a mutable branch name or a temporary extracted filename.

Final editorial corrections after [review](review.md): distinguish fresh release admission from completion of a historical release; separate signed stable intent from receiver-resolved guarded authority roots; require computational provenance rather than a writable checked-intent label; preserve execution lineage across translation and release changes; require authenticated deduplication retirement; distinguish historical integrity from permission to disclose history. These are contract requirements, not implemented fixes.

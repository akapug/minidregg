# Version 7 packaging

Version 7 adds the committed lazy catalog-loading service to the final U6-v2
runtime. Ordinary queries, capabilities and journal replays avoid constructing
the operations catalog. Discovery or a new direct invocation constructs it on
the existing Engine thread. Deferred counts remain unknown until construction
succeeds; a constructor failure is terminal for that worker. No provider, pool,
bridge, kernel, dependency or data change is included.

The exact U7 `APPLIANCE.json` SHA-256 is
`78773bfb4ec72633332dfd67d9a466f4022f2457371fff32d3b673bcd499844c`.
Service and README SHA-256 are `1152526eed823e0c2740961115605f5df63a45b865e8303eb2dc4dca3d98da5f`
and `62244bf82e3f9d0752c5099af4f8be807e5496adf6b57f93192517559ea29b23`.
The candidate was rehashed before staging; only those two runtime files differ
from U6-v2. All earlier candidates and signed packages remain unchanged.

Nine actual Engine behavior checks passed on an uninstrumented source overlay
whose entire adapter hash map matches this candidate. The initial runner chose
the bubblewrap wrapper during shutdown. A separate corrective-cleanup receipt
validated the original process identities and confirmed all three owned Python
processes stopped. This is not a claim that the original shutdown harness passed.
Both evidence hashes are retained in `runtime-v7-receipt.json`.

`data-selection-v7.json` is unchanged from the v5/v6 selection. Its 26-file
shared-data inventory remains
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
The existing qualified rootfs, bridge `11cb93bc…`, tenant pool `a593bbc6…` and
one-resident/128-workspace package settings are retained. A fresh grain is still
required: legacy root-level `requests.sqlite3` is refused rather than migrated.
The host must supply the trusted principal plus tab/session identity required
by the bridge; the qualified host is `8c1ad6ec…`.

Signing and independent inventory verification qualify package bytes, not Mini
admission or public availability. The next consumer is root's fresh Mini/browser
journey. This lane performs no retained-world or public deployment.


The independently verified artifact is 97,206,044 bytes, SHA-256
`e860a781dc8b897eadd002f28e388b799de92de0f019f1b357d140a9264a3888`.
All 15,372 members matched the pinned stage; the decoded archive is 520,275,720
bytes. It passed the unchanged standard profile. The local artifact and receipts
are under `o7vn/var/oracle-runtime-v7`; the protected receiving input directory is
`dregg-build:/build/lanes/oracle-v7-acceptance/inputs`. Transfer does not admit the
package or modify a retained world.

# Native birth refusals and foreground recovery

A native prepare refusal means the requested birth was denied before a signed
call was assembled. A lost client reply is different: the controller keeps it
uncertain until exact native evidence decides it. Error-message text never
changes that classification.

The runtime retains a typed `BirthRefusal` before clearing its pending birth.
The record joins the original foreground request and its digest, the complete
source-derived birth origin, and the exact native prepare refusal. The custody
marker binds the refusal frame to the signed request, pinned config and attempt
manifest; the pinned Host decodes the refusal.

`finish_no_birth` releases the delegated tool reservation at zero charge and
checks its signed idle terminal. It retains the terminal query and hashes of its
binary and JSON evidence atomically with retirement of the birth marker. A
possible submit keeps its consumed ordinal even when birth was refused.

The foreground completion path then:

1. Archives the disposition as `foreground-OOOOOOOOOOOOOOOO.birth-refusal.json`,
   where the operation number is padded to 16 decimal digits.
2. Saves the exact bounded error result before attempting parent settlement.
3. Settles the original parent hold at zero charge and marks the result definite.
4. Leaves result retrieval and acknowledgement to the existing separate
   `tool-result` and `tool-ack` paths.

The result has `isError: true`. Its `text` contains JSON with type
`mini-resource-birth-refused-v1`, the native reason, `phase: "prepare"`,
`born: false`, `toolCharge: "0"`, the native operation ID, family and ordinal.
`dispositionSha256` hashes the exact archived disposition bytes. A successful
admin reply means the result is ready; it does not mean a session was created.
The disposition remains after acknowledgement.

Ordinary attached work retains its existing hard-disconnect cleanup: a cancelled
completion claim calls the physical-stop and signed-fencing path. Explicit
operator recovery keeps the retained request fenced instead of introducing
additional disconnect effects.

## Older cleared refusal records

The existing owner-admin command also handles the narrowly identified older
session case:

```
grain-runtime admin CONFIG recover foreground session REQUESTID
```

This branch requires the same retained request and tombstone, a matching requested
and validated execution trace, a single first-session source within that trace,
and the original parent reservation. It regenerates the expected source from the
configured family, selected shared application and retained tool/parent views.
The source, current-author output, submitted intent and signed prepare request
must agree. Native codecs check the refusal and canonical cleanup calls; exact
historical lookups must confirm consecutive zero-charge release and disconnect
receipts. The current tool must still match the recorded idle terminal, and the
parent must still match its original signed reserved state.

Only then does the runtime adopt the disposition and complete the original
request as an error. This branch never calls resource creation, retries a birth,
changes factory policy, allocates a replacement foreground request, or grants
application authority. Missing or conflicting evidence remains fenced.

## Remaining recovery boundary

A crash or failure after result persistence but before successful parent
settlement retains the result, disposition and pending authority evidence. The
request stays uncertain and fenced. This command currently refuses an existing
result path or digest, including an orphan result file; it does **not** resume
that later completion stage. Exact result/settlement recovery remains separate
unfinished work. No second birth or automatic acknowledgement follows such a
failure.

The focused controlled-client tests exercise the real birth, cleanup and result
producer/consumer paths, evidence substitutions, cancelled completion and
persistence boundaries. They do not establish native admission. The retained
native refusal and cleanup checks use the frozen Host's codecs against the
original exported bytes without opening or changing the retained Store.

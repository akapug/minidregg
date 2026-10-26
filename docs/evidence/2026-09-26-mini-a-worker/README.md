# Fresh A reply worker: queued own R then Q

The committed `a2a6fa5` Rust client ran one `reply-consumer-drain-once`
against a new private A catalog Store and a qualified fn A node. The exact
already-qualified signed R and its matching Q were both posted before the
worker began. `GROUP fn.test` was `211 2 1 2 fn.test` throughout; fn consumer
ACK began at 0. This was separate from the earlier manual own-R gate and
from the completed workroom B Store.

The immutable client was SHA-256
`909d4886448d18072012a28871554b8dd88c59f0c965e422f26dff99c2afeed1`.
The certified Host was
`c37a35073b9d19ac342d91ba0a071b3a732f51b0f5f0991fc995ec64573edcff`.
The operator A catalog config bytes were SHA-256
`0a2d68ef26652cd41de2de8a37099ad12458f8dfa4373284ae47ccf90a1b263b`;
the resulting private route-bound worker pin was SHA-256
`9cf53bd3d425fa2ee7a1747de31275e5454b5f5b24e372a20fad99b0b70eea0d`.

The first op14 returned `skip-decision` / `fn-a-own-r-progress-decision-v1`,
`proposed-fresh`, position 0→5, bound to the accepted tag10 outbox transaction
`11988063685724989057941704507037411204956185069166548165162123111078764190396`.
The worker durably retained its exact call (SHA-256
`eb0216271961f3d05a8ba88fcfea18701d8e10a10aca9a6ffb8bfe884df9b002`),
received installed Mini transaction
`112101329255143933684920207764758302865815217170626990595005098142712671201311`
at accepted count 4, and got op15 `kind:own-r-skip`,
`fnAck:durable-accepted`, cursor/committed ACK 5, fn Store sequence 4.
The retained poll and ACK frames have SHA-256
`946c82bcc5154829eff98b9a0851b497408d2e1e7e325274f5f071a273c7f3bf`
and `d11646b303eb6acff81aa4799c3f6fea7309fc556b2c1ab668ce03b521d5e30b`.

Within that same drain invocation, without a new article or GROUP change, the
worker polled again. Op14 returned `accepted-decision` /
`fn-a-reply-consumer-decision-v1`, `proposed-fresh` for Q at fn Store sequence
and transaction 5. Its retained call SHA-256 was
`2a319b969ddb9810d18250a9d55ea72391e33c22467e01f508b82fd66b710da2`.
Mini installed transaction
`84380737485510178003017356522143666475906322102214384104983212602615550154531`
at accepted count 5; op15 returned `fnAck:durable-accepted` for Store 5.
The retained poll and ACK frame SHA-256 values were
`2aea830590d3ccc69aeca03bedef404a5779935e6003e357d3627a9ac2d835aa`
and `3035b3eb0aec76afdb8ba6c2e871d4b0bd4e20b06e4fd0668f51099ed5f599dd`.

The command exited 0 with `consumer wake stopped: Publication`. Both exact
transactions were archived under the private worker state; there was no
pending attempt. Read-only fn status afterward was committed ACK 6, journal
frontier 8, distance 2; GROUP remained 2. The full private frames, calls,
signatures, Store, and custody key stay under
`/tmp/mini-workroom-a-worker-20260926-1` and are not copied here.

This gate demonstrates the bounded drain path for queued R→Q and durable
ACKs. It does not yet demonstrate a killed/restarted worker or the continuous
GROUP scheduler; those require separate evidence.

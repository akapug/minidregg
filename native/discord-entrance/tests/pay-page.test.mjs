// The door's wallet page against a fake wallet and a fake cluster: no key leaves this process and no payment
// is made. Asserts the transaction the page builds (one TransferChecked of the quoted amount, mint and
// decimals from the payer's associated account to the recipient's, by the payer; one Memo with the exact
// bytes) and that the signature the fake cluster returned is what the page posts to /join/paid.
import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
vm.runInThisContext(fs.readFileSync(path.join(here, "../assets/vendor/web3.js"), "utf8"));
vm.runInThisContext(fs.readFileSync(path.join(here, "../assets/pay.js"), "utf8"));
const web3 = globalThis.solanaWeb3;
const makeDoorPay = globalThis.makeDoorPay;
assert.ok(web3 && makeDoorPay, "the vendored web3 and pay.js load");

const payer = web3.Keypair.generate();
const recipient = web3.Keypair.generate().publicKey;
const mint = web3.Keypair.generate().publicKey;
const quote = { id: "7f3a", recipient: recipient.toBase58(), mint: mint.toBase58(), tokenProgram: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
  decimals: "6", amountAtomic: "50000007", memo: "enrol:v2:AAAA/zz+", rpc: "http://cluster.invalid" };
let sent = null, posted = null;
const fakeSignature = "5".repeat(87);
const conn = {
  getAccountInfo: async (k) => (k.equals(makeDoorPay(web3, quote, {}).ata(recipient)) ? { lamports: 1 } : null),
  getTokenAccountBalance: async () => ({ value: { amount: "999999999" } }),
  getLatestBlockhash: async () => ({ blockhash: web3.Keypair.generate().publicKey.toBase58(), lastValidBlockHeight: 1 }),
  sendRawTransaction: async (raw) => { sent = raw; return fakeSignature; },
};
const provider = { name: "Fake", publicKey: payer.publicKey, async connect() { return { publicKey: payer.publicKey }; }, async signTransaction(tx) { tx.partialSign(payer); return tx; } };
let sentBeforePost = null;
const fetchImpl = async (url, options) => { posted = { url, options }; sentBeforePost = onSentSeen; return { status: 200, ok: true, text: async () => "" }; };
let onSentSeen = null;

const pay = makeDoorPay(web3, quote, { conn, fetch: fetchImpl });
const said = [];
const result = await pay.pay(provider, (t) => said.push(t), (sig) => { onSentSeen = sig; });
assert.equal(sentBeforePost, fakeSignature, "the payer holds the signature before the door is asked (fix 2)");

const tx = web3.Transaction.from(sent);
assert.equal(tx.instructions.length, 2, "one transfer and one memo");
const [transfer, memo] = tx.instructions;
assert.equal(transfer.programId.toBase58(), quote.tokenProgram);
assert.equal(transfer.data[0], 12, "TransferChecked");
let amount = 0n; for (let i = 7; i >= 0; i--) amount = (amount << 8n) | BigInt(transfer.data[1 + i]);
assert.equal(amount.toString(), quote.amountAtomic);
assert.equal(transfer.data[9], 6, "decimals");
const ata = pay.ata;
assert.deepEqual(transfer.keys.map((k) => [k.pubkey.toBase58(), k.isSigner, k.isWritable]), [
  [ata(payer.publicKey).toBase58(), false, true], [mint.toBase58(), false, false], [ata(recipient).toBase58(), false, true], [payer.publicKey.toBase58(), true, true] ]); // the owner signs and, as the fee payer, is writable
assert.equal(memo.programId.toBase58(), "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
assert.equal(Buffer.from(memo.data).toString("utf8"), quote.memo, "the memo bytes are the quote's memo, exactly");
assert.equal(tx.feePayer.toBase58(), payer.publicKey.toBase58());
assert.ok(tx.verifySignatures(), "the fake wallet's signature verifies");
assert.equal(result.signature, fakeSignature);
assert.equal(posted.url, "/join/paid");
assert.equal(posted.options.method, "POST");
assert.equal(posted.options.body, "id=7f3a&transaction=" + fakeSignature, "the paste path's field, filled automatically");
assert.ok(said.some((t) => t.startsWith("the wallet is signing")) && said.some((t) => t.startsWith("sent " + fakeSignature)));

// A missing recipient account is refused before anything is signed; nothing is created.
let signedWhenMissing = false;
const refusing = makeDoorPay(web3, quote, { conn: { ...conn, getAccountInfo: async () => null }, fetch: fetchImpl });
await assert.rejects(refusing.pay({ ...provider, async signTransaction(tx) { signedWhenMissing = true; return tx; } }), /does not exist/);
assert.equal(signedWhenMissing, false);
// Fix 6: a wallet that swaps the recipient's account is refused before anything is sent.
{
  let sentSwapped = false;
  const thief = web3.Keypair.generate().publicKey;
  const swapping = makeDoorPay(web3, quote, { conn: { ...conn, sendRawTransaction: async () => { sentSwapped = true; return fakeSignature; } }, fetch: fetchImpl });
  const evil = { ...provider, async signTransaction(tx) {
    const t = web3.Transaction.from(tx.serialize({ requireAllSignatures: false, verifySignatures: false }));
    t.instructions[0].keys[2].pubkey = swapping.ata(thief);
    t.partialSign(payer); return t; } };
  await assert.rejects(swapping.pay(evil), /refused, nothing was sent: instruction 0 names other accounts/);
  assert.equal(sentSwapped, false, "the swapped transaction never reaches the cluster");
}

// Fix 1: a door that refuses the POST (409, 429) is said as a refusal naming the signature, never "posted".
{
  let held = null;
  const refusing409 = makeDoorPay(web3, quote, { conn, fetch: async () => ({ status: 409, ok: false, text: async () => "<h1>Not accepted</h1><p>this step is already queued</p><p><a href=/join>Back</a></p>" }) });
  await assert.rejects(refusing409.pay(provider, () => {}, (s) => { held = s; }),
    (e) => /did not accept it \(409: this step is already queued\)/.test(e.message) && e.message.includes(fakeSignature) && /Do not pay again/.test(e.message));
  assert.equal(held, fakeSignature);
}

// Fix 3: a quote past its expiry hour is refused before the wallet is asked to sign.
{
  let asked = false;
  const old = { ...quote, expiryHour: "1001", asOfHour: "1000", quotedAt: 1_000_000 };
  const later = makeDoorPay(web3, old, { conn, fetch: fetchImpl, now: () => (1_000_000 + 2 * 3600 + 5) * 1000 });
  assert.match(later.stale(), /expired at processing-chain hour 1001 \(it is now about hour 1002\)/);
  await assert.rejects(later.pay({ ...provider, async signTransaction(tx) { asked = true; return tx; } }), /expired/);
  assert.equal(asked, false);
  const fresh = makeDoorPay(web3, old, { conn, fetch: fetchImpl, now: () => (1_000_000 + 1800) * 1000 });
  assert.equal(fresh.stale(), null, "inside the hour the quote stands");
}

console.log("ok: transfer " + amount + " atomic (decimals 6) " + ata(payer.publicKey).toBase58().slice(0, 6) + "… -> " + ata(recipient).toBase58().slice(0, 6) + "…, memo " + JSON.stringify(quote.memo) + ", posted " + fakeSignature.slice(0, 8) + "…");

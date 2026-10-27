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
const fetchImpl = async (url, options) => { posted = { url, options }; return { status: 200 }; };

const pay = makeDoorPay(web3, quote, { conn, fetch: fetchImpl });
const said = [];
const result = await pay.pay(provider, (t) => said.push(t));

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
assert.ok(said.some((t) => t.startsWith("the wallet is signing")) && said.some((t) => t.startsWith("posting")));

// A missing recipient account is refused before anything is signed; nothing is created.
let signedWhenMissing = false;
const refusing = makeDoorPay(web3, quote, { conn: { ...conn, getAccountInfo: async () => null }, fetch: fetchImpl });
await assert.rejects(refusing.pay({ ...provider, async signTransaction(tx) { signedWhenMissing = true; return tx; } }), /does not exist/);
assert.equal(signedWhenMissing, false);
console.log("ok: transfer " + amount + " atomic (decimals 6) " + ata(payer.publicKey).toBase58().slice(0, 6) + "… -> " + ata(recipient).toBase58().slice(0, 6) + "…, memo " + JSON.stringify(quote.memo) + ", posted " + fakeSignature.slice(0, 8) + "…");

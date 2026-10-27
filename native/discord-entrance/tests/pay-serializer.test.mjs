// The door's one-shape serializer (assets/solpay.js) against golden vectors that @solana/web3.js 1.99.0 produced
// before the SDK was removed from the door (support/pay-golden.json: 42 pay shapes with Token and Token-2022,
// decimals 0..38, amounts to 2^64-1, non-ASCII memos; 25 random generic messages; 120 curve points incl. edges).
// Message bytes, signed wire bytes, unsigned wire bytes and the associated token accounts must be identical.
// The fixture was emitted by the commit before this one, which still carried the bundle and compared live.
import fs from "node:fs";
import vm from "node:vm";
import crypto from "node:crypto";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
vm.runInThisContext(fs.readFileSync(path.join(here, "../assets/solpay.js"), "utf8"));
const sol = globalThis.solpay;
const golden = JSON.parse(fs.readFileSync(path.join(here, "support/pay-golden.json"), "utf8"));
const hex = (u) => Buffer.from(u).toString("hex");
const unhex = (s) => Uint8Array.from(Buffer.from(s, "hex"));

for (const [i, g] of golden.pay.entries()) {
  const owner = new sol.PublicKey(g.owner), mint = new sol.PublicKey(g.mint), tp = new sol.PublicKey(g.tokenProgram), rcpt = new sol.PublicKey(g.recipient);
  const ixs = [sol.transferChecked({ tokenProgram: tp, source: sol.ata(owner, tp, mint), mint, destination: sol.ata(rcpt, tp, mint), owner, amount: BigInt(g.amountAtomic), decimals: g.decimals }),
    sol.memo(owner, new TextEncoder().encode(g.memo))];
  const message = sol.compileMessage({ feePayer: owner, recentBlockhash: g.blockhash, instructions: ixs });
  assert.equal(hex(message), g.messageHex, "golden pay " + i + ": message");
  assert.equal(hex(sol.wireWith([unhex(g.signature)], message)), "01" + g.signature + g.messageHex, "golden pay " + i + ": signed wire = one signature, then the message");
  assert.equal(hex(sol.unsignedWire(message)), "01" + "00".repeat(64) + g.messageHex, "golden pay " + i + ": unsigned wire = a zeroed slot, then the message");
  assert.deepEqual([sol.ata(owner, tp, mint).toBase58(), sol.ata(rcpt, tp, mint).toBase58()], g.ata, "golden pay " + i + ": ata");
  const d = sol.decodeWire(sol.wireWith([unhex(g.signature)], message));
  assert.equal(hex(d.message), g.messageHex, "decode keeps the message");
  assert.equal(d.feePayer.toBase58(), g.owner);
  assert.equal(hex(d.instructions[0].data).slice(0, 2), "0c", "TransferChecked");
  assert.equal(Buffer.from(d.instructions[1].data).toString("utf8"), g.memo, "the memo bytes");
}
for (const [i, g] of golden.generic.entries()) {
  const message = sol.compileMessage({ feePayer: new sol.PublicKey(g.feePayer), recentBlockhash: g.blockhash,
    instructions: g.instructions.map((x) => ({ programId: new sol.PublicKey(x.programId), data: unhex(x.data), keys: x.keys.map((k) => ({ ...k, pubkey: new sol.PublicKey(k.pubkey) })) })) });
  assert.equal(hex(message), g.messageHex, "golden generic " + i);
}
let on = 0;
for (const v of golden.curve) { on += v.onCurve ? 1 : 0; assert.equal(sol.isOnCurve(unhex(v.hex)), v.onCurve, "golden curve " + v.hex); }
assert.ok(on > 20 && on < golden.curve.length - 20, "the vectors hold both answers (" + on + " on the curve)");

// base58 and SHA-256 against node:crypto and known values
for (let i = 0; i < 60; i++) {
  const u = crypto.randomBytes(i);
  assert.equal(hex(sol.sha256(u)), crypto.createHash("sha256").update(u).digest("hex"), "sha256 of " + i + " bytes");
  assert.equal(hex(sol.b58decode(sol.b58encode(u))), hex(u), "base58 round trip");
}
assert.equal(sol.b58encode(new Uint8Array(32)), "11111111111111111111111111111111");
assert.equal(sol.b58encode(Buffer.from("hello world")), "StV1DL6CwTryKyV");
assert.throws(() => sol.b58decode("0OIl"), /not base58/);
console.log("ok: " + golden.pay.length + " pay shapes, " + golden.generic.length + " generic messages and " + golden.curve.length + " curve points equal the bundle's golden vectors");

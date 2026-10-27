// The door's one-shape serializer (assets/solpay.js) against @solana/web3.js 1.99.0: the same quotes through
// both must give identical message bytes and identical signed wire bytes, and the on-curve test, base58 and
// SHA-256 must agree on random inputs. `node pay-serializer.test.mjs --emit-golden` rewrites
// support/pay-golden.json from the bundle; the golden check (what survives the bundle's deletion) always runs.
import fs from "node:fs";
import vm from "node:vm";
import crypto from "node:crypto";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (f) => vm.runInThisContext(fs.readFileSync(path.join(here, "../assets", f), "utf8"));
load("vendor/web3.js"); load("solpay.js");
const web3 = globalThis.solanaWeb3, sol = globalThis.solpay;
const GOLDEN = path.join(here, "support/pay-golden.json");

// a fixed-seed generator: the cases are the same on every run
let state = 0x9e3779b97f4a7c15n;
const rnd = () => { state ^= state << 13n; state &= 0xffffffffffffffffn; state ^= state >> 7n; state ^= state << 17n; state &= 0xffffffffffffffffn; return state; };
const bytes = (n) => Uint8Array.from({ length: n }, () => Number(rnd() & 0xffn));
const pick = (xs) => xs[Number(rnd() % BigInt(xs.length))];
const hex = (u) => Buffer.from(u).toString("hex");
const unhex = (s) => Uint8Array.from(Buffer.from(s, "hex"));

const TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", TOKEN22 = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb";
const MEMO_V2 = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr";
const memos = ["enrol:v2:AAAA/zz+", "x", "enrol:v2:é漢字🙂\u0000end", "a".repeat(100), "enrol:v2:" + "Zz9".repeat(20)];
const amounts = ["1", "50000007", "9007199254740993", "18446744073709551615", "0", "255", "256", "65536"];
const b58 = (u) => sol.b58encode(u);

// ---- the pay page's transaction: cases ----
const payCases = [];
for (let i = 0; i < 40; i++) {
  payCases.push({ owner: b58(bytes(32)), recipient: b58(bytes(32)), mint: b58(bytes(32)), tokenProgram: pick([TOKEN, TOKEN22]),
    decimals: pick([0, 1, 6, 9, 18, 38]), amountAtomic: pick(amounts), memo: pick(memos), blockhash: b58(bytes(32)), signature: hex(bytes(64)) });
}
// the owner is the recipient; the mint is the owner (degenerate, still a valid table with merged flags)
payCases.push({ ...payCases[0], recipient: payCases[0].owner });
payCases.push({ ...payCases[1], mint: payCases[1].owner });

function ours(c) {
  const owner = new sol.PublicKey(c.owner), mint = new sol.PublicKey(c.mint), tp = new sol.PublicKey(c.tokenProgram), rcpt = new sol.PublicKey(c.recipient);
  const ixs = [sol.transferChecked({ tokenProgram: tp, source: sol.ata(owner, tp, mint), mint, destination: sol.ata(rcpt, tp, mint), owner, amount: BigInt(c.amountAtomic), decimals: c.decimals }),
    sol.memo(owner, new TextEncoder().encode(c.memo))];
  const message = sol.compileMessage({ feePayer: owner, recentBlockhash: c.blockhash, instructions: ixs });
  return { message, wire: sol.wireWith([unhex(c.signature)], message), unsigned: sol.unsignedWire(message), ata: [sol.ata(owner, tp, mint).toBase58(), sol.ata(rcpt, tp, mint).toBase58()] };
}
function bundle(c) {
  const { PublicKey, Transaction, TransactionInstruction } = web3;
  const owner = new PublicKey(c.owner), mint = new PublicKey(c.mint), tp = new PublicKey(c.tokenProgram), rcpt = new PublicKey(c.recipient);
  const ATA = new PublicKey("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
  const ata = (o) => PublicKey.findProgramAddressSync([o.toBytes(), tp.toBytes(), mint.toBytes()], ATA)[0];
  const data = new Uint8Array(10); data[0] = 12; let v = BigInt(c.amountAtomic); for (let i = 0; i < 8; i++) { data[1 + i] = Number(v & 0xffn); v >>= 8n; } data[9] = c.decimals;
  const tx = new Transaction({ feePayer: owner, recentBlockhash: c.blockhash }).add(
    new TransactionInstruction({ programId: tp, data, keys: [{ pubkey: ata(owner), isSigner: false, isWritable: true }, { pubkey: mint, isSigner: false, isWritable: false },
      { pubkey: ata(rcpt), isSigner: false, isWritable: true }, { pubkey: owner, isSigner: true, isWritable: false }] }),
    new TransactionInstruction({ programId: new PublicKey(MEMO_V2), data: new TextEncoder().encode(c.memo), keys: [{ pubkey: owner, isSigner: true, isWritable: false }] }));
  const unsigned = tx.serialize({ requireAllSignatures: false, verifySignatures: false });
  tx.addSignature(owner, Buffer.from(c.signature, "hex"));
  return { message: tx.serializeMessage(), wire: tx.serialize({ requireAllSignatures: false, verifySignatures: false }), unsigned, ata: [ata(owner).toBase58(), ata(rcpt).toBase58()] };
}

// ---- generic messages: random instruction sets, duplicate accounts, flag merging, fee payer among the metas ----
function genericCases(n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const pool = Array.from({ length: 2 + Number(rnd() % 12n) }, () => b58(bytes(32)));
    const ix = Array.from({ length: 1 + Number(rnd() % 4n) }, () => ({
      programId: pick(pool),
      keys: Array.from({ length: Number(rnd() % 7n) }, () => ({ pubkey: pick(pool), isSigner: rnd() % 4n === 0n, isWritable: rnd() % 2n === 0n })),
      data: hex(bytes(Number(rnd() % 40n))) }));
    out.push({ feePayer: pick(pool), blockhash: b58(bytes(32)), instructions: ix });
  }
  return out;
}
const genOurs = (g) => sol.compileMessage({ feePayer: new sol.PublicKey(g.feePayer), recentBlockhash: g.blockhash,
  instructions: g.instructions.map((x) => ({ programId: new sol.PublicKey(x.programId), data: unhex(x.data), keys: x.keys.map((k) => ({ ...k, pubkey: new sol.PublicKey(k.pubkey) })) })) });
function genBundle(g) {
  const tx = new web3.Transaction({ feePayer: new web3.PublicKey(g.feePayer), recentBlockhash: g.blockhash });
  for (const x of g.instructions) tx.add(new web3.TransactionInstruction({ programId: new web3.PublicKey(x.programId), data: Buffer.from(x.data, "hex"), keys: x.keys.map((k) => ({ ...k, pubkey: new web3.PublicKey(k.pubkey) })) }));
  return tx.serializeMessage();
}

// ---- curve points: random, plus the edges (y >= p, x = 0 with the sign bit, y = 0, 1, -1) ----
function curveVectors() {
  const v = Array.from({ length: 300 }, () => bytes(32));
  const le = (n) => { const u = new Uint8Array(32); for (let i = 0; i < 32; i++) { u[i] = Number(n & 0xffn); n >>= 8n; } return u; };
  const p = (1n << 255n) - 19n;
  for (const y of [0n, 1n, 2n, p - 1n, p, p + 1n, (1n << 255n) - 1n, 1n << 254n]) { const u = le(y); v.push(u); const s = Uint8Array.from(u); s[31] |= 0x80; v.push(s); }
  return v;
}

if (process.argv.includes("--emit-golden")) {
  const golden = {
    note: "emitted from @solana/web3.js 1.99.0 by pay-serializer.test.mjs --emit-golden; fixed-seed cases",
    pay: payCases.map((c) => ({ ...c, ...(({ message, ata }) => ({ messageHex: hex(message), ata }))(bundle(c)) })),
    generic: genericCases(25).map((g) => ({ ...g, messageHex: hex(genBundle(g)) })),
    curve: curveVectors().slice(0, 120).map((u) => ({ hex: hex(u), onCurve: web3.PublicKey.isOnCurve(u) })),
  };
  fs.writeFileSync(GOLDEN, JSON.stringify(golden) + "\n");
  console.log("wrote", GOLDEN, fs.statSync(GOLDEN).size, "bytes");
  process.exit(0);
}

// ---- live: the serializer equals the bundle ----
for (const [i, c] of payCases.entries()) {
  const a = ours(c), b = bundle(c);
  assert.equal(hex(a.message), hex(b.message), "pay case " + i + ": message bytes");
  assert.equal(hex(a.wire), hex(b.wire), "pay case " + i + ": signed wire bytes");
  assert.equal(hex(a.unsigned), hex(b.unsigned), "pay case " + i + ": unsigned wire bytes (what the wallet is handed)");
  assert.deepEqual(a.ata, b.ata, "pay case " + i + ": associated token accounts");
  const d = sol.decodeWire(a.wire);
  assert.equal(hex(d.message), hex(a.message), "decode keeps the message");
  assert.equal(web3.Transaction.from(a.wire).instructions.length, 2, "the SDK reads our wire");
}
for (const [i, g] of genericCases(200).entries()) assert.equal(hex(genOurs(g)), hex(genBundle(g)), "generic message " + i);
let on = 0;
for (const u of curveVectors()) { const want = web3.PublicKey.isOnCurve(u); on += want ? 1 : 0; assert.equal(sol.isOnCurve(u), want, "on-curve " + hex(u)); }
assert.ok(on > 100 && on < 220, "the random points are about half on the curve (" + on + ")");
for (let i = 0; i < 50; i++) {
  const u = bytes(Number(rnd() % 70n));
  assert.equal(hex(sol.sha256(u)), crypto.createHash("sha256").update(u).digest("hex"), "sha256 of " + u.length + " bytes");
  assert.equal(hex(sol.b58decode(sol.b58encode(u))), hex(u), "base58 round trip");
}
for (const u of [Uint8Array.of(), Uint8Array.of(0), Uint8Array.of(0, 0, 1), new Uint8Array(32), new Uint8Array(32).fill(255)]) assert.equal(hex(sol.b58decode(sol.b58encode(u))), hex(u));
assert.equal(sol.b58encode(new Uint8Array(32)), "11111111111111111111111111111111");

// ---- golden: what survives the bundle ----
const golden = JSON.parse(fs.readFileSync(GOLDEN, "utf8"));
for (const [i, g] of golden.pay.entries()) {
  const a = ours(g);
  assert.equal(hex(a.message), g.messageHex, "golden pay " + i + ": message");
  assert.equal(hex(a.wire), "01" + g.signature + g.messageHex, "golden pay " + i + ": signed wire = one signature, then the message");
  assert.equal(hex(a.unsigned), "01" + "00".repeat(64) + g.messageHex, "golden pay " + i + ": unsigned wire = a zeroed slot, then the message");
  assert.deepEqual(a.ata, g.ata, "golden pay " + i + ": ata");
}
for (const [i, g] of golden.generic.entries()) assert.equal(hex(genOurs(g)), g.messageHex, "golden generic " + i);
for (const v of golden.curve) assert.equal(sol.isOnCurve(unhex(v.hex)), v.onCurve, "golden curve " + v.hex);
console.log("ok: " + payCases.length + " pay shapes, 200 generic messages and " + curveVectors().length + " curve points equal the bundle; " + golden.pay.length + "+" + golden.generic.length + "+" + golden.curve.length + " golden vectors hold");

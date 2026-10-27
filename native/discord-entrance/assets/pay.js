// The door's wallet payment, isomorphic like passwap.js: pass in the @solana/web3.js namespace, the quote the
// status page embeds (recipient, mint, tokenProgram, decimals, amountAtomic, memo, id, rpc), and the page's
// connection and fetch. Nothing here decides anything: the quote is the processor's, the transaction is the
// wallet's to sign, the cluster's to admit, and the door's observer matches what landed.
//
//   const pay = makeDoorPay(web3, quote, { conn, fetch })
//   pay.instructions(owner)      -> [transferChecked(owner's ATA -> recipient's ATA, amount, decimals), memo(exact bytes)]
//   await pay.pay(provider, say, onSent)
//                                -> { signature, status, tx }: refuse a quote past its expiry hour; connect, check
//                                   both token accounts, build, sign; refuse a signed transaction that is not exactly
//                                   the one built; send from the browser; hand the signature to onSent at once (the
//                                   payer holds it before anything else can fail); post it to /join/paid (the paste
//                                   path's field) and throw, naming the signature, unless the door accepted it.
//   pay.stale()                  -> null, or why this quote must not be paid (its processing-chain hour has passed)
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.makeDoorPay = factory();
})(typeof self !== "undefined" ? self : this, function () {
  return function makeDoorPay(web3, quote, deps) {
    const { PublicKey, Transaction, TransactionInstruction } = web3;
    // The associated-token-account program and SPL Memo (the watcher reads both memo programs; v2 is the one to write).
    const ATA_PROGRAM = new PublicKey("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL");
    const MEMO_PROGRAM = new PublicKey("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
    for (const k of ["recipient", "mint", "tokenProgram", "decimals", "amountAtomic", "memo", "id"]) {
      if (quote[k] === undefined || quote[k] === null || quote[k] === "") throw new Error("the quote lacks " + k);
    }
    const mint = new PublicKey(quote.mint), tokenProgram = new PublicKey(quote.tokenProgram), recipient = new PublicKey(quote.recipient);
    const amount = BigInt(quote.amountAtomic), decimals = Number(quote.decimals);
    if (!(decimals >= 0 && decimals <= 38)) throw new Error("the quote's decimals are not a token's");
    const memoBytes = new TextEncoder().encode(quote.memo); // the exact bytes `mini join` expects: the memo string, UTF-8, nothing added
    const ata = (owner) => PublicKey.findProgramAddressSync([owner.toBytes(), tokenProgram.toBytes(), mint.toBytes()], ATA_PROGRAM)[0];
    const now = deps.now || (() => Date.now());

    // The processing-chain hour advances with the chain's clock; from the hour `mini join` saw when
    // it quoted (asOfHour) and when that was (quotedAt), the hour now is at least asOfHour plus the
    // whole hours since. A memo processed after expiryHour is a pending claim, never an enrolment.
    function stale() {
      if (quote.asOfHour === undefined || quote.asOfHour === null || !quote.quotedAt) return null;
      const hour = Number(quote.asOfHour) + Math.floor((now() / 1000 - Number(quote.quotedAt)) / 3600);
      return hour > Number(quote.expiryHour)
        ? "this quote expired at processing-chain hour " + quote.expiryHour + " (it is now about hour " + hour + "): paying it now would leave a pending claim, not an account. Start a new request at /join."
        : null;
    }

    // The wallet must sign exactly what was built: the same instructions, accounts, flags and data,
    // and the payer as fee payer. A wallet (or an extension in between) that changed the recipient,
    // the amount or the memo is refused before anything is sent.
    function sameAsBuilt(signed, owner) {
      const want = instructions(owner);
      const got = signed.instructions || [];
      if (got.length !== want.length) return "the wallet returned " + got.length + " instructions where " + want.length + " were built";
      for (let i = 0; i < want.length; i++) {
        const a = want[i], b = got[i];
        if (!a.programId.equals(b.programId)) return "instruction " + i + " names another program";
        if (a.keys.length !== b.keys.length || a.keys.some((k, j) => !k.pubkey.equals(b.keys[j].pubkey) || k.isSigner !== b.keys[j].isSigner || k.isWritable !== b.keys[j].isWritable)) return "instruction " + i + " names other accounts";
        const da = Uint8Array.from(a.data), db = Uint8Array.from(b.data);
        if (da.length !== db.length || da.some((x, j) => x !== db[j])) return "instruction " + i + " carries other data";
      }
      if (!signed.feePayer || !signed.feePayer.equals(owner)) return "the fee payer is not your wallet";
      return null;
    }

    function instructions(owner) {
      const data = new Uint8Array(10);
      data[0] = 12; // TransferChecked
      let v = amount;
      for (let i = 0; i < 8; i++) { data[1 + i] = Number(v & 0xffn); v >>= 8n; }
      data[9] = decimals;
      const transfer = new TransactionInstruction({ programId: tokenProgram, data, keys: [
        { pubkey: ata(owner), isSigner: false, isWritable: true },
        { pubkey: mint, isSigner: false, isWritable: false },
        { pubkey: ata(recipient), isSigner: false, isWritable: true },
        { pubkey: owner, isSigner: true, isWritable: false } ] });
      const memo = new TransactionInstruction({ programId: MEMO_PROGRAM, data: memoBytes, keys: [{ pubkey: owner, isSigner: true, isWritable: false }] });
      return [transfer, memo];
    }

    async function pay(provider, say, onSent) {
      say = say || (() => {});
      onSent = onSent || (() => {});
      const late = stale();
      if (late) throw new Error(late);
      say("connecting to " + (provider.name || "the wallet"));
      const connected = await provider.connect();
      const owner = new PublicKey(((connected && connected.publicKey) || provider.publicKey).toString());
      say("checking the token accounts");
      const to = ata(recipient);
      if (!(await deps.conn.getAccountInfo(to))) {
        throw new Error("the recipient's token account for this mint does not exist on the cluster the page names; this page will not create it. Pay by the paste path below and tell the operator.");
      }
      const from = ata(owner);
      const balance = await deps.conn.getTokenAccountBalance(from).catch(() => null);
      if (!balance || BigInt(balance.value.amount) < amount) {
        throw new Error("your wallet " + owner.toBase58() + " holds " + (balance ? balance.value.amount : "no account") + " of this token; the quote needs " + quote.amountAtomic + " atomic units.");
      }
      const tx = new Transaction().add(...instructions(owner));
      tx.feePayer = owner;
      const { blockhash } = await deps.conn.getLatestBlockhash("confirmed");
      tx.recentBlockhash = blockhash;
      say("the wallet is signing");
      const signed = await provider.signTransaction(tx);
      const changed = sameAsBuilt(signed, owner);
      if (changed) throw new Error("refused, nothing was sent: " + changed + ". Pay by the paste path below with a wallet you trust.");
      const lateNow = stale();
      if (lateNow) throw new Error(lateNow);
      say("sending from this browser to " + (quote.rpc || "the cluster"));
      const signature = await deps.conn.sendRawTransaction(signed.serialize(), { skipPreflight: false });
      onSent(signature);
      say("sent " + signature + "; posting it to the door");
      const body = new URLSearchParams({ id: quote.id, transaction: signature }).toString();
      let res;
      try {
        res = await deps.fetch("/join/paid", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body, credentials: "same-origin", redirect: "follow" });
      } catch (e) {
        throw new Error("your payment was sent (" + signature + ") but the door could not be reached: paste that signature below; do not pay again. (" + String(e && e.message || e) + ")");
      }
      if (!res.ok) {
        const page = res.text ? await res.text().catch(() => "") : "";
        const why = page.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").replace(/^\s*Not accepted\s*/, "").replace(/\s*Back\s*$/, "").trim().slice(0, 300);
        throw new Error("your payment was sent (" + signature + ") but the door did not accept it (" + res.status + (why ? ": " + why : "") + "). Do not pay again: paste that signature below once the door accepts posts.");
      }
      return { signature, status: res.status, tx: signed };
    }
    return { ATA_PROGRAM, MEMO_PROGRAM, ata, instructions, pay, stale, sameAsBuilt };
  };
});

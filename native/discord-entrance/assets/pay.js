// The door's wallet payment, isomorphic like passwap.js: pass in the @solana/web3.js namespace, the quote the
// status page embeds (recipient, mint, tokenProgram, decimals, amountAtomic, memo, id, rpc), and the page's
// connection and fetch. Nothing here decides anything: the quote is the processor's, the transaction is the
// wallet's to sign, the cluster's to admit, and the door's observer matches what landed.
//
//   const pay = makeDoorPay(web3, quote, { conn, fetch })
//   pay.instructions(owner)      -> [transferChecked(owner's ATA -> recipient's ATA, amount, decimals), memo(exact bytes)]
//   await pay.pay(provider, say) -> { signature, status, tx }: connect, check both token accounts, build, sign, send
//                                   from the browser, post the signature to /join/paid (the paste path's field)
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

    async function pay(provider, say) {
      say = say || (() => {});
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
      say("sending from this browser to " + (quote.rpc || "the cluster"));
      const signature = await deps.conn.sendRawTransaction(signed.serialize(), { skipPreflight: false });
      say("posting the signature to the door");
      const body = new URLSearchParams({ id: quote.id, transaction: signature }).toString();
      const res = await deps.fetch("/join/paid", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body, credentials: "same-origin", redirect: "follow" });
      return { signature, status: res.status, tx: signed };
    }
    return { ATA_PROGRAM, MEMO_PROGRAM, ata, instructions, pay };
  };
});

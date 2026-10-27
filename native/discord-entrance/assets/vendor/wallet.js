// passwap wallet adapter, from ember's sol-misc (docs/passwap/wallet.js, 2026-10-27), reduced for the door:
// the one provider shape {name, icon, connect(), publicKey, signTransaction(bytes) -> bytes} from Wallet Standard
// wallets. Changes for the door: list(sol, { chain }) asks a Wallet Standard wallet for the quote's cluster
// (solana:mainnet or solana:devnet) instead of always preferring mainnet (audit INTEGRITY 7); the transaction
// crosses the wallet boundary as serialized bytes only (the Wallet Standard solana:signTransaction feature), so
// no SDK Transaction object is needed; the legacy window injections (window.solana etc.), which take an SDK
// Transaction object, are dropped, so a wallet without the Wallet Standard feature is not listed and the
// paste path below the button serves it.
//   await passwapWallets.list(sol, { chain }) -> [{ name, icon, connect(), publicKey, signTransaction(bytes) }]
// Wallet Standard wallets with a Solana chain (Phantom, Solflare, Backpack, Talisman, ...) are discovered on every
// call so late-loading extensions are found.
(function (root) {
  const standard = [];
  const register = (...ws) => { for (const w of ws) if (w && w.chains && w.chains.some((c) => String(c).startsWith("solana:")) && w.features && w.features["standard:connect"] && w.features["solana:signTransaction"] && !standard.includes(w)) standard.push(w); };
  try { window.addEventListener("wallet-standard:register-wallet", (e) => { try { e.detail(register); } catch {} }); } catch {}
  const rescan = () => { try { window.dispatchEvent(new CustomEvent("wallet-standard:app-ready", { detail: { register } })); } catch {} };
  rescan();

  function wrapStandard(w, sol, want) {
    let account = null, chain = null;
    const input = (bytes) => ({ transaction: bytes, account, chain });
    const feat = () => w.features["solana:signTransaction"];
    return {
      name: w.name, icon: w.icon, kind: "standard", isConnected: false, publicKey: null,
      async connect() {
        const r = await w.features["standard:connect"].connect();
        const accounts = (r && r.accounts && r.accounts.length ? r.accounts : w.accounts) || [];
        account = accounts.find((a) => a.chains && a.chains.some((c) => String(c).startsWith("solana:"))) || accounts[0];
        if (!account) throw new Error(w.name + " connected but exposed no Solana account");
        if (want && !(account.chains || []).includes(want)) throw new Error(w.name + "'s account is not on " + want + ", the cluster this quote is for");
        chain = want || (account.chains || []).find((c) => c === "solana:mainnet") || (account.chains || []).find((c) => String(c).startsWith("solana:")) || "solana:mainnet";
        this.publicKey = new sol.PublicKey(account.publicKey); this.isConnected = true;
        return { publicKey: this.publicKey };
      },
      async signTransaction(bytes) { const [out] = await feat().signTransaction(input(bytes)); return out.signedTransaction; },
    };
  }
  root.passwapWallets = {
    async list(sol, options) {
      const want = options && options.chain;
      rescan(); await new Promise((r) => setTimeout(r, 250)); rescan(); await new Promise((r) => setTimeout(r, 100));
      return standard.map((w) => wrapStandard(w, sol, want));
    },
    // what the page can see, for a "why isn't my wallet listed" report
    debug() { return { standard: standard.map((w) => w.name), globals: Object.keys(window).filter((k) => /sol|talisman|phantom|backpack|wallet/i.test(k)) }; },
  };
})(typeof self !== "undefined" ? self : this);

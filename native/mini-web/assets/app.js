/* Mini: the workspace. Without this file every page is one pane and every form works. With it,
   links open as panes on the stage (the server answers the stage region when asked with
   X-Mini-Fragment), forms submit in place, the set of open panes lives in the URL hash so a reload
   restores a workspace, and a Terminal pane is xterm.js over a WebSocket to a pty. No framework. */
(() => {
  "use strict";
  const stage = document.getElementById("stage");
  if (!stage) return;
  document.documentElement.classList.add("js"); // already set by the head script; idempotent
  const terminals = new Map(); // pane -> { term, ws, fit, closed }

  // ---------------------------------------------------------------- panes
  function paneFor(path) {
    for (const p of stage.querySelectorAll(".pane")) if (p.dataset.path === path) return p;
    return null;
  }

  // The head (with the title inside) is in the markup the server wrote; dressing adds the buttons
  // to it and nothing else, so the first frame and the dressed frame are the same size.
  function dress(pane) {
    let head = pane.querySelector(".pane-head");
    if (!head) {
      head = document.createElement("div");
      head.className = "pane-head";
      const title = pane.querySelector(".pane-title");
      if (title) head.appendChild(title);
      pane.insertBefore(head, pane.firstChild);
    }
    if (head.querySelector("button")) return;
    const mk = (label, name, fn) => {
      const b = document.createElement("button");
      b.type = "button"; b.title = name; b.setAttribute("aria-label", name); b.textContent = label;
      b.addEventListener("click", fn);
      head.appendChild(b);
    };
    mk("↻", "Reload", () => load(pane, pane.dataset.path));
    mk("⤢", "Maximize", () => pane.classList.toggle("max"));
    mk("×", "Close", () => close(pane));
  }

  function newPane(path) {
    const pane = document.createElement("section");
    pane.className = "pane";
    pane.dataset.path = path;
    pane.innerHTML = '<div class="pane-head"><h1 class="pane-title">…</h1></div><div class="pane-body"></div>';
    stage.appendChild(pane);
    dress(pane);
    return pane;
  }

  function close(pane) {
    const t = terminals.get(pane);
    if (t) { t.closed = true; try { t.ws && t.ws.close(); } catch (e) {} try { t.term.dispose(); } catch (e) {} terminals.delete(pane); }
    pane.remove();
    sync();
  }

  function setTitle(pane, title) {
    pane.dataset.title = title;
    const el = pane.querySelector(".pane-title");
    if (el) el.textContent = title;
    document.title = (stage.querySelector(".pane .pane-title") || {}).textContent || "Mini";
  }

  // The footer's "Report a problem" link follows the pane that last loaded (it is a plain link
  // to the derived feedback form, prefilled with the page; without this file it names the page
  // the document was served for).
  function reportLink(path) {
    const a = document.querySelector("footer .report");
    if (a) a.href = "/verb/feedback?page=" + encodeURIComponent(String(path).split("?")[0]);
  }

  async function load(pane, path, options) {
    options = options || {};
    if (!options.quiet) pane.classList.add("busy");
    try {
      const response = await fetch(path, {
        method: options.method || "GET",
        body: options.body,
        headers: Object.assign({ "X-Mini-Fragment": "1" }, options.headers || {}),
        credentials: "same-origin",
        redirect: "follow"
      });
      const html = await response.text();
      // A redirect lands the pane on the final URL (fetch followed it).
      const landed = new URL(response.url).pathname + new URL(response.url).search;
      pane.dataset.path = landed;
      pane.querySelector(".pane-body").innerHTML = html;
      setTitle(pane, response.headers.get("X-Mini-Title") || landed);
      wire(pane, !options.quiet);
      sync();
      fill(pane);
      reportLink(landed);
    } catch (e) {
      pane.querySelector(".pane-body").innerHTML = '<div class="outcome refused"><p class="headline">The page did not load</p><pre></pre></div>';
      pane.querySelector("pre").textContent = String(e);
    } finally {
      pane.classList.remove("busy");
    }
  }

  // Sections that fill in as their answers land (`data-load`: the grants page judges one grant
  // per request): loaded one after another, since the body answers one request at a time; each
  // keeps its no-JS link until its answer replaces it.
  async function fill(root) {
    for (const el of root.querySelectorAll("[data-load]:not([data-loaded])")) {
      el.dataset.loaded = "1";
      const slot = el.querySelector(".fill") || el;
      if (!sameOrigin(el.dataset.load)) continue;
      try {
        const response = await fetch(el.dataset.load, { headers: { "X-Mini-Fragment": "1" }, credentials: "same-origin" });
        slot.innerHTML = await response.text();
      } catch (e) {
        slot.insertAdjacentHTML("beforeend", '<p class="note">did not load: ' + String(e).replace(/[<&]/g, "") + "</p>");
      }
    }
  }
  fill(document);

  function open(path, from) {
    const existing = paneFor(path);
    if (existing) { existing.scrollIntoView({ block: "nearest" }); return existing; }
    const pane = newPane(path);
    load(pane, path);
    return pane;
  }

  function sameOrigin(href) {
    try { const u = new URL(href, location.href); return u.origin === location.origin ? u : null; } catch (e) { return null; }
  }

  // Links inside panes and the rail open panes; data-full links navigate.
  document.addEventListener("click", (event) => {
    const a = event.target.closest("a[href]");
    if (!a || a.hasAttribute("data-full") || a.target || event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
    // Document outline anchors are native navigation, including without JavaScript.
    if (a.getAttribute("href").startsWith("#")) return;
    const u = sameOrigin(a.getAttribute("href"));
    if (!u || u.pathname.startsWith("/assets/") || u.pathname.startsWith("/join")) return;
    event.preventDefault();
    const pane = a.closest(".pane");
    const path = u.pathname + u.search;
    if (pane && !a.closest(".rail") && a.closest(".pane-body") && !a.hasAttribute("data-pane")) load(pane, path);
    else open(path);
  });

  // Forms inside panes submit in place; data-full forms (log out, search) navigate.
  document.addEventListener("submit", (event) => {
    const form = event.target;
    const pane = form.closest(".pane");
    if (!pane || form.hasAttribute("data-full") || form.closest(".top")) return;
    event.preventDefault();
    const method = (form.getAttribute("method") || "get").toUpperCase();
    const u = sameOrigin(form.getAttribute("action") || pane.dataset.path);
    if (!u) return;
    const data = new FormData(form);
    if (event.submitter && event.submitter.name) data.append(event.submitter.name, event.submitter.value);
    const encoded = new URLSearchParams(data).toString();
    if (method === "GET") load(pane, u.pathname + (encoded ? "?" + encoded : ""));
    else load(pane, u.pathname + u.search, { method: "POST", body: encoded, headers: { "Content-Type": "application/x-www-form-urlencoded" } });
  });

  // ---------------------------------------------------------------- the hash: a workspace
  function sync() {
    const paths = [...stage.querySelectorAll(".pane")].map((p) => p.dataset.path).filter(Boolean);
    const hash = paths.length > 1 || (paths.length === 1 && paths[0] !== document.body.dataset.path) ? "#" + paths.map(encodeURIComponent).join("|") : "";
    if (location.hash !== hash) history.replaceState(null, "", location.pathname + location.search + hash);
    for (const a of document.querySelectorAll(".rail a")) a.classList.toggle("open", paths.some((p) => p === a.getAttribute("href") || p.startsWith(a.getAttribute("href") + "/")));
  }

  function restore() {
    if (!location.hash || location.hash.length < 2) return;
    for (const raw of location.hash.slice(1).split("|")) {
      // The hash is anyone's link: only a same-origin path opens a pane.
      let path = "";
      try {
        const decoded = decodeURIComponent(raw);
        // Native anchors (including the skip link) are not workspace paths.
        if (!decoded.startsWith("/") || decoded.startsWith("//")) continue;
        const u = sameOrigin(decoded); path = u ? u.pathname + u.search : "";
      } catch (e) {}
      if (path && !paneFor(path)) { const pane = newPane(path); load(pane, path); }
    }
  }

  // ---------------------------------------------------------------- terminals
  function assets(then) {
    if (window.Terminal && window.FitAddon) return then();
    const need = [["link", "/assets/vendor/xterm.css"], ["script", "/assets/vendor/xterm.js"], ["script", "/assets/vendor/addon-fit.js"]];
    let pending = 0;
    for (const [kind, href] of need) {
      if (document.querySelector(`${kind}[${kind === "link" ? "href" : "src"}="${href}"]`)) continue;
      pending++;
      const el = document.createElement(kind);
      if (kind === "link") { el.rel = "stylesheet"; el.href = href; } else { el.src = href; }
      el.addEventListener("load", () => { if (--pending === 0) then(); });
      document.head.appendChild(el);
    }
    if (pending === 0) then();
  }

  function boot(pane, host) {
    if (terminals.has(pane)) return;
    pane.classList.add("term-pane");
    const Terminal = window.Terminal;
    const FitAddon = window.FitAddon.FitAddon;
    const termBackground = getComputedStyle(host).getPropertyValue("--term-bg").trim();
    const term = new Terminal({
      fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace", fontSize: 13, cursorBlink: true, scrollback: 5000,
      theme: { background: termBackground }
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(host);
    const state = { term, fit, ws: null, closed: false, tries: 0 };
    terminals.set(pane, state);
    const encoder = new TextEncoder();
    // A text mirror of what the terminal wrote (the xterm canvas has no text
    // alternative): the last few KB, escape sequences stripped, readable on
    // demand — never live-announced, it would be noise.
    const mirror = document.createElement("pre");
    mirror.className = "term-mirror vh";
    mirror.setAttribute("aria-label", "Recent terminal output");
    mirror.tabIndex = 0;
    host.appendChild(mirror);
    const reflect = (u) => {
      const text = new TextDecoder().decode(u)
        .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "")
        .replace(/\x1b\][^\x07]*\x07/g, "")
        .replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
      if (!text) return;
      mirror.textContent = (mirror.textContent + text).slice(-4096);
    };
    const connect = () => {
      if (state.closed) return;
      const ws = new WebSocket((location.protocol === "https:" ? "wss://" : "ws://") + location.host + host.dataset.ws);
      ws.binaryType = "arraybuffer";
      state.ws = ws;
      ws.addEventListener("open", () => { state.tries = 0; fit.fit(); ws.send(JSON.stringify({ resize: [term.cols, term.rows] })); term.focus(); });
      ws.addEventListener("message", (e) => { const u = new Uint8Array(e.data); term.write(u); reflect(u); });
      ws.addEventListener("close", (e) => {
        state.ws = null;
        if (state.closed) return;
        if (e.reason === "exited" || e.code === 4000) { ended(pane, "the shell ended"); return; }
        if (e.code === 1008 || e.code === 4001) { ended(pane, "no session"); return; }
        if (state.tries++ < 20) setTimeout(connect, 1500); else ended(pane, "connection lost");
      });
    };
    term.onData((d) => { if (state.ws && state.ws.readyState === 1) state.ws.send(encoder.encode(d)); });
    term.onBinary((d) => { if (state.ws && state.ws.readyState === 1) state.ws.send(Uint8Array.from(d, (c) => c.charCodeAt(0))); });
    term.onResize(({ cols, rows }) => { if (state.ws && state.ws.readyState === 1) state.ws.send(JSON.stringify({ resize: [cols, rows] })); });
    new ResizeObserver(() => { try { fit.fit(); } catch (e) {} }).observe(host);
    connect();
  }

  function ended(pane, why) {
    const note = document.createElement("div");
    note.className = "term-ended";
    note.textContent = why + " — close this pane or open a new terminal from Terminal.";
    pane.querySelector(".pane-body").appendChild(note);
  }

  // A section with data-live="MS" (a room's stream) reloads its pane every MS while a form in it is not being typed into.
  function live(pane) {
    const section = pane.querySelector("[data-live]");
    if (pane.liveTimer) { clearInterval(pane.liveTimer); pane.liveTimer = null; }
    if (!section) return;
    const ms = Math.max(2000, parseInt(section.dataset.live, 10) || 5000);
    let refreshing = false;
    pane.liveTimer = setInterval(async () => {
      if (!document.body.contains(pane)) { clearInterval(pane.liveTimer); return; }
      const active = document.activeElement;
      const edited = [...pane.querySelectorAll("input,textarea,select")].some(el =>
        /^(checkbox|radio)$/.test(el.type) ? el.checked !== el.defaultChecked :
        el.tagName === "SELECT" ? el.selectedIndex !== Math.max(0, [...el.options].findIndex(o => o.defaultSelected)) :
        el.value !== el.defaultValue);
      if (edited || document.hidden || refreshing || (active && pane.contains(active) && /^(INPUT|TEXTAREA|SELECT|BUTTON)$/.test(active.tagName))) return;
      // The landing activity refreshes only its own read, never the welcome document or market.
      if (section.dataset.livePath && sameOrigin(section.dataset.livePath)) {
        refreshing = true;
        try {
          const response = await fetch(section.dataset.livePath, { headers: { "X-Mini-Fragment": "1" }, credentials: "same-origin" });
          if (!response.ok) return;
          const fragment = document.createElement("template");
          fragment.innerHTML = await response.text();
          const updated = fragment.content.querySelector(".ops");
          if (updated) section.replaceChildren(...updated.childNodes);
        } catch (_) { /* Keep the last observation; the room link still works. */ }
        finally { refreshing = false; }
      } else {
        refreshing = true;
        try { await load(pane, pane.dataset.path, { quiet: true }); }
        finally { refreshing = false; }
      }
    }, ms);
  }

  function wire(pane, focus = true) {
    const host = pane.querySelector(".term[data-ws]");
    if (host) assets(() => boot(pane, host));
    live(pane);
    // A grain's one-time bootstrap posts itself to the grain's own origin (a new tab: its cookie is its own).
    const auto = pane.querySelector("form[data-autosubmit]");
    if (auto && !auto.dataset.done) { auto.dataset.done = "1"; setTimeout(() => auto.submit(), 300); }
    const first = pane.querySelector(".pane-body input:not([type=hidden]), .pane-body textarea");
    if (focus && first && pane.dataset.focus !== "no") first.focus({ preventScroll: true });
  }

  // ---------------------------------------------------------------- start
  for (const pane of stage.querySelectorAll(".pane")) { dress(pane); wire(pane, false); }
  restore();
  sync();
  addEventListener("hashchange", restore);
})();

// The attempt rule, held to native/mini-sdk/src/custody.rs: no fresh-nonce successor after a Host
// refusal; an undecided answer keeps the attempt and names the exact lookup; `charged` is not success.
// Imports custody.ts alone (no wasm core), so it runs with `node --test test/custody-rule.test.ts`.
import { test } from "node:test";
import assert from "node:assert/strict";
import { Attempt, classify, outcomeOf } from "../src/custody.ts";

const enc = (s: string) => new TextEncoder().encode(s);
const receipt = { confirmation: "installed", transactionId: "1", eventId: "2", acceptedCount: "3", worldRoot: "4" };
const confirmed = { type: "confirmed", ...receipt };
const charged = { ...confirmed, disposition: "charged", cause: "exhausted" };
const sealed = () => { const a = Attempt.first("07".repeat(32), "10", "20"); a.prepared(); a.sealed(enc("call")); return a; };

test("a Host refusal is terminal and licenses no fresh-nonce successor", () => {
  const a = sealed();
  assert.equal(a.record(enc("call"), { kind: "answered", outcome: { type: "refused", reason: "staleRoot" } }).kind, "refused");
  assert.throws(() => a.successor("11", "21"), /no-effect/);
});

test("an undecided answer keeps the attempt and names the exact lookup of the same bytes", () => {
  for (const outcome of [{ type: "uncertain" }, { type: "unavailable" }, { type: "contention" }, { type: "absent" }, {}]) {
    const a = sealed();
    assert.equal(a.record(enc("call"), { kind: "answered", outcome }).kind, "uncertain");
    assert.throws(() => a.successor("11", "21"), /look it up \(same bytes\)/);
    assert.ok(a.call(), "the retained call stays the one this attempt may look up");
    assert.throws(() => a.record(enc("other"), { kind: "answered", outcome: confirmed }), /retained call bytes/);
  }
});

test("a charged failure is terminal and never a confirmation", () => {
  const o = outcomeOf(charged);
  assert.equal(o.kind, "charged");
  assert.equal(o.kind === "charged" && o.cause, "exhausted");
  const a = sealed();
  assert.equal(a.record(enc("call"), { kind: "answered", outcome: charged }).kind, "charged");
  assert.throws(() => a.successor("11", "21"), /charged/);
  assert.throws(() => a.record(enc("call"), { kind: "answered", outcome: confirmed }), /cannot transmit/);
  assert.equal(classify([charged])?.kind, "charged");
  assert.equal(outcomeOf({ ...confirmed, disposition: "partial" }).kind, "undecided");
  assert.equal(outcomeOf(confirmed).kind, "confirmed");
});

test("only a call that never reached the Host has a successor, with fresh nonces", () => {
  const a = sealed();
  a.record(enc("call"), { kind: "unsent", detail: "connect refused" });
  assert.throws(() => a.successor("10", "21"), /fresh nonces/);
  assert.equal(a.successor("11", "21").number, 2);
});

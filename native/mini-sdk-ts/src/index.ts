// @minidregg/sdk — the Mini client SDK in TypeScript, shape-for-shape and byte-for-byte with
// native/mini-sdk's offline core. CLIENT-LOCAL trust level: see native/mini-sdk/src/lib.rs.
//
//   Profile → Intent (typed cut) → explain() → Confirmation → sign → submit → Receipt | lookup
//
// It builds and signs; it never executes, proves, or re-derives a plan. It has NO transport: nothing
// here reaches a Host, a node, or the member's local Lean consent process (the plan check). The caller
// brings the Host-returned header bytes and carries the signed result wherever it goes.
export { SdkError, hex, unhex, sha256 } from "./bytes.ts";
export { call, core, installCore, type Core } from "./core.ts";
export { BREAD_PATH, derive, ed25519Signer, miniPath, Profile, PUBLIC_KEY_LEN, SCHEMES, SIGNATURE_LEN, signRaw, verify, type Key, type Scheme, type Signer } from "./profile.ts";
export { canonicalJson, intentBytes, intentIdPreimage, invocationId, lower, type Intent, type Json, type Lowering } from "./contracts.ts";
export { explain, type Bound, type Explanation } from "./explain.ts";
export { confirmDigest, headersDigest, Presented, signaturesJson, signTransaction, type Confirmation } from "./confirm.ts";
export { Attempt, classify, CONFIRMATIONS, outcomeOf, type Outcome, type Phase, type Receipt, type Transmission } from "./custody.ts";

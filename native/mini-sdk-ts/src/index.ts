// @minidregg/sdk — the Mini client SDK in TypeScript, shape-for-shape and byte-for-byte with
// native/mini-sdk's offline core. CLIENT-LOCAL trust level: see native/mini-sdk/src/lib.rs.
//
//   Profile → Intent (typed cut) → explain() → Confirmation → sign → submit → Receipt | lookup
//
// It builds and signs; it never executes, proves, or re-derives a plan. The plan check is the
// member's local Lean consent process; no bridge from a browser to that process exists, so a
// browser caller of this package has no plan check.
export { SdkError, hex, unhex, sha256 } from "./bytes.ts";
export { call, core, installCore, type Core } from "./core.ts";
export { BREAD_PATH, derive, ed25519Signer, miniPath, Profile, PUBLIC_KEY_LEN, SCHEMES, SIGNATURE_LEN, signRaw, verify, type Key, type Scheme, type Signer } from "./profile.ts";
export { canonicalJson, intentBytes, intentIdPreimage, invocationId, lower, type Intent, type Json, type Lowering } from "./contracts.ts";
export { explain, type Bound, type Explanation } from "./explain.ts";
export { confirmDigest, headersDigest, Presented, signaturesJson, signTransaction, type Confirmation } from "./confirm.ts";
export { Attempt, classify, CONFIRMATIONS, outcomeOf, type Outcome, type Phase, type Receipt, type Transmission } from "./custody.ts";

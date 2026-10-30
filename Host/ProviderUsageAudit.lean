/- Source-level regression facts for provider-metering admission data. The
general arithmetic proof is ProviderMetering.charge_rounding; these closed
inputs check the intended Chat Completions framing and refusal boundaries. -/
import Host.ProviderUsage

namespace Minidregg.Host.ProviderUsageAudit

open Minidregg.Host.ProviderUsage
open Minidregg.Kernel.ProviderMetering

set_option autoImplicit false

private def tariff : Tariff := ⟨1, "fixture", 4, ⟨2, 1000000, 2000000⟩, ⟨0, 1000000, 2000000⟩⟩
private def request : List UInt8 :=
  "{\"model\":\"fixture\",\"stream\":true}".toUTF8.toList
private def finished : String :=
  "data: {\"id\":\"a\",\"object\":\"chat.completion.chunk\",\"model\":\"fixture\",\"choices\":[{\"index\":0,\"finish_reason\":\"stop\"}]}"
private def metered : String :=
  "data: {\"id\":\"a\",\"object\":\"chat.completion.chunk\",\"model\":\"fixture\",\"choices\":[],\"usage\":{\"prompt_tokens\":1,\"completion_tokens\":2,\"total_tokens\":3}}"
private def complete : List UInt8 :=
  (": keepalive\r\n\r\n" ++ finished ++ "\r\n\r\n" ++ metered ++
    "\r\n\r\ndata: [DONE]\r\n\r\n").toUTF8.toList
private def truncated : List UInt8 :=
  (finished ++ "\n\n" ++ metered ++ "\n\ndata: [DONE]").toUTF8.toList
private def absent : List UInt8 :=
  (finished ++ "\n\ndata: [DONE]\n\n").toUTF8.toList

-- The provider may repeat its inert final choice on the sole usage event.
-- These synthetic counts and shape match the retained OpenRouter response.
private def echoChoice : String :=
  r#"{"index":0,"delta":{"content":"","role":"assistant"},"finish_reason":"stop","native_finish_reason":"stop"}"#
private def echoUsage : String :=
  r#", "usage":{"prompt_tokens":3042,"completion_tokens":38,"total_tokens":3080}"#
private def echoEvent (choice : String) (usage : String := "") : String :=
  r#"data: {"id":"a","object":"chat.completion.chunk","model":"fixture","choices":["# ++
    choice ++ "]" ++ usage ++ "}"
private def echoPrefix : String := echoEvent echoChoice ++ "\n\n"
private def doneFrame : String := "data: [DONE]\n\n"
private def echoStream (event : String) : String := echoPrefix ++ event ++ "\n\n" ++ doneFrame

/-- The basis, the detail and the amount of a quote, or the refusal. -/
private def classify (result : Result Quoted) : Except String (Basis × Option String × Nat) :=
  result.map (fun quoted => (quoted.quote.basis, quoted.detail, quoted.quote.amount))

private def checkTerminalEcho : IO Unit := do
  let terminal := echoEvent echoChoice echoUsage
  let positive := classify (quoteResponse tariff .pool .complete request
    (echoStream terminal).toUTF8.toList "text/event-stream" 200 3120)
  unless positive == .ok (.reported ⟨3042, 38, 3080⟩, none, 3120) do
    throw (IO.userError s!"inert terminal echo changed: {repr positive}")
  -- A complete 200 whose record the parser refuses is no longer a refusal of the
  -- settle: it is quoted at the hold, undecided, with the parser's reason as detail.
  let vectors : List (String × String × String) := [
    ("changed index", echoStream (terminal.replace r#""index":0"# r#""index":1"#),
      "SSE choice index is not zero"),
    ("changed reason", echoStream (terminal.replace r#""finish_reason":"stop""#
      r#""finish_reason":"length""#), "SSE terminal choice finish reason differs"),
    ("new text", echoStream (terminal.replace r#""content":"""# r#""content":"later""#),
      "SSE terminal choice delta is not inert"),
    ("tool delta", echoStream (terminal.replace r#""content":"""# r#""tool_calls":[]"#),
      "SSE terminal choice delta is not inert"),
    ("function delta", echoStream (terminal.replace r#""content":"""# r#""function_call":{}"#),
      "SSE terminal choice delta is not inert"),
    ("audio delta", echoStream (terminal.replace r#""content":"""# r#""audio":{}"#),
      "SSE terminal choice delta is not inert"),
    ("changed role", echoStream (terminal.replace r#""role":"assistant""# r#""role":"user""#),
      "SSE terminal choice delta is not inert"),
    ("extra choice output", echoStream (terminal.replace r#""index":0"# r#""index":0,"text":"later""#),
      "SSE terminal choice contains extra output"),
    ("changed model", echoStream (terminal.replace r#""model":"fixture""# r#""model":"other""#),
      "response model differs from the operator tariff"),
    ("changed generation", echoStream (terminal.replace r#""id":"a""# r#""id":"b""#),
      "SSE completion ids differ"),
    ("multiple indices", echoStream (echoEvent (echoChoice ++ "," ++ echoChoice) echoUsage),
      "SSE choices contain multiple indices"),
    ("duplicate usage", echoPrefix ++ terminal ++ "\n\n" ++ terminal ++ "\n\n" ++ doneFrame,
      "SSE data follows terminal usage"),
    ("data after done", echoStream terminal ++ terminal ++ "\n\n",
      "SSE data follows terminal usage"),
    ("absent terminator", echoPrefix ++ terminal ++ "\n\ndata: [DONE]",
      "SSE final data event lacks a blank-line terminator"),
    ("nonterminal usage", (echoEvent (echoChoice.replace r#""finish_reason":"stop""#
      r#""finish_reason":null"#) echoUsage) ++ "\n\n" ++ doneFrame,
      "usage precedes finish reason"),
    ("echo without usage", echoStream (echoEvent echoChoice), "missing usage")]
  for (label, response, expected) in vectors do
    let result := classify (quoteResponse tariff .pool .complete request response.toUTF8.toList
      "text/event-stream" 200 3120)
    unless result == .ok (.undecided .truncated, some expected, 3120) do
      throw (IO.userError s!"terminal echo {label} changed: {repr result}")

-- Z.AI's coding-plan Chat Completions stream, as measured on 2026-10-27
-- (`api.z.ai/api/coding/paas/v4`, glm-5.3-flash, max_tokens 8): reasoning
-- chunks whose choice carries no `finish_reason` key at all, and the usage
-- record on the finishing chunk itself, with token details beside the three
-- counts. An absent `finish_reason` before the finish reads as null.
private def zaiTariff : Tariff := ⟨1, "glm-5.3-flash", 4, ⟨2, 1000000, 2000000⟩, ⟨0, 1000000, 2000000⟩⟩
private def zaiRequest : List UInt8 :=
  "{\"model\":\"glm-5.3-flash\",\"stream\":true}".toUTF8.toList
private def zaiStream : String :=
  r#"data: {"id":"z","created":1,"object":"chat.completion.chunk","model":"glm-5.3-flash","choices":[{"index":0,"delta":{"role":"assistant","reasoning_content":"Let"}}]}"# ++ "\n\n" ++
  r#"data: {"id":"z","created":1,"object":"chat.completion.chunk","model":"glm-5.3-flash","choices":[{"index":0,"finish_reason":"length","delta":{"role":"assistant","content":""}}],"usage":{"prompt_tokens":14,"completion_tokens":8,"total_tokens":22,"prompt_tokens_details":{"cached_tokens":0},"completion_tokens_details":{"reasoning_tokens":5}}}"# ++ "\n\n" ++
  doneFrame

private def checkZaiStream : IO Unit := do
  let result := classify (quoteResponse zaiTariff .pool .complete zaiRequest zaiStream.toUTF8.toList
    "text/event-stream" 200 500)
  -- Pool fee 2 + ⌈(14·10⁶ + 8·2·10⁶)/10⁶⌉ = 32.
  unless result == .ok (.reported ⟨14, 8, 22⟩, none, 32) do
    throw (IO.userError s!"Z.AI coding-plan stream changed: {repr result}")
  -- Data after the terminal usage is still refused.
  let echoed := zaiStream.replace doneFrame
    (r#"data: {"id":"z","created":1,"object":"chat.completion.chunk","model":"glm-5.3-flash","choices":[{"index":0,"delta":{"content":""}}]}"# ++ "\n\n" ++ doneFrame)
  let refused := classify (quoteResponse zaiTariff .pool .complete zaiRequest echoed.toUTF8.toList
    "text/event-stream" 200 500)
  unless refused == .ok (.undecided .truncated, some "SSE data follows terminal usage", 500) do
    throw (IO.userError s!"Z.AI data after usage changed: {repr refused}")

/-- Executable parser regression gate. Its closed examples do not replace the
general theorems in `Kernel.ProviderMetering` (`failed_leg_settle_decided`). It raises
an error during this module's narrow Lean check if any framing or classification
result changes. -/
def check : IO Unit := do
  checkTerminalEcho
  checkZaiStream
  let positive := classify (quoteResponse tariff .pool .complete request complete
    "text/event-stream; charset=UTF-8" 200 7)
  unless positive == .ok (.reported ⟨1, 2, 3⟩, none, 7) do
    throw (IO.userError s!"complete stream changed: {repr positive}")
  -- A truncated 200 and a 200 without a usage record are quoted at the hold, undecided.
  let truncatedResult := classify (quoteResponse tariff .pool .complete request truncated
    "text/event-stream" 200 5)
  unless truncatedResult == .ok (.undecided .truncated,
      some "SSE final data event lacks a blank-line terminator", 5) do
    throw (IO.userError s!"truncated stream changed: {repr truncatedResult}")
  let absentResult := classify (quoteResponse tariff .pool .complete request absent
    "text/event-stream" 200 5)
  unless absentResult == .ok (.undecided .truncated,
      some "SSE completion lacks one terminal usage record", 5) do
    throw (IO.userError s!"missing usage changed: {repr absentResult}")
  -- Reported usage above the hold is still the one refusal (impossible for a lawful reserve).
  let overResult := classify (quoteResponse tariff .pool .complete request complete
    "text/event-stream" 200 6)
  unless overResult == .error "reported usage quote exceeds the held allowance or tariff bound" do
    throw (IO.userError s!"over-reserve changed: {repr overResult}")
  -- The four failure classes on the pool route (fee 2): a refused reply is the fee;
  -- timeout, truncated and lost are the hold.
  let refused := classify (quoteResponse tariff .pool .complete request
    "{\"error\":\"rate limited\"}".toUTF8.toList "application/json" 429 500)
  unless refused == .ok (.refusedReply 429, none, 2) do
    throw (IO.userError s!"429 settle changed: {repr refused}")
  for (leg, label) in [(Leg.timeout, "timeout"), (Leg.truncated, "truncated"), (Leg.lost, "lost")] do
    let result := classify (quoteResponse tariff .pool leg request [] "" 0 500)
    unless result == .ok (.undecided leg, none, 500) do
      throw (IO.userError s!"{label} settle changed: {repr result}")
  -- A homelab refused reply at a zero fee settles at zero (the law admits a zero charge).
  let homelab := classify (quoteResponse tariff .homelab .complete request [] "text/plain" 503 9)
  unless homelab == .ok (.refusedReply 503, none, 0) do
    throw (IO.userError s!"homelab 503 settle changed: {repr homelab}")
  -- The user route charges the fee alone, reads no usage, and refuses a hold
  -- below the fee.
  let user := classify (quoteResponse tariff .user .complete request absent "text/plain" 429 4)
  unless user == .ok (.perOperation, none, 4) do
    throw (IO.userError s!"user fee changed: {repr user}")
  let userLost := classify (quoteResponse tariff .user .lost request [] "" 0 4)
  unless userLost == .ok (.perOperation, none, 4) do
    throw (IO.userError s!"user lost-leg fee changed: {repr userLost}")
  let userOver := classify (quoteResponse tariff .user .complete request complete
    "text/event-stream" 200 3)
  unless userOver == .error "reported usage quote exceeds the held allowance or tariff bound" do
    throw (IO.userError s!"user over-reserve changed: {repr userOver}")

#eval check

end Minidregg.Host.ProviderUsageAudit

/-
Strict source-owned presentation of provider-reported usage from the exact
retained Chat Completions request and response. A valid report is a configured
tariff quote over provider-asserted counts, not an invoice attestation or Mini
admission verdict. Missing or ambiguous usage refuses construction.
-/
import Host.Json
import Kernel.ProviderMetering

namespace Minidregg.Host.ProviderUsage

open Lean
open Minidregg.Kernel
open Minidregg.Kernel.ProviderMetering

set_option autoImplicit false

abbrev Result := Except String

private def field (json : Json) (name : String) : Result Json :=
  (json.getObjVal? name).mapError (fun _ => s!"missing {name}")

private def stringField (json : Json) (name : String) : Result String := do
  (← field json name).getStr?.mapError (fun _ => s!"{name} must be a string")

private def canonicalNat (json : Json) (name : String) : Result Nat := do
  let value ← stringField json name
  if value.length > 20 then throw s!"{name} exceeds decimal width"
  match value.toNat? with
  | some n =>
      if toString n = value then pure n
      else .error s!"{name} must be canonical decimal"
  | none => .error s!"{name} must be canonical decimal"

private def exactKeys (json : Json) (label : String) (expected : List String) : Result Unit := do
  let obj ← json.getObj?.mapError (fun _ => s!"{label} must be an object")
  let actual := obj.foldl (init := []) (fun names key _ => key :: names)
  unless actual.length = expected.length && actual.all expected.contains do
    throw s!"{label} fields differ from the per-route v2 schema"

private def parseRate (json : Json) (label : String) : Result Rate := do
  exactKeys json label ["perOp", "inputMicroPerMillion", "outputMicroPerMillion"]
  pure { perOp := ← canonicalNat json "perOp"
         inputMicroPerMillion := ← canonicalNat json "inputMicroPerMillion"
         outputMicroPerMillion := ← canonicalNat json "outputMicroPerMillion" }

/-- The tariff is fixed operator configuration, per route (schema v2):
`{version, model, routes: {user: {perOp}, pool: {perOp, inputMicroPerMillion,
outputMicroPerMillion}, homelab: {…same as pool…}}}`. The four-field v1 shape
(one rate pair per task, no routes) refuses to load. Only source-owned
canonical decimal parsing can turn it into arithmetic. -/
def parseTariff (source : String) : Result Tariff := do
  let json ← Minidregg.Host.Json.parse source
  exactKeys json "tariff" ["version", "model", "routes"]
  let routes ← field json "routes"
  exactKeys routes "tariff.routes" ["user", "pool", "homelab"]
  let user ← field routes "user"
  exactKeys user "tariff.routes.user" ["perOp"]
  let tariff : Tariff := {
    version := ← canonicalNat json "version"
    model := ← stringField json "model"
    userPerOp := ← canonicalNat user "perOp"
    pool := ← parseRate (← field routes "pool") "tariff.routes.pool"
    homelab := ← parseRate (← field routes "homelab") "tariff.routes.homelab" }
  unless decide tariff.valid do
    throw "tariff version, model, fee or rate exceeds the v2 bound"
  pure tariff

/-- The tariff as the Host profile publishes it. -/
def tariffJson (tariff : Tariff) : Json :=
  let n := fun value : Nat => toJson (toString value)
  let rate := fun (r : Rate) => Json.mkObj [("perOp", n r.perOp),
    ("inputMicroPerMillion", n r.inputMicroPerMillion),
    ("outputMicroPerMillion", n r.outputMicroPerMillion)]
  Json.mkObj [("version", n tariff.version), ("model", toJson tariff.model),
    ("routes", Json.mkObj [("user", Json.mkObj [("perOp", n tariff.userPerOp)]),
      ("pool", rate tariff.pool), ("homelab", rate tariff.homelab)])]

private def usageOfJson (json : Json) : Result Usage := do
  let usage : Usage := {
    promptTokens := ← (← field json "prompt_tokens").getNat?.mapError
      (fun _ => "prompt_tokens must be an unsigned JSON integer")
    completionTokens := ← (← field json "completion_tokens").getNat?.mapError
      (fun _ => "completion_tokens must be an unsigned JSON integer")
    totalTokens := ← (← field json "total_tokens").getNat?.mapError
      (fun _ => "total_tokens must be an unsigned JSON integer") }
  unless usage.totalTokens == usage.promptTokens + usage.completionTokens &&
      usage.promptTokens ≤ maxReportedTokens &&
      usage.completionTokens ≤ maxReportedTokens do
    throw "reported usage is inconsistent or exceeds the token bound"
  pure usage

private def textOfBytes (label : String) (bytes : List UInt8) (limit : Nat) : Result String := do
  if bytes.length > limit then throw s!"{label} exceeds byte bound"
  match String.fromUTF8? bytes.toByteArray with
  | some value => pure value
  | none => throw s!"{label} is not UTF-8"

private def parseRequest (tariff : Tariff) (bytes : List UInt8) : Result Bool := do
  let text ← textOfBytes "request" bytes 1048576
  let json ← Minidregg.Host.Json.parse text
  unless (← stringField json "model") = tariff.model do
    throw "request model differs from the operator tariff"
  let streaming ← match json.getObjVal? "stream" with
    | .ok value => value.getBool?.mapError (fun _ => "stream must be boolean")
    | .error _ => pure false
  match json.getObjVal? "n" with
  | .ok count =>
      unless count.getNat?.toOption == some 1 do
        throw "only one Chat Completion choice is metered"
  | .error _ => pure ()
  pure streaming

private def checkModel (tariff : Tariff) (json : Json) : Result Unit := do
  unless (← stringField json "model") = tariff.model do
    throw "response model differs from the operator tariff"

private def parseJsonResponse (tariff : Tariff) (text : String) : Result Usage := do
  let json ← Minidregg.Host.Json.parse text
  checkModel tariff json
  unless (← stringField json "object") = "chat.completion" do
    throw "response is not a Chat Completion"
  if (← stringField json "id").isEmpty then
    throw "response completion id is empty"
  let choices ← (← field json "choices").getArr?.mapError
    (fun _ => "choices must be an array")
  unless choices.size = 1 do throw "exactly one Chat Completion choice required"
  let choice := choices[0]!
  unless (← field choice "index").getNat?.toOption == some 0 do
    throw "choice index is not zero"
  let finish ← stringField choice "finish_reason"
  if finish.isEmpty then throw "completion finish reason is empty"
  usageOfJson (← field json "usage")

private def fieldValue (line : String) : String × String :=
  let parts := line.splitOn ":"
  let name := parts.head!
  let value := String.intercalate ":" parts.tail
  let value := if value.startsWith " " then String.ofList (value.toList.drop 1) else value
  (name, value)

/-- WHATWG SSE allows comment-only keepalives and multiple data lines per
event. The exact original bytes remain in Quote; framing normalization only
selects the JSON payload. -/
private def dataPayload (frame : String) : Result (Option String) := do
  let mut data : List String := []
  for line in frame.splitOn "\n" do
    if line.isEmpty || line.startsWith ":" then continue
    let (name, value) := fieldValue line
    if name = "data" then
      data := value :: data
    else if name = "event" then
      if value = "error" then throw "SSE error event"
    else if name = "id" then
      if value.contains (Char.ofNat 0) then throw "SSE id contains NUL"
    else if name = "retry" then
      pure ()
    else
      pure ()
  if data.isEmpty then pure none
  else pure (some (String.intercalate "\n" data.reverse))

private def mediaType (source : String) : Result String := do
  let parts := source.toLower.splitOn ";"
  match parts with
  | [base] => pure base.trimAscii.toString
  | [base, parameter] =>
      unless parameter.trimAscii.toString = "charset=utf-8" do
        throw "unsupported Content-Type parameter"
      pure base.trimAscii.toString
  | _ => throw "ambiguous Content-Type parameters"

/-- A post-finish choice can only repeat the finish marker, not produce more
output. Only empty content and the assistant role are inert delta fields. -/
private def checkTerminalEcho (choice : Json) (finishedReason : String) : Result Unit := do
  let obj ← choice.getObj?.mapError (fun _ => "SSE terminal choice must be an object")
  let keys := obj.foldl (init := []) (fun names key _ => key :: names)
  unless keys.all (["index", "finish_reason", "native_finish_reason", "delta"].contains) do
    throw "SSE terminal choice contains extra output"
  unless (← stringField choice "finish_reason") = finishedReason do
    throw "SSE terminal choice finish reason differs"
  let delta ← (← field choice "delta").getObj?.mapError
    (fun _ => "SSE terminal choice delta must be an object")
  let inert := delta.foldl (init := true) fun accepted key value =>
    accepted && ((key == "content" && value == toJson "") ||
      (key == "role" && value == toJson "assistant"))
  unless inert do throw "SSE terminal choice delta is not inert"

/-- Accept a complete stream with exactly one terminal usage event, after a
finish reason and immediately before [DONE]. That event may echo the same
choice's finish reason with an inert delta. No usage is inferred from deltas. -/
private def parseSseResponse (tariff : Tariff) (text : String) : Result Usage := do
  let normalized := (text.replace "\r\n" "\n").replace "\r" "\n"
  let normalized := if normalized.startsWith (String.ofList [Char.ofNat 65279]) then
      String.ofList (normalized.toList.drop 1) else normalized
  let segments := normalized.splitOn "\n\n"
  let suffix := segments[segments.length - 1]!
  if !(← dataPayload suffix).isNone then
    throw "SSE final data event lacks a blank-line terminator"
  let frames := (segments.take (segments.length - 1)).filter (· != "")
  if frames.isEmpty || frames.length > 4096 then
    throw "SSE frame count outside bound"
  let mut finished : Option String := none
  let mut done := false
  let mut usage : Option Usage := none
  let mut completionId : Option String := none
  for frame in frames do
    let some payload ← dataPayload frame | continue
    if payload = "[DONE]" then
      if done || finished.isNone || usage.isNone then
        throw "SSE completion lacks one terminal usage record"
      done := true
    else
      if done || usage.isSome then throw "SSE data follows terminal usage"
      let event ← Minidregg.Host.Json.parse payload
      checkModel tariff event
      unless (← stringField event "object") = "chat.completion.chunk" do
        throw "SSE event is not a Chat Completion chunk"
      let eventId ← stringField event "id"
      if eventId.isEmpty || completionId.isSome && completionId != some eventId then
        throw "SSE completion ids differ"
      completionId := some eventId
      let choices ← (← field event "choices").getArr?.mapError
        (fun _ => "SSE choices must be an array")
      if choices.isEmpty then
        unless finished.isSome do throw "usage precedes finish reason"
        usage := some (← usageOfJson (← field event "usage"))
      else
        if choices.size != 1 then
          throw "SSE choices contain multiple indices"
        let choice := choices[0]!
        unless (← field choice "index").getNat?.toOption == some 0 do
          throw "SSE choice index is not zero"
        match finished with
        | some reason =>
            checkTerminalEcho choice reason
            -- A repeated finish is allowed only on the unique usage event;
            -- the next data event must be [DONE], as enforced above.
            usage := some (← usageOfJson (← field event "usage"))
        | none =>
            -- Before the finish, an absent finish_reason reads as null
            -- (Z.AI's coding-plan stream omits the key on its delta chunks).
            let reason := (choice.getObjVal? "finish_reason").toOption.getD .null
            if reason != .null then
              let name ← reason.getStr?.mapError (fun _ => "finish_reason must be a string")
              if name.isEmpty then throw "empty finish_reason"
              finished := some name
            match event.getObjVal? "usage" with
            | .ok value =>
                if value != .null then
                  unless finished.isSome do throw "usage precedes finish reason"
                  usage := some (← usageOfJson value)
            | .error _ => pure ()
  unless done do throw "SSE [DONE] marker absent"
  match usage with
  | some observed => pure observed
  | none => throw "SSE terminal usage absent"

/-- The one terminal usage record of a complete 200 reply, read from the retained
bytes under the request's framing. Every refusal here is a fact about the reply's
shape; on a metered route it is NOT a refusal of the settle (below) but the reason
the settle is quoted at the hold. -/
def readUsage (tariff : Tariff) (streaming : Bool) (response : List UInt8)
    (contentType : String) : Result Usage := do
  let text ← textOfBytes "response" response 8388608
  let contentType ← mediaType contentType
  if streaming then
    if contentType != "text/event-stream" then
      throw "stream response content type differs"
    parseSseResponse tariff text
  else
    if contentType != "application/json" then
      throw "JSON response content type differs"
    parseJsonResponse tariff text

/-- A quote with the reason its basis is not reported usage, when there is one. -/
structure Quoted where
  quote : Quote
  leg : Leg
  status : Nat
  detail : Option String

/-- The basis of a metered call's quote, by leg and reply (`Kernel.ProviderMetering.Basis`):
reported usage on a complete 200 whose record reads; a refused reply on any other
complete status; otherwise the undecided leg, with the parser's reason when a complete
200 could not be read. Total: no leg is left without a basis. -/
def meteredBasis (tariff : Tariff) (streaming : Bool) (leg : Leg) (response : List UInt8)
    (contentType : String) (status : Nat) : Basis × Option String :=
  match leg with
  | .complete =>
      if status = 200 then
        match readUsage tariff streaming response contentType with
        | .ok usage => (.reported usage, none)
        | .error reason => (.undecided .truncated, some reason)
      else (.refusedReply status, none)
  | leg => (.undecided leg, none)

/-- This function consumes retained exact bytes, not worker-supplied counts.
A user-route call is quoted its per-operation fee whatever the reply: the friend's
own key paid the provider, so no count is read. A metered route is quoted by the leg
and the reply (`meteredBasis`): the tariff charge on reported usage, the route fee on
a refused reply, the hold on an undecided leg
(`ProviderMetering.failed_leg_settle_decided`). The only refusals left are the
controller's own request bytes failing the tariff's framing and a quote above the hold
(impossible for a lawful reserve). The caller must separately pin the quote's reserve
to the signed provider hold and submit the generated operation through ordinary Mini
admission, where the purse's route law checks the charge against the route recorded
at reserve. -/
def quoteResponse (tariff : Tariff) (route : Route) (leg : Leg) (request response : List UInt8)
    (contentType : String) (status reserve : Nat) : Result Quoted := do
  let streaming ← parseRequest tariff request
  let (basis, detail) : Basis × Option String := if route = .user then (.perOperation, none)
    else meteredBasis tariff streaming leg response contentType status
  match prepare tariff route basis request response reserve with
  | some quote => pure ⟨quote, leg, status, detail⟩
  | none => throw "reported usage quote exceeds the held allowance or tariff bound"

/-- Bounded typed projection. The request/response files remain the exact
evidence; digest equality is a collision-resistance assumption, not a proof of
provider truth. -/
def reportJson (providerResourceId : Nat) (quoted : Quoted) : Json :=
  let quote := quoted.quote
  let usageFields := match quote.usage with
    | none => []
    | some usage => [
        ("promptTokens", toJson (toString usage.promptTokens)),
        ("completionTokens", toJson (toString usage.completionTokens)),
        ("totalTokens", toJson (toString usage.totalTokens))]
  let detailFields := match quoted.detail with
    | none => []
    | some reason => [("detail", toJson reason)]
  .mkObj ([
    ("type", toJson "minidregg-provider-metering-v2"),
    ("status", toJson (match quote.basis with
      | .perOperation => "quoted-per-operation"
      | .reported _ => "quoted-reported-usage"
      | .refusedReply _ => "quoted-refused-reply"
      | .undecided _ => "quoted-undecided-at-hold")),
    ("basis", toJson quote.basis.name),
    ("leg", toJson quoted.leg.name),
    ("httpStatus", toJson (toString quoted.status)),
    ("providerResourceId", toJson (toString providerResourceId)),
    ("route", toJson quote.route.name),
    ("model", toJson quote.tariff.model),
    ("tariffVersion", toJson (toString quote.tariff.version)),
    ("tariffDigest", toJson (toString (tariffDigest quote.tariff).value)),
    ("requestDigest", toJson (toString (requestDigest quote.request).value)),
    ("responseDigest", toJson (toString (responseDigest quote.response).value)),
    ("requestBytes", toJson (toString quote.request.length)),
    ("responseBytes", toJson (toString quote.response.length))] ++ usageFields ++ [
    ("perOp", toJson (toString (quote.tariff.perOp quote.route))),
    ("reserve", toJson (toString quote.reserve)),
    ("charge", toJson (toString quote.amount)),
    ("operation", .mkObj [("type", toJson "settle"),
      ("charge", toJson (toString quote.amount)), ("route", toJson quote.route.name)]),
    ("claim", toJson (match quote.basis with
      | .perOperation => "per-operation fee under operator tariff; the provider bill is the key owner's"
      | .reported _ => "provider-reported usage under operator tariff; not invoice-verified"
      | .refusedReply _ => "complete non-200 reply: the route's declared per-operation fee; the provider bills nothing for a refused call"
      | .undecided _ => "no usage record could be read for this leg: the whole hold, the maximum the provider may have billed"))]
    ++ detailFields)

private def splitPairBounded (payload : List UInt8) (maximum : Nat) :
    Result (List UInt8 × List UInt8) := do
  if payload.length < 4 then throw "short provider metering pair"
  let width := payload[0]!.toNat + 256 * payload[1]!.toNat +
    65536 * payload[2]!.toNat + 16777216 * payload[3]!.toNat
  if width = 0 || width > maximum || width > payload.length - 4 then
    throw "provider metering pair exceeds bound"
  pure ((payload.drop 4).take width, payload.drop (4 + width))

/-- Read-only socket op payload: u32LE metadata length, strict metadata JSON,
u32LE exact request length, exact request bytes, then exact response bytes.
Metadata (v3) is {version "3", providerResourceId, route, status, contentType,
reserve}, decimal strings for integers; the route is the one the purse
recorded at reserve. The Host Settings supply the tariff for a configured
providerResourceId; neither comes from the request. No provider key or Mini
signer enters this operation. -/
def quotePayload (services : List (Nat × Tariff))
    (payload : List UInt8) : Result Json := do
  let (metadataBytes, remainder) ← splitPairBounded payload 4096
  let (request, response) ← splitPairBounded remainder 1048576
  if response.length > 8388608 then
    throw "provider metering response exceeds byte bound"
  let metadataText ← textOfBytes "metadata" metadataBytes 4096
  let metadata ← Minidregg.Host.Json.parse metadataText
  let obj ← metadata.getObj?.mapError (fun _ => "metadata must be an object")
  let expected := ["version", "providerResourceId", "route", "leg", "status", "contentType", "reserve"]
  let actual := obj.foldl (init := []) (fun names key _ => key :: names)
  unless actual.length = expected.length && actual.all expected.contains do
    throw "provider metering metadata differs from the v4 schema"
  unless (← stringField metadata "version") == "4" do
    throw "provider metering metadata version differs"
  let some leg := Leg.ofName? (← stringField metadata "leg")
    | throw "provider metering leg must be complete, timeout, truncated or lost"
  let providerResourceId ← canonicalNat metadata "providerResourceId"
  let some (_, tariff) := services.find? (fun service => service.1 == providerResourceId)
    | throw "provider metering selector is not configured"
  let some route := Route.ofName? (← stringField metadata "route")
    | throw "provider metering route must be user, pool or homelab"
  let status ← canonicalNat metadata "status"
  let contentType ← stringField metadata "contentType"
  let reserve ← canonicalNat metadata "reserve"
  -- A leg without a complete reply carries no status and no content type, and may
  -- carry no response bytes at all (or the partial bytes the gateway retained).
  if leg != .complete then
    unless status = 0 && contentType.isEmpty do
      throw "a non-complete provider leg carries no HTTP status or content type"
  let quoted ← quoteResponse tariff route leg request response contentType status reserve
  pure (reportJson providerResourceId quoted)

/-- One pinned provider service as the deployment config spells it
(`providerServices[]`): the purse resource and its per-route tariff. The
serving Host and the local consent provider parse it with `checkedServices`,
so the two can never read different pins from one file. -/
structure ServiceSettings where
  providerResourceId : Nat
  tariff : Json
  deriving FromJson, ToJson

/-- Bounded unique service table: one to eight entries, positive distinct
resource ids, each tariff the per-route v2 schema. -/
def checkedServices (services : List ServiceSettings) : Result (List (Nat × Tariff)) := do
  unless 0 < services.length && services.length ≤ 8 do
    throw "providerServices requires one to eight entries"
  let ids := services.map (·.providerResourceId)
  unless ids.all (fun id => decide (0 < id)) && decide ids.Nodup do
    throw "providerServices resource IDs must be positive and unique"
  services.mapM fun service => do
    let tariff ← parseTariff service.tariff.compress
    pure (service.providerResourceId, tariff)

end Minidregg.Host.ProviderUsage

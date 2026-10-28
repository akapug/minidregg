/-
# Compiler.TypedAuthorizationRequestCodec — one complete canonical request codec

All request consumers use the source-owned RequestWire projection, including
resource kind and explicit policy revision. Typed and existential codecs share
this one representation. Every stream decoder is canonical by construction
(the natural codec refuses leading zeros and the word, kind and verb decoders
are partial inverses), so no prefix is re-encoded; kind mismatch and omitted
revision are refused, never defaulted.
-/
module

public import Compiler.Tower256ConcreteBackend
public import Theory.AuthorizationDeclaration

-- Bodies this file reduces or derives through, not exposed by their modules (module system).
import all Init.Data.Repr
import all Init.Data.ToString.Basic
import all Init.Data.ToString.Extra
import all Init.Data.Array.Basic
import all Init.Data.ByteArray.Basic
import all Init.Data.String.Decode
import all Init.Data.String.Defs
import all Init.Control.Except
import all Init.Data.List.Basic
import all Init.Data.Nat.Bitwise.Basic
import all Init.Data.String.Bootstrap
import all Init.Data.Format.Basic
import all Init.Data.List.Scan.Basic

@[expose] public section

namespace Minidregg.Compiler.TypedAuthorizationRequestCodec

open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.AuthorizationDeclaration

set_option autoImplicit false

/-! ## Wrapper fields -/

def subjectIdStream : StreamCodec SubjectId :=
  StreamCodec.xmap StreamCodec.nat SubjectId.value SubjectId.mk
    (by intro value; cases value; rfl)

def policyIdStream : StreamCodec PolicyId :=
  StreamCodec.xmap StreamCodec.nat PolicyId.value PolicyId.mk
    (by intro value; cases value; rfl)

def federationIdStream : StreamCodec FederationId :=
  StreamCodec.xmap StreamCodec.nat FederationId.value FederationId.mk
    (by intro value; cases value; rfl)

def resourceIdStream (kind : ResourceKind) : StreamCodec (ResourceId kind) :=
  StreamCodec.xmap StreamCodec.nat ResourceId.value ResourceId.mk
    (by intro value; cases value; rfl)

/-- Pure wire projection is source-owned so lower backend manifests cannot
create an import cycle through this concrete byte codec. -/
abbrev requestWords := Minidregg.Theory.AuthorizationDeclaration.requestWords
abbrev requestWordCount := Minidregg.Theory.AuthorizationDeclaration.requestWordCount
abbrev requestWireOfWords := Minidregg.Theory.AuthorizationDeclaration.requestWireOfWords
abbrev requestWireOfWords_requestWords :=
  Minidregg.Theory.AuthorizationDeclaration.requestWireOfWords_requestWords
abbrev requestWireOfWords_exact :=
  @Minidregg.Theory.AuthorizationDeclaration.requestWireOfWords_exact
abbrev requestWords_injective :=
  Minidregg.Theory.AuthorizationDeclaration.requestWords_injective

/-! ## The request words are a canonical spelling

`decodeResourceKind`, `decodeVerb` and `decodeRequest` are partial inverses of
their encoders: whatever they accept is the tag of what they return. The
stream codecs below are therefore canonical by construction, with no
re-encode of the consumed prefix. -/

theorem resourceKindTag_of_decode {tag : Nat} {kind : ResourceKind}
    (decoded : decodeResourceKind tag = some kind) : resourceKindTag kind = tag := by
  unfold decodeResourceKind at decoded
  split at decoded <;> first | cases decoded; rfl | cases decoded

theorem verbTag_of_decode {kind : ResourceKind} {tag : Nat} {verb : Verb kind}
    (decoded : decodeVerb kind tag = some verb) : verbTag verb = tag := by
  unfold decodeVerb at decoded
  split at decoded <;> first | cases decoded; rfl | cases decoded

theorem encodeRequest_of_decode {wire : RequestWire} {request : SomeRequest}
    (decoded : decodeRequest wire = some request) : encodeRequest request = wire := by
  cases kindOk : decodeResourceKind wire.resourceKind with
  | none => simp [decodeRequest, kindOk] at decoded
  | some kind =>
    cases verbOk : decodeVerb kind wire.verb with
    | none => simp [decodeRequest, kindOk, verbOk] at decoded
    | some verb =>
      simp only [decodeRequest, kindOk, verbOk, bind, Option.bind, Option.some.injEq] at decoded
      subst decoded
      cases wire
      simp only [encodeRequest, resourceKindTag_of_decode kindOk, verbTag_of_decode verbOk]

def requestWireStream : StreamCodec RequestWire where
  encode request := (StreamCodec.list StreamCodec.nat).encode (requestWords request)
  decodePrefix bytes := do
    let (count, afterCount) ← StreamCodec.nat.decodePrefix bytes
    if count = requestWordCount then
      let (words, suffix) ← StreamCodec.decodeMany StreamCodec.nat count afterCount
      let request ← requestWireOfWords words
      some (request, suffix)
    else none
  decodePrefix_encode := by
    intro request suffix
    simp [StreamCodec.list, List.append_assoc,
      StreamCodec.nat.decodePrefix_encode, requestWords, requestWordCount,
      requestFieldOrder, StreamCodec.encodeMany, StreamCodec.decodeMany,
      requestWireOfWords, Minidregg.Theory.AuthorizationDeclaration.requestWords,
      Minidregg.Theory.AuthorizationDeclaration.requestWordCount,
      Minidregg.Theory.AuthorizationDeclaration.requestWireOfWords]
  encode_decodePrefix := by
    intro bytes request suffix decoded
    cases countOk : StreamCodec.nat.decodePrefix bytes with
    | none => simp [countOk] at decoded
    | some countPair =>
      obtain ⟨count, afterCount⟩ := countPair
      by_cases exact : count = requestWordCount
      · subst exact
        cases wordsOk : StreamCodec.decodeMany StreamCodec.nat requestWordCount afterCount with
        | none => simp [countOk, wordsOk] at decoded
        | some wordsPair =>
          obtain ⟨words, rest⟩ := wordsPair
          cases wireOk : requestWireOfWords words with
          | none => simp [countOk, wordsOk, wireOk] at decoded
          | some wire =>
            simp only [countOk, wordsOk, wireOk, bind, Option.bind, if_true,
              Option.some.injEq, Prod.mk.injEq] at decoded
            obtain ⟨rfl, rfl⟩ := decoded
            obtain ⟨length, encoded⟩ := StreamCodec.encodeMany_decodeMany _ _ _ _ _ wordsOk
            have spelled : requestWords wire = words := requestWireOfWords_exact wireOk
            change StreamCodec.nat.encode (requestWords wire).length ++
              StreamCodec.encodeMany StreamCodec.nat (requestWords wire) ++ rest = bytes
            rw [spelled, List.append_assoc, encoded, length]
            exact StreamCodec.nat.encode_decodePrefix _ _ _ countOk
      · simp [countOk, exact] at decoded

theorem requestWireStream_wrong_count (count : Nat) (payload : List UInt8)
    (wrong : count ≠ requestWordCount) :
    requestWireStream.decodePrefix (StreamCodec.nat.encode count ++ payload) = none := by
  simp [requestWireStream, StreamCodec.nat.decodePrefix_encode, wrong]

/-- The preceding request vocabulary cannot acquire a fabricated zero revision. -/
theorem requestWireStream_rejects_omitted_revision (payload : List UInt8) :
    requestWireStream.decodePrefix (StreamCodec.nat.encode 16 ++ payload) = none :=
  requestWireStream_wrong_count 16 payload (by decide)

def requestWireCodec : LawfulCodec RequestWire := requestWireStream.toLawful

theorem requestWireStream_canonical {bytes suffix : List UInt8} {request : RequestWire}
    (decoded : requestWireStream.decodePrefix bytes = some (request, suffix)) :
    bytes = requestWireStream.encode request ++ suffix :=
  (requestWireStream.encode_decodePrefix _ _ _ decoded).symm

theorem requestWireCodec_canonical {bytes : List UInt8} {request : RequestWire}
    (decoded : requestWireCodec.decode bytes = some request) :
    requestWireCodec.encode request = bytes :=
  requestWireStream.toLawful_canonical _ _ decoded

def someRequestStream : StreamCodec SomeRequest where
  encode request := requestWireStream.encode (encodeRequest request)
  decodePrefix bytes := do
    let (wire, suffix) ← requestWireStream.decodePrefix bytes
    let request ← decodeRequest wire
    some (request, suffix)
  decodePrefix_encode := by
    intro request suffix
    simp [requestWireStream.decodePrefix_encode, decodeRequest_encodeRequest]
  encode_decodePrefix := by
    intro bytes request suffix decoded
    cases wireOk : requestWireStream.decodePrefix bytes with
    | none => simp [wireOk] at decoded
    | some wirePair =>
      obtain ⟨wire, rest⟩ := wirePair
      cases requestOk : decodeRequest wire with
      | none => simp [wireOk, requestOk] at decoded
      | some decodedRequest =>
        simp only [wireOk, requestOk, bind, Option.bind, Option.some.injEq,
          Prod.mk.injEq] at decoded
        obtain ⟨rfl, rfl⟩ := decoded
        change requestWireStream.encode (encodeRequest decodedRequest) ++ rest = bytes
        rw [encodeRequest_of_decode requestOk]
        exact requestWireStream.encode_decodePrefix _ _ _ wireOk

def someRequestCodec : LawfulCodec SomeRequest := someRequestStream.toLawful

theorem someRequestStream_canonical {bytes suffix : List UInt8} {request : SomeRequest}
    (decoded : someRequestStream.decodePrefix bytes = some (request, suffix)) :
    bytes = someRequestStream.encode request ++ suffix :=
  (someRequestStream.encode_decodePrefix _ _ _ decoded).symm

theorem someRequestCodec_canonical {bytes : List UInt8} {request : SomeRequest}
    (decoded : someRequestCodec.decode bytes = some request) :
    someRequestCodec.encode request = bytes :=
  someRequestStream.toLawful_canonical _ _ decoded

theorem someRequestStream_rejects_wire (wire : RequestWire) (suffix : List UInt8)
    (invalid : decodeRequest wire = none) :
    someRequestStream.decodePrefix (requestWireStream.encode wire ++ suffix) = none := by
  simp [someRequestStream, requestWireStream.decodePrefix_encode, invalid]

def requestStreamFor (kind : ResourceKind) : StreamCodec (Request kind) where
  encode request := someRequestStream.encode ⟨kind, request⟩
  decodePrefix bytes := do
    let (⟨actualKind, request⟩, suffix) ← someRequestStream.decodePrefix bytes
    if same : actualKind = kind then some (same ▸ request, suffix) else none
  decodePrefix_encode := by
    intro request suffix
    simp [someRequestStream.decodePrefix_encode]
  encode_decodePrefix := by
    intro bytes request suffix decoded
    cases someOk : someRequestStream.decodePrefix bytes with
    | none => simp [someOk] at decoded
    | some somePair =>
      obtain ⟨⟨actualKind, actual⟩, rest⟩ := somePair
      by_cases same : actualKind = kind
      · subst same
        simp only [someOk, bind, Option.bind, dite_true, Option.some.injEq,
          Prod.mk.injEq] at decoded
        obtain ⟨rfl, rfl⟩ := decoded
        exact someRequestStream.encode_decodePrefix _ _ _ someOk
      · simp [someOk, same] at decoded

def requestCodecFor (kind : ResourceKind) : LawfulCodec (Request kind) :=
  (requestStreamFor kind).toLawful

theorem requestStreamFor_canonical (kind : ResourceKind)
    {bytes suffix : List UInt8} {request : Request kind}
    (decoded : (requestStreamFor kind).decodePrefix bytes = some (request, suffix)) :
    bytes = (requestStreamFor kind).encode request ++ suffix :=
  ((requestStreamFor kind).encode_decodePrefix _ _ _ decoded).symm

theorem requestCodecFor_canonical (kind : ResourceKind)
    {bytes : List UInt8} {request : Request kind}
    (decoded : (requestCodecFor kind).decode bytes = some request) :
    (requestCodecFor kind).encode request = bytes :=
  (requestStreamFor kind).toLawful_canonical _ _ decoded

theorem requestStreamFor_wrong_kind {actual expected : ResourceKind}
    (request : Request actual) (suffix : List UInt8) (different : actual ≠ expected) :
    (requestStreamFor expected).decodePrefix
      (someRequestStream.encode ⟨actual, request⟩ ++ suffix) = none := by
  simp [requestStreamFor, someRequestStream.decodePrefix_encode, different]

abbrev requestCodecVersion := Minidregg.Theory.AuthorizationDeclaration.requestCodecVersion

/-- The signed frame is the PLAN frame: a signature over the old whole-request
frame (`DREGG/AUTH/REQUEST`) does not verify against it. -/
def requestFrame : List UInt8 :=
  "DREGG/AUTH/PLAN".toUTF8.toList ++ [UInt8.ofNat requestCodecVersion]

/-- The request as a plan signs it.  `height` is the admission clock and
`preStateRoot` is the kernel's own pre-root of the leg's cell
(`MultiCellHyperedge.PreparedTuple.requestRoots` derives it from the validated
patch); neither is the signer's to bind.  Signing them bound every plan to the
exact journal length and to the whole root of every cell it touched, so any
commit anywhere invalidated every pending plan.  A plan bounds the clock with
the signed header's `validUntil` and states what it read at address level: a
command's per-cell `expectedTargetRoot` for a cell it reads whole, and the
header's authority footprint (`Theory.PlanBinding`).  The two words are encoded
as zero. -/
def planOf (request : SomeRequest) : SomeRequest :=
  ⟨request.1, { request.2 with height := 0, preStateRoot := ⟨0⟩ }⟩

def signedRequestBytes (request : SomeRequest) : List UInt8 :=
  requestFrame ++ someRequestStream.encode (planOf request)

theorem signedRequestBytes_exact (request : SomeRequest) :
    signedRequestBytes request =
      ("DREGG/AUTH/PLAN".toUTF8.toList ++ [2]) ++
        (StreamCodec.list StreamCodec.nat).encode
          (requestWords (encodeRequest (planOf request))) := rfl

/-- The signed bytes determine exactly the plan: every request field except the
admission clock and the kernel-derived pre-root. -/
theorem signedRequestBytes_eq_iff (left right : SomeRequest) :
    signedRequestBytes left = signedRequestBytes right ↔ planOf left = planOf right := by
  constructor
  · intro same
    have samePayload : someRequestCodec.encode (planOf left) =
        someRequestCodec.encode (planOf right) :=
      List.append_cancel_left same
    have decoded := congrArg someRequestCodec.decode samePayload
    simpa only [someRequestCodec.decode_encode, Option.some.injEq] using decoded
  · intro same
    unfold signedRequestBytes
    rw [same]

/-- Satisfied pole: a plan signed at one height and pre-root is the same signed
plan at any other. -/
theorem signedRequestBytes_clock_free {kind : ResourceKind} (request : Request kind)
    (height : Height) (root : Digest) :
    signedRequestBytes ⟨kind, { request with height := height, preStateRoot := root }⟩ =
      signedRequestBytes ⟨kind, request⟩ := rfl

/-- Refuted pole: every plan field is still bound; two requests whose plans
differ sign different bytes. -/
theorem signedRequestBytes_separates_plan {left right : SomeRequest}
    (different : planOf left ≠ planOf right) :
    signedRequestBytes left ≠ signedRequestBytes right :=
  fun same => different ((signedRequestBytes_eq_iff left right).1 same)

/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.requestWireOfWords_exact' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms requestWireOfWords_exact
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.requestWords_injective' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms requestWords_injective
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.requestWireCodec_canonical' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms requestWireCodec_canonical
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.someRequestCodec_canonical' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms someRequestCodec_canonical
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.requestCodecFor_canonical' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms requestCodecFor_canonical
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.requestStreamFor_wrong_kind' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms requestStreamFor_wrong_kind
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.signedRequestBytes_exact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms signedRequestBytes_exact
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.signedRequestBytes_eq_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms signedRequestBytes_eq_iff
/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.signedRequestBytes_clock_free' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms signedRequestBytes_clock_free


private theorem resourceKindTag_of_decoded {tag : Nat} {kind : ResourceKind}
    (decoded : decodeResourceKind tag = some kind) : resourceKindTag kind = tag := by
  cases kind <;> unfold decodeResourceKind at decoded <;>
    split at decoded <;> simp_all [resourceKindTag]

private theorem verbTag_of_decoded {kind : ResourceKind} {tag : Nat} {verb : Verb kind}
    (decoded : decodeVerb kind tag = some verb) :
    Minidregg.Theory.AuthorizationDeclaration.verbTag verb = tag := by
  fun_cases decodeVerb kind tag <;>
    grind +lax [decodeVerb, Minidregg.Theory.AuthorizationDeclaration.verbTag]

theorem encodeRequest_of_decodeRequest {wire : RequestWire} {request : SomeRequest}
    (decoded : decodeRequest wire = some request) : encodeRequest request = wire := by
  unfold decodeRequest at decoded
  cases kindDecoded : decodeResourceKind wire.resourceKind with
  | none => simp [kindDecoded] at decoded
  | some kind =>
    cases verbDecoded : decodeVerb kind wire.verb with
    | none => simp [kindDecoded, verbDecoded] at decoded
    | some verb =>
      simp only [kindDecoded, bind, Option.bind, verbDecoded] at decoded
      cases Option.some.inj decoded
      have kindExact := resourceKindTag_of_decoded kindDecoded
      have verbExact := verbTag_of_decoded verbDecoded
      cases wire
      simp_all [encodeRequest]


/-- info: 'Minidregg.Compiler.TypedAuthorizationRequestCodec.encodeRequest_of_decodeRequest' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms encodeRequest_of_decodeRequest

/-- Object clients share the complete kind-tagged codec; no second request layout. -/
def requestStream : StreamCodec (Request .object) := requestStreamFor .object

def requestCodec : LawfulCodec (Request .object) := requestCodecFor .object

theorem requestCodec_separates_target (request : Request .object)
    (other : ResourceId .object) (different : request.target ≠ other) :
    requestCodec.encode request ≠ requestCodec.encode { request with target := other } := by
  intro same
  apply different
  have decoded := congrArg requestCodec.decode same
  rw [requestCodec.decode_encode, requestCodec.decode_encode] at decoded
  exact congrArg Request.target (Option.some.inj decoded)

theorem requestCodec_separates_effectsDigest (request : Request .object)
    (other : Digest) (different : request.effectsDigest ≠ other) :
    requestCodec.encode request ≠ requestCodec.encode { request with effectsDigest := other } := by
  intro same
  apply different
  have decoded := congrArg requestCodec.decode same
  rw [requestCodec.decode_encode, requestCodec.decode_encode] at decoded
  exact congrArg Request.effectsDigest (Option.some.inj decoded)

theorem requestStream_composes (request : Request .object) (suffix : List UInt8) :
    requestStream.decodePrefix (requestStream.encode request ++ suffix) = some (request, suffix) :=
  requestStream.decodePrefix_encode request suffix

end Minidregg.Compiler.TypedAuthorizationRequestCodec

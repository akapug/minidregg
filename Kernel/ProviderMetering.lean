/-
Typed, source-owned quote for one provider call, by the route the call took.
The operator pins a per-route tariff in the Host profile and funds an
independent AgentGrain allowance. Neither the reported counts nor this quote
authenticate a provider invoice. The native receiver still decides whether an
authored settlement is admitted, under the provider purse's route law
(`Kernel.ProviderRoute`), which charges by the route recorded at reserve.
-/
module

public import Kernel.AgentGrain
public import Theory.AssertAxioms

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

namespace Minidregg.Kernel.ProviderMetering

open Minidregg.Theory.TypedAuthorization (Digest)
open Minidregg.Compiler
open Minidregg.Kernel

set_option autoImplicit false

/-- The payer of one provider call, fixed when the purse reserves for it.
* `user`: the friend's own provider key. The friend pays the provider
  directly; Mini charges only the per-operation fee for the turn.
* `pool`: the operator's key, funded by the purse. Metered.
* `homelab`: a keyless upstream the operator runs. Priced like the pool
  (a per-operation fee plus optional metered rates).
There is no `none` route: a call without a payer is refused before any
reserve, so no purse ever holds for it (`ProviderRoute.none_route_reserves_nothing`). -/
inductive Route where
  | user
  | pool
  | homelab
  deriving DecidableEq, Repr

/-- The code the purse records in its route field (field 4). Zero is "no
call in flight". -/
def Route.code : Route → Int
  | .user => 1
  | .pool => 2
  | .homelab => 3

def Route.name : Route → String
  | .user => "user"
  | .pool => "pool"
  | .homelab => "homelab"

def Route.ofName? : String → Option Route
  | "user" => some .user
  | "pool" => some .pool
  | "homelab" => some .homelab
  | _ => none

def Route.ofCode? : Int → Option Route
  | 1 => some .user
  | 2 => some .pool
  | 3 => some .homelab
  | _ => none

theorem Route.ofCode_code (route : Route) : Route.ofCode? route.code = some route := by
  cases route <;> rfl

theorem Route.ofName_name (route : Route) : Route.ofName? route.name = some route := by
  cases route <;> rfl

/-- A metered route's rates. All three are in **credit**: a purse is funded
only by `Kernel.PurseRefill`, which burns the pay tariff's credit asset 1:1
into the purse's allowance, so one permission micro-unit is one credit and
`inputMicroPerMillion = 20000000` means 20 credits per million input tokens. -/
structure Rate where
  perOp : Nat
  inputMicroPerMillion : Nat
  outputMicroPerMillion : Nat
  deriving DecidableEq, Repr

/-- The per-route provider tariff (schema v2). The user route has a
per-operation fee and nothing else: it has no rate fields, so no token count
can reach a user-route charge. The version is an operator-controlled tariff
identity, not a provider price feed. -/
structure Tariff where
  version : Nat
  model : String
  userPerOp : Nat
  pool : Rate
  homelab : Rate
  deriving DecidableEq, Repr

/-- The per-operation fees, the part of the tariff the provider purse's
installed law carries as constants. -/
structure Schedule where
  user : Nat
  pool : Nat
  homelab : Nat
  deriving DecidableEq, Repr

def Tariff.schedule (tariff : Tariff) : Schedule :=
  ⟨tariff.userPerOp, tariff.pool.perOp, tariff.homelab.perOp⟩

def Schedule.perOp (schedule : Schedule) : Route → Nat
  | .user => schedule.user
  | .pool => schedule.pool
  | .homelab => schedule.homelab

def Tariff.perOp (tariff : Tariff) (route : Route) : Nat :=
  tariff.schedule.perOp route

/-- The metered rates of a route; the user route has none. -/
def Tariff.rate? (tariff : Tariff) : Route → Option Rate
  | .user => none
  | .pool => some tariff.pool
  | .homelab => some tariff.homelab

/-- Counts asserted in one complete upstream response. The parser, not the
worker, must construct these from the retained response bytes. -/
structure Usage where
  promptTokens : Nat
  completionTokens : Nat
  totalTokens : Nat
  deriving DecidableEq, Repr

def maxReportedTokens : Nat := 1000000000
def maxRate : Nat := 1000000000000
def million : Nat := 1000000

def Rate.valid (rate : Rate) : Prop :=
  rate.perOp ≤ maxRate ∧
  rate.inputMicroPerMillion ≤ maxRate ∧
  rate.outputMicroPerMillion ≤ maxRate

instance (rate : Rate) : Decidable rate.valid := by
  unfold Rate.valid; infer_instance

def Tariff.valid (tariff : Tariff) : Prop :=
  0 < tariff.version ∧
  0 < tariff.model.toUTF8.size ∧
  tariff.model.toUTF8.size ≤ 256 ∧
  tariff.userPerOp ≤ maxRate ∧
  tariff.pool.valid ∧
  tariff.homelab.valid

instance (tariff : Tariff) : Decidable tariff.valid := by
  unfold Tariff.valid; infer_instance

def Usage.valid (usage : Usage) : Prop :=
  usage.totalTokens = usage.promptTokens + usage.completionTokens ∧
  usage.promptTokens ≤ maxReportedTokens ∧
  usage.completionTokens ≤ maxReportedTokens

instance (usage : Usage) : Decidable usage.valid := by
  unfold Usage.valid; infer_instance

def weighted (rate : Rate) (usage : Usage) : Nat :=
  usage.promptTokens * rate.inputMicroPerMillion +
    usage.completionTokens * rate.outputMicroPerMillion

/-- Round the metered part upward once, to an integral permission
micro-unit. No floating-point arithmetic or per-category double rounding. -/
def metered (rate : Rate) (usage : Usage) : Nat :=
  (weighted rate usage + million - 1) / million

/-- The one rounding point is the ceiling of the aggregate numerator,
including the zero-usage case. -/
theorem metered_rounding (rate : Rate) (usage : Usage) :
    weighted rate usage ≤ metered rate usage * million ∧
      metered rate usage * million < weighted rate usage + million := by
  unfold metered million
  omega

/-- The charge for one call on a route: its per-operation fee, plus, on a
metered route, the metered usage. A user-route call ignores the usage. -/
def charge (tariff : Tariff) (route : Route) (usage : Usage) : Nat :=
  tariff.perOp route +
    match tariff.rate? route with
    | none => 0
    | some rate => metered rate usage

theorem charge_user (tariff : Tariff) (usage : Usage) :
    charge tariff .user usage = tariff.userPerOp := by
  simp [charge, Tariff.rate?, Tariff.perOp, Tariff.schedule, Schedule.perOp]

theorem charge_pool (tariff : Tariff) (usage : Usage) :
    charge tariff .pool usage = tariff.pool.perOp + metered tariff.pool usage := by
  simp [charge, Tariff.rate?, Tariff.perOp, Tariff.schedule, Schedule.perOp]

theorem charge_homelab (tariff : Tariff) (usage : Usage) :
    charge tariff .homelab usage = tariff.homelab.perOp + metered tariff.homelab usage := by
  simp [charge, Tariff.rate?, Tariff.perOp, Tariff.schedule, Schedule.perOp]

/-- The largest charge a metered call can reach under per-call token
ceilings: what the reserve must cover. -/
def maxCharge (tariff : Tariff) (route : Route) (maxInput maxOutput : Nat) : Nat :=
  charge tariff route ⟨maxInput, maxOutput, maxInput + maxOutput⟩

theorem metered_monotone (rate : Rate) (usage : Usage) (maxInput maxOutput : Nat)
    (input : usage.promptTokens ≤ maxInput) (output : usage.completionTokens ≤ maxOutput) :
    metered rate usage ≤ metered rate ⟨maxInput, maxOutput, maxInput + maxOutput⟩ := by
  unfold metered weighted
  apply Nat.div_le_div_right
  have := Nat.mul_le_mul_right rate.inputMicroPerMillion input
  have := Nat.mul_le_mul_right rate.outputMicroPerMillion output
  dsimp only
  omega

/-- A call within the token ceilings never charges more than `maxCharge`. -/
theorem charge_le_maxCharge (tariff : Tariff) (route : Route) (usage : Usage)
    (maxInput maxOutput : Nat)
    (input : usage.promptTokens ≤ maxInput) (output : usage.completionTokens ≤ maxOutput) :
    charge tariff route usage ≤ maxCharge tariff route maxInput maxOutput := by
  unfold maxCharge
  cases route with
  | user => simp [charge_user]
  | pool =>
      rw [charge_pool, charge_pool]
      have := metered_monotone tariff.pool usage maxInput maxOutput input output
      omega
  | homelab =>
      rw [charge_homelab, charge_homelab]
      have := metered_monotone tariff.homelab usage maxInput maxOutput input output
      omega

/-- Unambiguous length-prefixing keeps model, version, route and rates
distinct before the repository's domain-separated cSHAKE projection. -/
def rateBytes (rate : Rate) : List UInt8 :=
  Sp800185Cshake256.leftEncode rate.perOp ++
  Sp800185Cshake256.leftEncode rate.inputMicroPerMillion ++
  Sp800185Cshake256.leftEncode rate.outputMicroPerMillion

def tariffBytes (tariff : Tariff) : List UInt8 :=
  Sp800185Cshake256.encodeString tariff.model.toUTF8.toList ++
  Sp800185Cshake256.leftEncode tariff.version ++
  Sp800185Cshake256.leftEncode tariff.userPerOp ++
  rateBytes tariff.pool ++
  rateBytes tariff.homelab

def tariffDigest (tariff : Tariff) : Digest :=
  (Sp800185Cshake256.hash "DREGG.PROVIDER.TARIFF/v2".toUTF8.toList
    (tariffBytes tariff)).digest

def requestDigest (bytes : List UInt8) : Digest :=
  (Sp800185Cshake256.hash "DREGG.PROVIDER.REQUEST/v1".toUTF8.toList bytes).digest

def responseDigest (bytes : List UInt8) : Digest :=
  (Sp800185Cshake256.hash "DREGG.PROVIDER.RESPONSE/v1".toUTF8.toList bytes).digest

/-- How a metered call's provider leg ended. The four failure classes of the triage
(RUST-TRIAGE §4 rank 6; grain-runtime H1–H4) and the one success class:
* `complete`: a complete reply with an HTTP status. At 200 its usage record is read;
  at any other status it is a refused reply;
* `timeout`: the upstream deadline passed with no complete reply;
* `truncated`: a reply was received but is malformed or truncated, so no usage can be
  read (a complete 200 whose body the Host cannot read is classed here too);
* `lost`: the controller crashed after the durable send boundary and before any outcome. -/
inductive Leg where
  | complete
  | timeout
  | truncated
  | lost
  deriving DecidableEq, Repr

def Leg.name : Leg → String
  | .complete => "complete"
  | .timeout => "timeout"
  | .truncated => "truncated"
  | .lost => "lost"

def Leg.ofName? : String → Option Leg
  | "complete" => some .complete
  | "timeout" => some .timeout
  | "truncated" => some .truncated
  | "lost" => some .lost
  | _ => none

theorem Leg.ofName_name (leg : Leg) : Leg.ofName? leg.name = some leg := by
  cases leg <;> rfl

/-- What a quote's amount rests on. -/
inductive Basis where
  /-- A user-route call: the per-operation fee alone; no usage is read. -/
  | perOperation
  /-- A complete 200 reply with one terminal usage record. -/
  | reported (usage : Usage)
  /-- A complete reply with a non-200 status: the provider refused the call. -/
  | refusedReply (status : Nat)
  /-- No usage can be read: the leg failed in the named way. -/
  | undecided (leg : Leg)
  deriving DecidableEq, Repr

def Basis.usage? : Basis → Option Usage
  | .reported usage => some usage
  | _ => none

/-- A basis is valid when the usage it reports (if any) is. -/
def Basis.valid : Basis → Prop
  | .reported usage => usage.valid
  | _ => True

instance : (basis : Basis) → Decidable basis.valid
  | .reported usage => inferInstanceAs (Decidable usage.valid)
  | .perOperation => inferInstanceAs (Decidable True)
  | .refusedReply _ => inferInstanceAs (Decidable True)
  | .undecided _ => inferInstanceAs (Decidable True)

theorem Basis.valid_reported {basis : Basis} (valid : basis.valid) (usage : Usage)
    (reported : basis = .reported usage) : usage.valid := by
  subst reported; exact valid

theorem Basis.valid_of_no_usage {basis : Basis} (failed : basis.usage? = none) : basis.valid := by
  cases basis <;> simp_all [Basis.usage?, Basis.valid]

def Basis.name : Basis → String
  | .perOperation => "per-operation"
  | .reported _ => "reported"
  | .refusedReply _ => "refused-reply"
  | .undecided _ => "undecided"

/-- The amount a quote names, by route and basis, against the held allowance `reserve`.
Total: every leg of every route has a decided charge.
* user route: the per-operation fee whatever the reply (the friend's key paid the provider);
* metered route, usage reported: the tariff charge;
* metered route, refused reply: the route's per-operation fee, the DECLARED REFUSAL FEE.
  Zero is the purse law's release of a call that never left (`ProviderRoute.settleRule`),
  and this call left; providers do not bill a non-2xx reply, so the operator's exposure is
  the fee it declared for a turn, and that is what the purse pays;
* metered route, undecided leg: the HOLD, the pessimistic number (ATLAS law 14). The
  provider may have completed and billed anything up to the held maximum and nothing
  retained bounds it lower; the member authorised exactly this maximum at reserve. -/
def quoteAmount (tariff : Tariff) (route : Route) (basis : Basis) (reserve : Nat) : Nat :=
  match route, basis with
  | .user, _ => tariff.userPerOp
  | route, .reported usage => charge tariff route usage
  | route, .refusedReply _ => tariff.perOp route
  | route, .perOperation => tariff.perOp route
  | _, .undecided _ => reserve

/-- A quote identifies the exact retained request/response bytes, the route,
the basis of its amount (reported usage, refused reply, undecided leg), the
configured tariff and the held allowance. Its evidence is external data; the
proof fields establish only arithmetic and allowance bounds. -/
structure Quote where
  tariff : Tariff
  tariffValid : tariff.valid
  route : Route
  basis : Basis
  basisValid : basis.valid
  request : List UInt8
  response : List UInt8
  reserve : Nat
  amount : Nat
  amountExact : quoteAmount tariff route basis reserve = amount
  amountBound : amount ≤ reserve

/-- The reported usage, when the basis is one. -/
def Quote.usage (quote : Quote) : Option Usage := quote.basis.usage?

theorem Quote.usageValid (quote : Quote) (observed : Usage)
    (reported : quote.basis = .reported observed) : observed.valid :=
  Basis.valid_reported quote.basisValid observed reported

def prepare (tariff : Tariff) (route : Route) (basis : Basis)
    (request response : List UInt8) (reserve : Nat) : Option Quote :=
  if ht : tariff.valid then
    if hv : basis.valid then
      if hb : quoteAmount tariff route basis reserve ≤ reserve then
        some ⟨tariff, ht, route, basis, hv, request, response, reserve, _, rfl, hb⟩
      else none
    else none
  else none

/-- A user-route quote is exactly the per-operation fee, whatever the basis. -/
theorem Quote.user_is_per_op (quote : Quote) (user : quote.route = .user) :
    quote.amount = quote.tariff.userPerOp := by
  have exact := quote.amountExact
  rw [user] at exact
  simp [quoteAmount] at exact
  exact exact.symm

/-- A pool-route quote on reported usage is the per-operation fee plus the metered usage. -/
theorem Quote.pool_is_metered (quote : Quote) (pool : quote.route = .pool) (usage : Usage)
    (reported : quote.basis = .reported usage) :
    quote.amount = quote.tariff.pool.perOp + metered quote.tariff.pool usage := by
  have exact := quote.amountExact
  rw [pool, reported] at exact
  simp [quoteAmount, charge_pool] at exact
  exact exact.symm

/-- A metered quote on a refused reply is the route's per-operation fee. -/
theorem Quote.refused_reply_is_fee (quote : Quote) (metered : quote.route ≠ .user)
    (status : Nat) (refused : quote.basis = .refusedReply status) :
    quote.amount = quote.tariff.perOp quote.route := by
  have exact := quote.amountExact
  rw [refused] at exact
  cases route : quote.route with
  | user => exact absurd route metered
  | pool => rw [route] at exact; simpa [quoteAmount] using exact.symm
  | homelab => rw [route] at exact; simpa [quoteAmount] using exact.symm

/-- A metered quote on an undecided leg is the hold. -/
theorem Quote.undecided_is_hold (quote : Quote) (metered : quote.route ≠ .user)
    (leg : Leg) (undecided : quote.basis = .undecided leg) :
    quote.amount = quote.reserve := by
  have exact := quote.amountExact
  rw [undecided] at exact
  cases route : quote.route with
  | user => exact absurd route metered
  | pool => rw [route] at exact; simpa [quoteAmount] using exact.symm
  | homelab => rw [route] at exact; simpa [quoteAmount] using exact.symm

/-- **Every failed provider leg has a decided settle.** For a valid tariff, a metered
route and any of the four failure classes (a complete non-200 reply; an upstream
timeout; a truncated or malformed reply; a crash after the send boundary), `prepare`
yields a quote whenever the hold covers the route fee (the purse law guarantees this
at reserve: `ProviderRoute.reserveRule`), and the quote's amount is the declared
charge: the route fee for a refused reply, the hold for an undecided leg; in every
case at most the hold. Before this lane `quoteAmount` was `none` for a metered route
without a usage record, so this statement was false at every one of the four classes
and one 429 left a purse held forever (RUST-TRIAGE §4 rank 6). -/
theorem failed_leg_settle_decided (tariff : Tariff) (valid : tariff.valid) (route : Route)
    (metered : route ≠ .user) (basis : Basis) (failed : basis.usage? = none)
    (request response : List UInt8) (reserve : Nat) (held : tariff.perOp route ≤ reserve) :
    ∃ quote, prepare tariff route basis request response reserve = some quote ∧
      quote.amount ≤ reserve ∧
      ((∃ status, basis = .refusedReply status ∧ quote.amount = tariff.perOp route) ∨
        (∃ leg, basis = .undecided leg ∧ quote.amount = reserve) ∨
        (basis = .perOperation ∧ quote.amount = tariff.perOp route)) := by
  have noUsage : basis.valid := Basis.valid_of_no_usage failed
  have bound : quoteAmount tariff route basis reserve ≤ reserve := by
    cases basis with
    | reported usage => simp [Basis.usage?] at failed
    | perOperation => cases route <;> simp_all [quoteAmount, Tariff.perOp, Tariff.schedule, Schedule.perOp]
    | refusedReply status => cases route <;> simp_all [quoteAmount, Tariff.perOp, Tariff.schedule, Schedule.perOp]
    | undecided leg => cases route <;> simp_all [quoteAmount]
  refine ⟨⟨tariff, valid, route, basis, noUsage, request, response, reserve, _, rfl, bound⟩, ?_, bound, ?_⟩
  · unfold prepare
    rw [dif_pos valid, dif_pos noUsage, dif_pos bound]
  · cases basis with
    | reported usage => simp [Basis.usage?] at failed
    | perOperation =>
        right; right
        refine ⟨rfl, ?_⟩
        cases route with
        | user => exact absurd rfl metered
        | pool => rfl
        | homelab => rfl
    | refusedReply status =>
        left
        refine ⟨status, rfl, ?_⟩
        cases route with
        | user => exact absurd rfl metered
        | pool => rfl
        | homelab => rfl
    | undecided leg =>
        right; left
        refine ⟨leg, rfl, ?_⟩
        cases route with
        | user => exact absurd rfl metered
        | pool => rfl
        | homelab => rfl

/-- Every quote on a metered route is a settle the purse's route law admits
(`ProviderRoute.pool_route_charges_metered` / `homelab_route_charges_metered` shape):
zero, or at least the route fee and at most the hold. Needs only that the hold covered
the fee, which the reserve rule enforced. -/
theorem Quote.admissible_metered_settle (quote : Quote) (metered : quote.route ≠ .user)
    (held : quote.tariff.perOp quote.route ≤ quote.reserve) :
    quote.amount = 0 ∨
      (quote.tariff.perOp quote.route ≤ quote.amount ∧ quote.amount ≤ quote.reserve) := by
  right
  refine ⟨?_, quote.amountBound⟩
  have exact := quote.amountExact
  cases basis : quote.basis with
  | perOperation =>
      rw [basis] at exact
      cases route : quote.route with
      | user => exact absurd route metered
      | pool => rw [route] at exact; simp [quoteAmount] at exact; omega
      | homelab => rw [route] at exact; simp [quoteAmount] at exact; omega
  | reported usage =>
      rw [basis] at exact
      cases route : quote.route with
      | user => exact absurd route metered
      | pool => rw [route] at exact; simp [quoteAmount, charge_pool, Tariff.perOp, Tariff.schedule, Schedule.perOp] at exact ⊢; omega
      | homelab => rw [route] at exact; simp [quoteAmount, charge_homelab, Tariff.perOp, Tariff.schedule, Schedule.perOp] at exact ⊢; omega
  | refusedReply status =>
      rw [basis] at exact
      cases route : quote.route with
      | user => exact absurd route metered
      | pool => rw [route] at exact; simp [quoteAmount] at exact; omega
      | homelab => rw [route] at exact; simp [quoteAmount] at exact; omega
  | undecided leg =>
      rw [basis] at exact
      cases route : quote.route with
      | user => exact absurd route metered
      | pool => rw [route] at exact held; simp [quoteAmount] at exact; omega
      | homelab => rw [route] at exact held; simp [quoteAmount] at exact; omega

/-- Satisfiable at a concrete tariff (pool fee 2): a 429 on the pool route is charged the
pool fee, 2, not nothing and not the hold; `failed_leg_settle_decided` supplies the quote. -/
theorem refused_reply_quoted_fee_witness :
    quoteAmount ⟨1, "m", 4, ⟨2, 1000000, 2000000⟩, ⟨0, 1, 1⟩⟩ .pool (.refusedReply 429) 500 = 2 := rfl

/-- Teeth: a crash after the send boundary is charged the whole hold. An implementation
that released the hold for free, or that still refused to quote (the state before this
lane), fails this witness. -/
theorem lost_leg_quoted_hold_witness :
    quoteAmount ⟨1, "m", 4, ⟨2, 1000000, 2000000⟩, ⟨0, 1, 1⟩⟩ .pool (.undecided .lost) 500 = 500 := rfl

def Quote.operation (quote : Quote) : AgentGrain.Operation :=
  .settle (Int.ofNat quote.amount)

theorem Quote.operation_after (quote : Quote) (state : AgentGrain.State) :
    quote.operation.after state = AgentGrain.settle state (Int.ofNat quote.amount) := rfl

theorem Quote.charge_within_hold (quote : Quote) :
    0 ≤ (Int.ofNat quote.amount : Int) ∧
      (Int.ofNat quote.amount : Int) ≤ Int.ofNat quote.reserve := by
  constructor
  · exact Int.natCast_nonneg _
  · exact Int.ofNat_le.mpr quote.amountBound

/-- The controller must establish this equality from the fresh signed
provider state; the quote's reserve field alone is not a receipt. -/
theorem Quote.charge_within_signed_hold (quote : Quote) (state : AgentGrain.State)
    (held : state.reserved = Int.ofNat quote.reserve) :
    0 ≤ (Int.ofNat quote.amount : Int) ∧
      (Int.ofNat quote.amount : Int) ≤ state.reserved := by
  simpa [held] using quote.charge_within_hold

theorem Quote.exact_budget_change (quote : Quote) (state : AgentGrain.State) :
    (quote.operation.after state).remaining +
      (quote.operation.after state).reserved =
      state.remaining + state.reserved - Int.ofNat quote.amount := by
  simp [Quote.operation_after, AgentGrain.settle]

/-- Once the native receiver admits the exact authored settlement, its budget
decreases by precisely the Lean quote. The quote does not itself prove receipt
authenticity, authority, or receiver admission. -/
theorem Quote.admitted_budget_nonincrease (quote : Quote) (state : AgentGrain.State)
    (admitted : AgentGrain.accepts state (quote.operation.after state) = true) :
    (quote.operation.after state).remaining +
      (quote.operation.after state).reserved ≤ state.remaining + state.reserved :=
  AgentGrain.accepted_budget_nonincrease state (quote.operation.after state) admitted

#assert_axioms Route.ofCode_code
#assert_axioms Route.ofName_name
#assert_axioms metered_rounding
#assert_axioms charge_user
#assert_axioms charge_pool
#assert_axioms charge_homelab
#assert_axioms metered_monotone
#assert_axioms charge_le_maxCharge
#assert_axioms Leg.ofName_name
#assert_axioms Quote.user_is_per_op
#assert_axioms Quote.pool_is_metered
#assert_axioms Quote.refused_reply_is_fee
#assert_axioms Quote.undecided_is_hold
#assert_axioms failed_leg_settle_decided
#assert_axioms Quote.admissible_metered_settle
#assert_axioms refused_reply_quoted_fee_witness
#assert_axioms lost_leg_quoted_hold_witness
#assert_axioms Quote.charge_within_signed_hold
#assert_axioms Quote.exact_budget_change
#assert_axioms Quote.admitted_budget_nonincrease

end Minidregg.Kernel.ProviderMetering

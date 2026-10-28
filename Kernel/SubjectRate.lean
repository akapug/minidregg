/-
# Kernel.SubjectRate -- a per-subject request rate for the Host (statement first)

The Host is the one place ssh, web and socket clients meet (`mini serve` feeds one Host
process; `native/resource-client/src/transport.rs` `serve_host_observed`). The transport's
fairness is per kernel peer uid (`serve_queue.rs`), but public clients can arrive through one
relay uid, so a peer is not a member. This module states the rate law over the Host's own
notion of a requester: the **subject**, as the request claims it and as its signature verifies
it.

## The shape: claim-checked, verify-charged

* `check` reads the table for the subject the request **claims**, before any Store work. It
  never changes the table.
* `charge` is applied only after the receiver has **verified** the request's signature for that
  subject. A verified request names the subject it claimed, so check and charge see one subject.
* A request that fails verification charges nobody: a forger naming a victim's subject cannot
  fill the victim's window (`charge_other`, `check_forgery_free`); it can only be refused on the
  victim's already-full window, which costs the victim nothing.
* A refused request charges nothing, so a flood does not extend its own window, and the
  refusal's retry promise holds (`check_retry_admits`).

## The poles (ATLAS fields)

* **Satisfiable:** a subject's first `limit` verified requests inside a window are admitted
  (`check_fresh`, `check_below_limit`, the concrete run `witness_run`).
* **Teeth:** the next request inside the window is refused `limited r` where `r` is the time
  left in the window, `0 < r` (`check_at_limit`, `limit_charges_refuse`, `witness_run`).
* **After the window:** admitted again and the window restarts (`check_after_window`,
  `charge_after_window`).
* **Non-interference:** one subject's charges never change another's answer (`charge_other`).
* **Exemption, decided:** the configured operator subjects (the box's own member and its
  sponsor) are exempt: always admitted, never charged (`check_exempt`, `charge_exempt`). A
  stranger cannot act as an exempt subject without its key, and the exempt set is part of the
  Host's published configuration. The exemption is by verified subject, not by socket: the Host
  does not learn which listener a frame arrived on.

## Time, not height

The window is the Host's monotonic clock in milliseconds (`IO.monoMsNow`), and a refusal says
how long until the window reopens. A window in world heights would never reopen for a reader in
a quiet world: reads and dry-runs (the flood ABUSE-LIMITS gap 2 names) do not move the height.

## Scope

The table lives in the Host process (bounded by the subjects that ever verified, since only
verified requests charge); a Host restart starts every window afresh. Which operations check and
charge, and the refusal's name on the wire, are integration decisions recorded in
`docs/PD-HOST-RATE-DESIGN.md`; this module is the law they must instantiate.
-/
module

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

namespace Minidregg.Kernel.SubjectRate

set_option autoImplicit false

/-- The rate: at most `limit` charged requests per subject per `windowMs` milliseconds. -/
structure Policy where
  limit : Nat
  windowMs : Nat
  limit_pos : 0 < limit
  window_pos : 0 < windowMs

/-- The Host's default (coordinator's ruling, 2026-10-27; ASSUMED until `jtour` counts signed
frames per verb): 300 signed requests per subject per 60 s, 5 a second sustained. -/
def hostDefault : Policy := ⟨300, 60000, by decide, by decide⟩

/-- A configured rate; a zero limit or a zero window refuses the configuration. -/
def Policy.make (limit windowMs : Nat) : Except String Policy :=
  if h₁ : 0 < limit then
    if h₂ : 0 < windowMs then .ok ⟨limit, windowMs, h₁, h₂⟩
    else .error "requestRate.windowMs must be positive"
  else .error "requestRate.limit must be positive"

/-- The exempt predicate of a configured subject list. -/
def exemptOf (subjects : List Nat) (subject : Nat) : Bool := subjects.contains subject

/-- One subject's current window: when it started and how many requests it has charged. -/
structure Slot where
  start : Nat
  count : Nat
  deriving DecidableEq, Repr

/-- Subject → its window. Only verified subjects ever enter. -/
abbrev Table := List (Nat × Slot)

/-- The answer to a claimed subject. -/
inductive Decision where
  | admit
  /-- Refused; the window reopens `retryAfterMs` milliseconds from now. -/
  | limited (retryAfterMs : Nat)
  deriving DecidableEq, Repr

def lookup (t : Table) (subject : Nat) : Option Slot := t.lookup subject

def put (t : Table) (subject : Nat) (slot : Slot) : Table :=
  (subject, slot) :: t.filter (fun e => e.1 != subject)

/-- Read-only: may a request claiming `subject` proceed at time `now`? -/
def check (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat) : Decision :=
  if exempt subject then .admit else
  match lookup t subject with
  | none => .admit
  | some s =>
      if now < s.start + p.windowMs then
        if s.count < p.limit then .admit else .limited (s.start + p.windowMs - now)
      else .admit

/-- After the receiver verified a request for `subject`: charge it to the subject's window. -/
def charge (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat) : Table :=
  if exempt subject then t else
  match lookup t subject with
  | some s => if now < s.start + p.windowMs then put t subject ⟨s.start, s.count + 1⟩
              else put t subject ⟨now, 1⟩
  | none => put t subject ⟨now, 1⟩

/-! ## Table lemmas -/

theorem lookup_put_self (t : Table) (subject : Nat) (slot : Slot) :
    lookup (put t subject slot) subject = some slot := by
  simp [lookup, put]

theorem lookup_filter_ne (t : Table) (a b : Nat) (h : b ≠ a) :
    (t.filter (fun e => e.1 != a)).lookup b = t.lookup b := by
  induction t with
  | nil => rfl
  | cons e rest ih =>
      obtain ⟨k, v⟩ := e
      by_cases hk : k = a
      · subst hk
        have hbk : (b == k) = false := by simpa using h
        simp [List.filter, List.lookup, hbk, ih]
      · have hka : (k != a) = true := by simpa using hk
        simp only [List.filter, hka, List.lookup]
        split <;> simp_all

theorem lookup_put_other (t : Table) (a b : Nat) (slot : Slot) (h : b ≠ a) :
    lookup (put t a slot) b = lookup t b := by
  have hba : (b == a) = false := by simpa using h
  simp [lookup, put, List.lookup, hba, lookup_filter_ne t a b h]

/-! ## The poles -/

/-- Satisfiable: a subject never seen is admitted. -/
theorem check_fresh (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (h : lookup t subject = none) : check p exempt t subject now = .admit := by
  simp [check, h]

/-- Satisfiable: inside the window and below the limit, admitted. -/
theorem check_below_limit (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (s : Slot) (h : lookup t subject = some s) (hin : now < s.start + p.windowMs)
    (hc : s.count < p.limit) : check p exempt t subject now = .admit := by
  simp [check, h, hin, hc]

/-- Teeth: inside the window at the limit, a non-exempt subject is refused, with the time left
in its window, which is positive. -/
theorem check_at_limit (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (s : Slot) (hx : exempt subject = false) (h : lookup t subject = some s)
    (hin : now < s.start + p.windowMs) (hc : p.limit ≤ s.count) :
    check p exempt t subject now = .limited (s.start + p.windowMs - now) ∧
      0 < s.start + p.windowMs - now := by
  have hnc : ¬ s.count < p.limit := by omega
  refine ⟨?_, by omega⟩
  simp [check, hx, h, hin, hnc]

/-- After the window, admitted again. -/
theorem check_after_window (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (s : Slot) (h : lookup t subject = some s) (hout : s.start + p.windowMs ≤ now) :
    check p exempt t subject now = .admit := by
  have : ¬ now < s.start + p.windowMs := by omega
  simp [check, h, this]

/-- A charge after the window restarts it at `now` with one request. -/
theorem charge_after_window (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (s : Slot) (hx : exempt subject = false) (h : lookup t subject = some s)
    (hout : s.start + p.windowMs ≤ now) :
    lookup (charge p exempt t subject now) subject = some ⟨now, 1⟩ := by
  have : ¬ now < s.start + p.windowMs := by omega
  simp [charge, hx, h, this, lookup_put_self]

/-- A charge inside the window adds exactly one to the subject's count. -/
theorem charge_in_window (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (s : Slot) (hx : exempt subject = false) (h : lookup t subject = some s)
    (hin : now < s.start + p.windowMs) :
    lookup (charge p exempt t subject now) subject = some ⟨s.start, s.count + 1⟩ := by
  simp [charge, hx, h, hin, lookup_put_self]

/-- Non-interference: charging one subject never changes another's window, so it never changes
another's answer. In particular a forged request, which verifies for nobody and charges nobody,
cannot fill a victim's window: only charges carrying the victim's verified subject move it. -/
theorem charge_other (p : Policy) (exempt : Nat → Bool) (t : Table) (a b now : Nat) (h : b ≠ a) :
    lookup (charge p exempt t a now) b = lookup t b := by
  unfold charge
  split
  · rfl
  · split
    · split <;> exact lookup_put_other _ _ _ _ h
    · exact lookup_put_other _ _ _ _ h

theorem check_forgery_free (p : Policy) (exempt : Nat → Bool) (t : Table) (a b now later : Nat)
    (h : b ≠ a) :
    check p exempt (charge p exempt t a now) b later = check p exempt t b later := by
  simp only [check, lookup] at *
  have := charge_other p exempt t a b now h
  simp only [lookup] at this
  rw [this]

/-- The refusal's promise: retrying after the time it names is admitted (charges to other
subjects in between do not matter, by `charge_other`). -/
theorem check_retry_admits (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now r : Nat)
    (hr : check p exempt t subject now = .limited r) :
    check p exempt t subject (now + r) = .admit := by
  cases hx : exempt subject
  · cases hs : lookup t subject with
    | none => simp [check, hx, hs] at hr
    | some s =>
        by_cases hin : now < s.start + p.windowMs
        · by_cases hc : s.count < p.limit
          · simp [check, hx, hs, hin, hc] at hr
          · simp [check, hx, hs, hin, hc] at hr
            subst hr
            have : ¬ now + (s.start + p.windowMs - now) < s.start + p.windowMs := by omega
            simp [check, hx, hs, this]
        · simp [check, hx, hs, hin] at hr
  · simp [check, hx] at hr

/-- Exemption: an exempt subject is always admitted and never charged. -/
theorem check_exempt (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (hx : exempt subject = true) : check p exempt t subject now = .admit := by
  simp [check, hx]

theorem charge_exempt (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (hx : exempt subject = true) : charge p exempt t subject now = t := by
  simp [charge, hx]

/-- Teeth over a run: `limit` admitted-and-charged requests inside one window leave the subject
refused for the rest of it. -/
def chargeMany (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat) : Nat → Table
  | 0 => t
  | n + 1 => charge p exempt (chargeMany p exempt t subject now n) subject now

theorem chargeMany_slot (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now : Nat)
    (hx : exempt subject = false) (h : lookup t subject = none) (n : Nat) (hn : 0 < n) :
    lookup (chargeMany p exempt t subject now n) subject = some ⟨now, n⟩ := by
  induction n with
  | zero => omega
  | succ k ih =>
      cases k with
      | zero => simp [chargeMany, charge, hx, h, lookup_put_self]
      | succ j =>
          have ih' := ih (by omega)
          have hin : now < now + p.windowMs := by have := p.window_pos; omega
          simp only [chargeMany] at ih' ⊢
          rw [charge_in_window p exempt _ subject now _ hx ih' hin]

theorem limit_charges_refuse (p : Policy) (exempt : Nat → Bool) (t : Table) (subject now later : Nat)
    (hx : exempt subject = false) (h : lookup t subject = none)
    (hin : later < now + p.windowMs) :
    check p exempt (chargeMany p exempt t subject now p.limit) subject later =
      .limited (now + p.windowMs - later) := by
  have hs := chargeMany_slot p exempt t subject now hx h p.limit p.limit_pos
  exact (check_at_limit p exempt _ subject later ⟨now, p.limit⟩ hx hs hin (Nat.le_refl _)).1

/-! ## A concrete run (the satisfiable and teeth witnesses, by evaluation) -/

/-- Three per second; subject 9 is the exempt operator. -/
def demoPolicy : Policy := ⟨3, 1000, by decide, by decide⟩
def demoExempt (s : Nat) : Bool := s == 9

/-- Subject 7 at t = 0, 1, 2 (admitted, charged), at t = 3 (refused, 997 ms left), at
t = 1000 (admitted again); subject 8 at t = 3 is unaffected; the operator at t = 3 is admitted. -/
def witnessTable : Table :=
  charge demoPolicy demoExempt
    (charge demoPolicy demoExempt (charge demoPolicy demoExempt [] 7 0) 7 1) 7 2

theorem witness_run :
    check demoPolicy demoExempt [] 7 0 = .admit ∧
    check demoPolicy demoExempt witnessTable 7 3 = .limited 997 ∧
    check demoPolicy demoExempt witnessTable 7 1000 = .admit ∧
    check demoPolicy demoExempt witnessTable 8 3 = .admit ∧
    check demoPolicy demoExempt (chargeMany demoPolicy demoExempt [] 9 3 50) 9 3 = .admit := by
  decide

#assert_axioms check_fresh
#assert_axioms check_below_limit
#assert_axioms check_at_limit
#assert_axioms check_after_window
#assert_axioms charge_after_window
#assert_axioms charge_in_window
#assert_axioms charge_other
#assert_axioms check_forgery_free
#assert_axioms check_retry_admits
#assert_axioms check_exempt
#assert_axioms charge_exempt
#assert_axioms limit_charges_refuse
#assert_axioms witness_run

end Minidregg.Kernel.SubjectRate

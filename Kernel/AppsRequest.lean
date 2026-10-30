/-
# Kernel.AppsRequest — the app-install request law (docs/APP-MARKET-2026-10-27.md §3)

One declared cell is one member's request to run one signed Sandstorm package as a grain: the
member (the requester) states the package and the size class once; the hosting manager (the
operator's management subject) states the outcome once. This module is the law's **source**. The
shell template `native/resource-client/templates/apps/request/law.apps` is the Host's own rendering
of `law` (`LawLeaf.renderClause`) with the two parameters as placeholders, written by
`scripts/AppsRequestTemplate.lean`; `mini apps install` binds the placeholders and births the cell
under it, and `law show` prints an installed law back from the same renderer.

Fields (`fields.json`): 1 state (0 requested; 1 running; 2 refused), 2 packageHi and 3 packageLo
(the packageId, the first 16 bytes of the SPK's SHA-256, as two 64-bit words), 4–7 appId (the
signing key's 32-byte hash, as four 64-bit words), 8 class (1 S, 2 M, 3 L), 9 grain (the admitted
application resource, 0 until the manager writes it), 10 generation (the serving generation).

The guarantees, each a consequence of one clause:
* `choice_frozen_after_setup` — once set up, no admitted write moves the package, the appId or the
  class: the manager installs exactly what the member asked for, or nothing. Pole:
  `package_change_refused`.
* `outcome_once_by_manager` — the state moves only 0 → 1 or 0 → 2, only by the manager; a running
  outcome names a nonzero grain. Pole: `requester_cannot_decide`.
* `no_install_no_revoke` — the law admits no install and no revoke: neither the law nor the
  manager's observe grant can be withdrawn while the request stands.

The member's package choice is what this cell adds to the kernel's record of an install; the
application birth (op 30) and the hosting delegation are the other two statements, admitted by their
own receivers. No new operation byte is needed for any of the three.
-/
import Pred.HashEq
import Kernel.LawView

namespace Minidregg.Kernel.AppsRequest

open Minidregg.Pred (Pred State eval Slot)
open Minidregg.Kernel.LawView (ev_eq ev_le ev_eqSlots ev_leSlots ev_not ev_all ev_any)

set_option autoImplicit false

/-! ## §1. Slots, parameters, layout -/

def fA (n : Nat) : Slot := s!"resource/field/{n}/after"
def fB (n : Nat) : Slot := s!"resource/field/{n}/before"
def fD (n : Nat) : Slot := s!"resource/field/{n}/delta"
def subjectSlot : Slot := "request/subject"
def verbSlot : Slot := "request/verb"

/-- The placeholders of the template: the requester (the member) and the hosting manager. -/
structure Params where
  requester : Int
  manager : Int

/-- The member's choice: fields 2–8. -/
def choice : List Nat := [2, 3, 4, 5, 6, 7, 8]
/-- The manager's outcome: fields 1, 9, 10. -/
def outcome : List Nat := [1, 9, 10]

/-! ## §2. The law -/

/-- The write guard: a clause under it judges writes only (`LawLeaf.writeGuard`). -/
def guard : Pred := .not (.eq verbSlot 2)
/-- The request has been set up: field 1 was present before this write. -/
def setUp : Pred := .eqSlots (fB 1) (fB 1)
/-- The fields' deltas are all zero (each was present before and is unchanged). -/
def frozen (ns : List Nat) : Pred := Pred.all (ns.map fun n => .eq (fD n) 0)

/-- 0 management: reads and writes for any holder (the clauses below judge every write); the
requester delegates (the manager's observe grant); nobody installs (4) or revokes (5). -/
def management (p : Params) : Pred :=
  Pred.any [.eq verbSlot 1, .eq verbSlot 2, Pred.all [.eq verbSlot 3, .eq subjectSlot p.requester]]

/-- 1 setup, once, by the requester: state 0, the outcome fields 0, a nonzero package, a class in
{1, 2, 3}; then the choice is frozen. -/
def setup (p : Params) : Pred :=
  Pred.any [guard,
    Pred.all [.not setUp, .eq subjectSlot p.requester, .eq (fA 1) 0, .eq (fA 9) 0, .eq (fA 10) 0,
      Pred.any [.not (.eq (fA 2) 0), .not (.eq (fA 3) 0)],
      Pred.any [.eq (fA 8) 1, .eq (fA 8) 2, .eq (fA 8) 3]],
    Pred.all [setUp, frozen choice]]

/-- 2 outcome, once, by the manager: state 0 → 1 (running, with a nonzero grain) or 0 → 2
(refused); the grain and generation move only in that write. -/
def decision (p : Params) : Pred :=
  Pred.any [guard, .not setUp, frozen outcome,
    Pred.all [.eq subjectSlot p.manager, .eq (fB 1) 0,
      Pred.any [Pred.all [.eq (fA 1) 1, .not (.eq (fA 9) 0)], .eq (fA 1) 2]]]

def clauses (p : Params) : List Pred := [management p, setup p, decision p]

/-- The law of one request. -/
def law (p : Params) : Pred := Pred.all (clauses p)

/-- What each clause says, for the template's comment lines (one per clause, in order). -/
def notes : List String :=
  ["0 management: anyone holding a grant reads and writes (the clauses below judge every write); the requester delegates the manager's observe grant; nobody installs or revokes, so the law and the grants stand.",
   "1 setup, once, by the requester: state 0, grain and generation 0, a nonzero packageId (fields 2, 3), the appId (fields 4-7), a class 1 S / 2 M / 3 L (field 8); then the choice is frozen.",
   "2 outcome, once, by the manager: state 0 -> 1 running with a nonzero grain (field 9) and its generation (field 10), or 0 -> 2 refused; the outcome fields move in no other write."]

theorem notes_length : notes.length = (clauses ⟨0, 0⟩).length := by decide

/-! ## §3. Reading the law -/

section Reading
variable {p : Params} {o n : State}

theorem law_clause (h : eval (law p) o n = true) {q : Pred} (hq : q ∈ clauses p) :
    eval q o n = true :=
  ev_all.mp h q hq

/-- On a write to a set-up request, a guarded disjunction holds by one of its remaining branches. -/
theorem branch {rest : List Pred} (hw : n.get verbSlot = some 2) (hs : (n.get (fB 1)).isSome)
    (h : eval (Pred.any (guard :: .not setUp :: rest)) o n = true) :
    ∃ q ∈ rest, eval q o n = true := by
  obtain ⟨q, hq, hev⟩ := ev_any.mp h
  rcases List.mem_cons.mp hq with rfl | hq
  · exact absurd (ev_eq.mpr hw) (ev_not.mp hev)
  rcases List.mem_cons.mp hq with rfl | hq
  · exfalso; apply ev_not.mp hev; apply ev_eqSlots.mpr
    obtain ⟨x, hx⟩ := Option.isSome_iff_exists.mp hs; exact ⟨x, hx, hx⟩
  exact ⟨q, hq, hev⟩

theorem frozen_iff {ns : List Nat} :
    eval (frozen ns) o n = true ↔ ∀ m ∈ ns, n.get (fD m) = some 0 := by
  simp only [frozen, ev_all, List.mem_map, forall_exists_index, and_imp, forall_apply_eq_imp_iff₂,
    ev_eq]

end Reading

/-! ## §4. The guarantees -/

section Guarantees
variable {p : Params} {o n : State}

/-- **The choice is frozen.** An admitted write to a set-up request moves none of the package,
appId or class fields. -/
theorem choice_frozen_after_setup (h : eval (law p) o n = true) (hw : n.get verbSlot = some 2)
    (hs : (n.get (fB 1)).isSome) {m : Nat} (hm : m ∈ choice) : n.get (fD m) = some 0 := by
  have hr := law_clause h (q := setup p) (by simp [clauses])
  simp only [setup] at hr
  obtain ⟨q, hq, hev⟩ := ev_any.mp hr
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl | rfl
  · exact absurd (ev_eq.mpr hw) (ev_not.mp hev)
  · exfalso
    have hnot := (ev_all.mp hev) (.not setUp) (by simp)
    apply ev_not.mp hnot; apply ev_eqSlots.mpr
    obtain ⟨x, hx⟩ := Option.isSome_iff_exists.mp hs; exact ⟨x, hx, hx⟩
  · exact frozen_iff.mp ((ev_all.mp hev) (frozen choice) (by simp)) m hm

/-- Pole: a write to a set-up request that moves the package is refused. -/
theorem package_change_refused (hw : n.get verbSlot = some 2) (hs : (n.get (fB 1)).isSome)
    (moved : n.get (fD 2) ≠ some 0) : eval (law p) o n = false := by
  cases he : eval (law p) o n
  · rfl
  · exact absurd (choice_frozen_after_setup he hw hs (by simp [choice])) moved

/-- **The outcome is the manager's, once.** An admitted write to a set-up request that moves the
state is by the manager, from 0, to 1 with a nonzero grain or to 2. -/
theorem outcome_once_by_manager (h : eval (law p) o n = true) (hw : n.get verbSlot = some 2)
    (hs : (n.get (fB 1)).isSome) (moved : n.get (fD 1) ≠ some 0) :
    n.get subjectSlot = some p.manager ∧ n.get (fB 1) = some 0 ∧
      ((n.get (fA 1) = some 1 ∧ n.get (fA 9) ≠ some 0) ∨ n.get (fA 1) = some 2) := by
  have hr := law_clause h (q := decision p) (by simp [clauses])
  obtain ⟨q, hq, hev⟩ := branch hw hs hr
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl
  · exact absurd (frozen_iff.mp hev 1 (by simp [outcome])) moved
  · have hsub := (ev_all.mp hev) (.eq subjectSlot p.manager) (by simp)
    have hbefore := (ev_all.mp hev) (.eq (fB 1) 0) (by simp)
    have hany := (ev_all.mp hev)
      (Pred.any [Pred.all [.eq (fA 1) 1, .not (.eq (fA 9) 0)], .eq (fA 1) 2]) (by simp)
    refine ⟨ev_eq.mp hsub, ev_eq.mp hbefore, ?_⟩
    obtain ⟨b, hb, hbev⟩ := ev_any.mp hany
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hb
    rcases hb with rfl | rfl
    · have h1 := (ev_all.mp hbev) (.eq (fA 1) 1) (by simp)
      have h9 := (ev_all.mp hbev) (.not (.eq (fA 9) 0)) (by simp)
      exact Or.inl ⟨ev_eq.mp h1, fun z => ev_not.mp h9 (ev_eq.mpr z)⟩
    · exact Or.inr (ev_eq.mp hbev)

/-- Pole: the requester (or anyone but the manager) cannot decide the request. -/
theorem requester_cannot_decide (hw : n.get verbSlot = some 2) (hs : (n.get (fB 1)).isSome)
    (moved : n.get (fD 1) ≠ some 0) (who : n.get subjectSlot ≠ some p.manager) :
    eval (law p) o n = false := by
  cases he : eval (law p) o n
  · rfl
  · exact absurd (outcome_once_by_manager he hw hs moved).1 who

/-- **No install, no revoke.** The law refuses verbs 4 and 5 outright. -/
theorem no_install_no_revoke (h : eval (law p) o n = true) :
    n.get verbSlot ≠ some 4 ∧ n.get verbSlot ≠ some 5 := by
  have hm := law_clause h (q := management p) (by simp [clauses])
  obtain ⟨q, hq, hev⟩ := ev_any.mp hm
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl | rfl
  · have := ev_eq.mp hev; exact ⟨by simp [this], by simp [this]⟩
  · have := ev_eq.mp hev; exact ⟨by simp [this], by simp [this]⟩
  · have := ev_eq.mp ((ev_all.mp hev) (.eq verbSlot 3) (by simp))
    exact ⟨by simp [this], by simp [this]⟩

end Guarantees

end Minidregg.Kernel.AppsRequest

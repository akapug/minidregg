/-
# Assurance.StoryHistory -- no skip, no rewind, over the controller's own checked legs

`Assurance.StoryLaw.sealed_story_scene_monotone` is proved over `Kernel.LawHistory.Accepted`, a
model of a cell's write history judged by `LawView.admits`; no theorem identifies that model's
`LawView.view` with the state the Host's controller hands the policy (`DeclaredResourceController.step`).
The per-step `kernel_story_step` IS about the controller (a `CheckedLeg`). This file lifts the per-step
statement to histories, over the controller's states.

* `Realized t S n`: `n` is the `newState` of the controller's `step` for some `CheckedLeg` that is a
  write on a cell whose authenticated closure includes the sealed story law (`StoryInstalled`).
  `realized_step` gets `Step t S n` from `kernel_story_step`.
* `Chained`: consecutive legs link, scene and turn: the `after` slot of one leg equals the `before`
  slot of the next. This is the durable CAS (each pre is the previous post), a premise on the states.
* `Coherent n`: for the scene and turn fields, `delta = after - before`: the arithmetic of
  `DeclaredResourceProjection.scalarSlots`.

**Named residuals (premises, not proved here).** (R1) `Coherent (step ..).newState`: that the
controller's projection of a story cell fills `delta` as `after - before` is `scalarSlots`' definition
but is not yet connected through `projectWithCommon`/`participantSlots`. (R2) `Chained` for the
receiver's actual sequence of accepted writes (the CAS chain), and that the Host discharges
`StoryInstalled` (nothing in the Host calls `checkInstalled` yet). (R3) A concrete `CheckedLeg` on
the tale, inhabiting `Realized` (the premise-inhabitation of the controller side; the satisfiable pole
below inhabits every other premise). The main theorem is proved given these.
-/
import Assurance.StoryLaw

namespace Minidregg.Assurance.StoryHistory

open Minidregg.Pred (Pred State eval)
open Minidregg.Kernel.DeclaredResourceProjection (fieldName)
open Minidregg.Kernel.DeclaredResourceController
open Minidregg.Kernel.MultiCellHyperedge
open Minidregg.Compiler
open Minidregg.Assurance.StoryLaw
set_option autoImplicit false
set_option linter.unusedSimpArgs false

/-! ## §1. The premises, on the controller's states -/

/-- `n` is the new state of the controller's step for a checked write leg on a cell carrying the
sealed story law of `t` for player `S`. -/
def Realized (t : Table) (S : Int) (n : State) : Prop :=
  ∃ (F : Type) (_ : Field F) (_ : DecidableEq F) (deployment : Deployment)
    (profile : CanonicalRuntimeProfile.Profile F) (ambient : Ambient)
    (ground : Ground deployment) (command : Command)
    (prepared : PreparedInvocation deployment profile ambient ground command)
    (tuple : PreparedTuple (plan prepared)) (incidence : Incidence command) (envelope : List UInt8),
    Nonempty (CheckedLeg prepared tuple incidence envelope) ∧
    StoryInstalled t S tuple incidence ∧
    (step prepared tuple incidence).newState = n ∧
    n.get "request/verb" = some 2

theorem realized_step {t : Table} {S : Int} {n : State} (h : Realized t S n) : Step t S n := by
  obtain ⟨F, _, _, deployment, profile, ambient, ground, command, prepared, tuple, incidence,
    envelope, ⟨leg⟩, installed, rfl, w⟩ := h
  exact kernel_story_step t S leg installed w

/-- The scene (field 0) and turn (field 1) slots of a leg's state are an arithmetic row. -/
def Coherent (n : State) : Prop :=
  ∀ f : Nat, f ≤ 1 → ∃ b a : Int, n.get (fieldName f "before") = some b ∧
    n.get (fieldName f "after") = some a ∧ n.get (fieldName f "delta") = some (a - b)

/-- The next leg starts where the previous one ended. -/
def Links (n m : State) : Prop :=
  n.get (fieldName 0 "after") = m.get (fieldName 0 "before") ∧
  n.get (fieldName 1 "after") = m.get (fieldName 1 "before")

def Chained : List State → Prop
  | n :: m :: rest => Links n m ∧ Chained (m :: rest)
  | _ => True

/-! ## §2. The theorem -/

/-- **`story_history_monotone`.** For a chain of the controller's checked story legs that starts at
scene `a`, turn `k`: every leg is the player's, moves the scene along a table edge or not at all
(no skip), and raises the turn by exactly one, so the last leg ends at turn `k + length` (no
rewind). Generic over the leg predicate `R` that yields `Step` (`Realized` is the instance). -/
theorem story_history_monotone_of (t : Table) (S : Int) (R : State → Prop)
    (hR : ∀ n, R n → Step t S n) :
    ∀ (ns : List State) (a k : Int),
      (∀ n ∈ ns, R n) → (∀ n ∈ ns, Coherent n) → Chained ns →
      (∀ n, ns.head? = some n → n.get (fieldName 0 "before") = some a ∧
        n.get (fieldName 1 "before") = some k) →
      (∀ n ∈ ns, n.get "request/subject" = some S ∧ ∃ x y m : Int,
          n.get (fieldName 0 "before") = some x ∧ n.get (fieldName 0 "after") = some y ∧
          n.get (fieldName 1 "before") = some m ∧ n.get (fieldName 1 "after") = some (m + 1) ∧
          (y = x ∨ ∃ e ∈ t.edges, e.src = x ∧ e.dst = y)) ∧
      (∀ n, ns.getLast? = some n → n.get (fieldName 1 "after") = some (k + ns.length)) := by
  intro ns
  induction ns with
  | nil => intro a k _ _ _ _; exact ⟨fun n hn => by simp at hn, fun n hn => by simp at hn⟩
  | cons n rest ih =>
      intro a k hR' hCoh hCh hStart
      have hn := hR _ (hR' n (by simp))
      obtain ⟨b0, a0, hb0, ha0, hd0⟩ := hCoh n (by simp) 0 (by omega)
      obtain ⟨b1, a1, hb1, ha1, hd1⟩ := hCoh n (by simp) 1 (by omega)
      obtain ⟨hb0', hb1'⟩ := hStart n (by simp)
      have e0 : b0 = a := by rw [hb0] at hb0'; exact Option.some.inj hb0'
      have e1 : b1 = k := by rw [hb1] at hb1'; exact Option.some.inj hb1'
      have d1 : a1 = b1 + 1 := by
        have := hn.turn; rw [hd1] at this; have := Option.some.inj this; omega
      have scene : a0 = b0 ∨ ∃ e ∈ t.edges, n.get (fieldName 0 "before") = some e.src ∧
          n.get (fieldName 0 "after") = some e.dst := by
        rcases hn.scene with h | h
        · left; rw [hd0] at h; have := Option.some.inj h; omega
        · right; exact h
      have headFacts : n.get "request/subject" = some S ∧ ∃ x y m : Int,
          n.get (fieldName 0 "before") = some x ∧ n.get (fieldName 0 "after") = some y ∧
          n.get (fieldName 1 "before") = some m ∧ n.get (fieldName 1 "after") = some (m + 1) ∧
          (y = x ∨ ∃ e ∈ t.edges, e.src = x ∧ e.dst = y) := by
        refine ⟨hn.subject, b0, a0, b1, hb0, ha0, hb1, by rw [ha1, d1], ?_⟩
        rcases scene with h | ⟨e, he, h1, h2⟩
        · left; exact h
        · right
          refine ⟨e, he, ?_, ?_⟩
          · rw [hb0] at h1; exact (Option.some.inj h1).symm
          · rw [ha0] at h2; exact (Option.some.inj h2).symm
      cases rest with
      | nil =>
          refine ⟨?_, ?_⟩
          · intro m hm; simp at hm; subst hm; exact headFacts
          · intro m hm; simp at hm; subst hm; rw [ha1, d1, e1]; simp
      | cons m rest' =>
          obtain ⟨⟨l0, l1⟩, hCh'⟩ := hCh
          have hm0 : m.get (fieldName 0 "before") = some a0 := by rw [← l0, ha0]
          have hm1 : m.get (fieldName 1 "before") = some (k + 1) := by rw [← l1, ha1, d1, e1]
          obtain ⟨hall, hlast⟩ := ih a0 (k + 1)
            (fun x hx => hR' x (by simp [hx])) (fun x hx => hCoh x (by simp [hx])) hCh'
            (fun x hx => by simp at hx; subst hx; exact ⟨hm0, hm1⟩)
          refine ⟨?_, ?_⟩
          · intro x hx
            rcases List.mem_cons.mp hx with rfl | hx
            · exact headFacts
            · exact hall x hx
          · intro x hx
            have := hlast x (by simpa [List.getLast?_cons_cons] using hx)
            rw [this]; simp only [List.length_cons]; congr 1; push_cast; ring

theorem story_history_monotone (t : Table) (S : Int) (ns : List State) (a k : Int)
    (real : ∀ n ∈ ns, Realized t S n) (coh : ∀ n ∈ ns, Coherent n) (chain : Chained ns)
    (start : ∀ n, ns.head? = some n → n.get (fieldName 0 "before") = some a ∧
      n.get (fieldName 1 "before") = some k) :
    (∀ n ∈ ns, n.get "request/subject" = some S ∧ ∃ x y m : Int,
        n.get (fieldName 0 "before") = some x ∧ n.get (fieldName 0 "after") = some y ∧
        n.get (fieldName 1 "before") = some m ∧ n.get (fieldName 1 "after") = some (m + 1) ∧
        (y = x ∨ ∃ e ∈ t.edges, e.src = x ∧ e.dst = y)) ∧
    (∀ n, ns.getLast? = some n → n.get (fieldName 1 "after") = some (k + ns.length)) :=
  story_history_monotone_of t S (Realized t S) (fun _ h => realized_step h) ns a k real coh chain start

/-! ## §3. Poles on the tale (player 7)

Satisfiable: a four-leg play-through of `taleTable` meets every premise of
`story_history_monotone_of` with `R := Step` (the part of `Realized` this file can inhabit; (R3)
above is the controller side) and its conclusion says the last leg ends at turn 4.
Teeth: a skipped scene and a repeated turn are not `Step`s (so not `Realized`); a chain whose next
leg does not start where the last ended is not `Chained`; and dropping `Chained` is load-bearing:
two legs that are each lawful, coherent and correctly started, whose last turn is not `k + length`. -/

/-- A leg of player 7's cell: scene `x` to `y`, turn `m` to `m + b`; the slots the law reads. -/
def leg (x y m b : Int) : State :=
  ⟨[("request/subject", 7), ("request/verb", 2),
    (fieldName 0 "before", x), (fieldName 0 "after", y), (fieldName 0 "delta", y - x),
    (fieldName 1 "before", m), (fieldName 1 "after", m + b), (fieldName 1 "delta", b)]⟩

section LegGet
variable (x y m b : Int)

private theorem ne_sym {α : Type} {a c : α} (h : a ≠ c) : c ≠ a := fun e => h e.symm

theorem leg_subject : (leg x y m b).get "request/subject" = some 7 := by
  simp [leg, State.get]
theorem leg_verb : (leg x y m b).get "request/verb" = some 2 := by
  have h : "request/verb" ≠ "request/subject" := by decide
  simp [leg, State.get, h]
theorem leg_b0 : (leg x y m b).get (fieldName 0 "before") = some x := by
  have h1 : fieldName 0 "before" ≠ "request/subject" := by decide
  have h2 : fieldName 0 "before" ≠ "request/verb" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2]
theorem leg_a0 : (leg x y m b).get (fieldName 0 "after") = some y := by
  have h1 : fieldName 0 "after" ≠ "request/subject" := by decide
  have h2 : fieldName 0 "after" ≠ "request/verb" := by decide
  have h3 : fieldName 0 "after" ≠ fieldName 0 "before" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2, ne_sym h3]
theorem leg_d0 : (leg x y m b).get (fieldName 0 "delta") = some (y - x) := by
  have h1 : fieldName 0 "delta" ≠ "request/subject" := by decide
  have h2 : fieldName 0 "delta" ≠ "request/verb" := by decide
  have h3 : fieldName 0 "delta" ≠ fieldName 0 "before" := by decide
  have h4 : fieldName 0 "delta" ≠ fieldName 0 "after" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2, ne_sym h3, ne_sym h4]
theorem leg_b1 : (leg x y m b).get (fieldName 1 "before") = some m := by
  have h1 : fieldName 1 "before" ≠ "request/subject" := by decide
  have h2 : fieldName 1 "before" ≠ "request/verb" := by decide
  have h3 : fieldName 1 "before" ≠ fieldName 0 "before" := by decide
  have h4 : fieldName 1 "before" ≠ fieldName 0 "after" := by decide
  have h5 : fieldName 1 "before" ≠ fieldName 0 "delta" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2, ne_sym h3, ne_sym h4, ne_sym h5]
theorem leg_a1 : (leg x y m b).get (fieldName 1 "after") = some (m + b) := by
  have h1 : fieldName 1 "after" ≠ "request/subject" := by decide
  have h2 : fieldName 1 "after" ≠ "request/verb" := by decide
  have h3 : fieldName 1 "after" ≠ fieldName 0 "before" := by decide
  have h4 : fieldName 1 "after" ≠ fieldName 0 "after" := by decide
  have h5 : fieldName 1 "after" ≠ fieldName 0 "delta" := by decide
  have h6 : fieldName 1 "after" ≠ fieldName 1 "before" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2, ne_sym h3, ne_sym h4, ne_sym h5, ne_sym h6]
theorem leg_d1 : (leg x y m b).get (fieldName 1 "delta") = some b := by
  have h1 : fieldName 1 "delta" ≠ "request/subject" := by decide
  have h2 : fieldName 1 "delta" ≠ "request/verb" := by decide
  have h3 : fieldName 1 "delta" ≠ fieldName 0 "before" := by decide
  have h4 : fieldName 1 "delta" ≠ fieldName 0 "after" := by decide
  have h5 : fieldName 1 "delta" ≠ fieldName 0 "delta" := by decide
  have h6 : fieldName 1 "delta" ≠ fieldName 1 "before" := by decide
  have h7 : fieldName 1 "delta" ≠ fieldName 1 "after" := by decide
  simp [leg, State.get, ne_sym h1, ne_sym h2, ne_sym h3, ne_sym h4, ne_sym h5, ne_sym h6, ne_sym h7]
end LegGet

theorem coherent_leg (x y m : Int) : Coherent (leg x y m 1) := by
  intro f hf
  have : f = 0 ∨ f = 1 := by omega
  rcases this with rfl | rfl
  · exact ⟨x, y, leg_b0 .., leg_a0 .., leg_d0 ..⟩
  · exact ⟨m, m + 1, leg_b1 .., leg_a1 .., by simpa using leg_d1 x y m 1⟩

theorem step_leg_of_edge (x y m : Int) (e : Edge) (he : e ∈ taleTable.edges) (h1 : e.src = x)
    (h2 : e.dst = y) : Step taleTable 7 (leg x y m 1) :=
  ⟨leg_subject .., leg_d1 .., Or.inr ⟨e, he, by rw [leg_b0, h1], by rw [leg_a0, h2]⟩⟩

theorem step_leg_stay (x m : Int) : Step taleTable 7 (leg x x m 1) :=
  ⟨leg_subject .., leg_d1 .., Or.inl (by rw [leg_d0]; simp)⟩

/-- hallway to anteroom, take the key (the scene stays), anteroom to landing, landing to lamp room. -/
def play : List State := [leg 0 1 0 1, leg 1 1 1 1, leg 1 3 2 1, leg 3 4 3 1]

theorem play_chained : Chained play := by
  simp [play, Chained, Links, leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb]

theorem play_steps : ∀ n ∈ play, Step taleTable 7 n := by
  intro n hn
  simp only [play, List.mem_cons, List.not_mem_nil, or_false] at hn
  rcases hn with rfl | rfl | rfl | rfl
  · exact step_leg_of_edge 0 1 0 ⟨0, 1, none⟩ (by decide) rfl rfl
  · exact step_leg_stay 1 1
  · exact step_leg_of_edge 1 3 2 ⟨1, 3, some 0⟩ (by decide) rfl rfl
  · exact step_leg_of_edge 3 4 3 ⟨3, 4, none⟩ (by decide) rfl rfl

theorem play_coherent : ∀ n ∈ play, Coherent n := by
  intro n hn
  simp only [play, List.mem_cons, List.not_mem_nil, or_false] at hn
  rcases hn with rfl | rfl | rfl | rfl <;> exact coherent_leg _ _ _

/-- **Satisfiable.** Every premise of the history theorem holds of a real play-through, and its
conclusion is the expected one: the last leg ends at turn 4. -/
theorem history_satisfiable :
    play ≠ [] ∧ (∀ n ∈ play, Step taleTable 7 n) ∧ (∀ n ∈ play, Coherent n) ∧ Chained play ∧
    (∀ n, play.head? = some n → n.get (fieldName 0 "before") = some 0 ∧
      n.get (fieldName 1 "before") = some 0) ∧
    (∀ n, play.getLast? = some n → n.get (fieldName 1 "after") = some (0 + play.length)) := by
  refine ⟨by simp [play], play_steps, play_coherent, play_chained, ?_, ?_⟩
  · intro n hn; simp [play] at hn; subst hn; simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb]
  · intro n hn; simp [play] at hn; subst hn; simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb, play]

/-- **Teeth (skip).** Scene 0 straight to scene 3 is no `Step`, hence no `Realized`. -/
theorem skip_not_step : ¬ Step taleTable 7 (leg 0 3 0 1) := by
  rintro ⟨-, -, h⟩
  rcases h with h | ⟨e, he, h1, h2⟩
  · simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb] at h
  · simp only [taleTable, List.mem_cons, List.not_mem_nil, or_false] at he
    rcases he with rfl | rfl | rfl | rfl <;> simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb] at h1 h2

/-- **Teeth (repeat).** A leg that leaves the turn where it was is no `Step`. -/
theorem repeat_not_step : ¬ Step taleTable 7 (leg 0 1 0 0) := by
  rintro ⟨-, h, -⟩
  simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb] at h

/-- **Teeth (rewind).** A next leg that starts at an earlier turn is not linked. -/
theorem rewind_not_chained : ¬ Chained [leg 0 1 1 1, leg 1 2 0 1] := by
  simp [Chained, Links, leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb]

/-- **Teeth (the chain is load-bearing).** Two lawful, coherent, correctly started legs that do not
link: the history conclusion fails, so `Chained` cannot be dropped. -/
theorem unchained_breaks_conclusion :
    (∀ n ∈ [leg 0 1 0 1, leg 1 2 0 1], Step taleTable 7 n) ∧
    (∀ n ∈ [leg 0 1 0 1, leg 1 2 0 1], Coherent n) ∧
    ¬ Chained [leg 0 1 0 1, leg 1 2 0 1] ∧
    (∀ n, ([leg 0 1 0 1, leg 1 2 0 1] : List State).getLast? = some n →
      n.get (fieldName 1 "after") ≠ some (0 + ([leg 0 1 0 1, leg 1 2 0 1] : List State).length)) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro n hn
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hn
    rcases hn with rfl | rfl
    · exact step_leg_of_edge 0 1 0 ⟨0, 1, none⟩ (by decide) rfl rfl
    · exact step_leg_of_edge 1 2 0 ⟨1, 2, none⟩ (by decide) rfl rfl
  · intro n hn
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hn
    rcases hn with rfl | rfl <;> exact coherent_leg _ _ _
  · simp [Chained, Links, leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb]
  · intro n hn; simp at hn; subst hn; simp [leg_b0, leg_a0, leg_b1, leg_a1, leg_d0, leg_d1, leg_subject, leg_verb]


/-- info: 'Minidregg.Assurance.StoryHistory.realized_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms realized_step
/-- info: 'Minidregg.Assurance.StoryHistory.story_history_monotone_of' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms story_history_monotone_of
/-- info: 'Minidregg.Assurance.StoryHistory.story_history_monotone' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms story_history_monotone
/-- info: 'Minidregg.Assurance.StoryHistory.history_satisfiable' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms history_satisfiable
/-- info: 'Minidregg.Assurance.StoryHistory.skip_not_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms skip_not_step
/-- info: 'Minidregg.Assurance.StoryHistory.repeat_not_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms repeat_not_step
/-- info: 'Minidregg.Assurance.StoryHistory.rewind_not_chained' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms rewind_not_chained
/-- info: 'Minidregg.Assurance.StoryHistory.unchained_breaks_conclusion' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms unchained_breaks_conclusion

end Minidregg.Assurance.StoryHistory

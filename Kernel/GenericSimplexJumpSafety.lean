import Kernel.GenericSimplexObservationSafety

/-! Safety of the actual prepared-view entry used by `progressOuter`.
Selection and entry frames are parameter-independent. The reachable consensus
join below is deliberately restricted to the existing n = 3f+1 proof. -/
namespace Minidregg.Kernel.GenericSimplexJumpSafety
open Minidregg.Kernel.GenericSimplex
open Minidregg.Kernel.GenericSimplexLocal
open Minidregg.Kernel.GenericSimplexCausal
open Minidregg.Kernel.GenericSimplexPreparedHistory
open Minidregg.Kernel.GeneralSimplexReachability
open Minidregg.Kernel.GenericSimplexObservationSafety
set_option autoImplicit false

private def eligible (s : State) (n : Nat) : Prop :=
  s.current < n ∧ (viewAt s n).prepared ≠ []

private theorem prepared_fold (s : State) (ns : List Nat) (acc : Nat) :
    let result := ns.foldl
      (fun a n => if s.current < n && !(viewAt s n).prepared.isEmpty then max a n else a) acc
    acc ≤ result ∧
      (result = acc ∨ (result ∈ ns ∧ eligible s result)) ∧
      (∀ n ∈ ns, eligible s n → n ≤ result) := by
  induction ns generalizing acc with
  | nil => simp
  | cons n ns ih =>
    simp only [List.foldl_cons]
    by_cases good : s.current < n ∧ (viewAt s n).prepared ≠ []
    · have test : (s.current < n && !(viewAt s n).prepared.isEmpty) = true := by
        simp [good.1, good.2]
      rw [if_pos test]
      obtain ⟨lower, selected, upper⟩ := ih (max acc n)
      refine ⟨by omega, ?_, ?_⟩
      · rcases selected with same | ⟨member, valid⟩
        · by_cases order : n ≤ acc
          · exact Or.inl (by omega)
          · apply Or.inr
            rw [same, Nat.max_eq_right (by omega : acc ≤ n)]
            exact ⟨List.mem_cons_self, good⟩
        · exact Or.inr ⟨List.mem_cons_of_mem n member, valid⟩
      · intro m member valid
        rcases List.mem_cons.mp member with same | member
        · subst m; omega
        · exact upper m member valid
    · have test : (s.current < n && !(viewAt s n).prepared.isEmpty) = false := by
        simpa using good
      rw [if_neg (by simp [test])]
      obtain ⟨lower, selected, upper⟩ := ih acc
      refine ⟨lower, ?_, ?_⟩
      · rcases selected with same | ⟨member, valid⟩
        · exact Or.inl same
        · exact Or.inr ⟨List.mem_cons_of_mem n member, valid⟩
      · intro m member valid
        rcases List.mem_cons.mp member with same | member
        · subst m; exact False.elim (good valid)
        · exact upper m member valid

/-- Maximum, not merely some prepared view; no honest/provenance premise is
needed to establish what the executable selector computes. -/
theorem preparedAbove_spec (s : State) (jump : s.current < preparedAbove s) :
    preparedAbove s ∈ s.views.map View.number ∧
    (viewAt s (preparedAbove s)).prepared ≠ [] ∧
    ∀ n ∈ s.views.map View.number, s.current < n →
      (viewAt s n).prepared ≠ [] → n ≤ preparedAbove s := by
  obtain ⟨_, selected, upper⟩ := prepared_fold s (s.views.map View.number) 0
  change preparedAbove s = 0 ∨ _ at selected
  rcases selected with zero | ⟨member, valid⟩
  · omega
  · exact ⟨member, valid.2, fun n hn high nonempty => upper n hn ⟨high, nonempty⟩⟩

/-- Erase only the two fields a leader proposal may update. Every safety flag,
lock and prepared/committed value remains in this projection. -/
def safetyView (v : View) : View := {v with proposal := none, received := []}

private theorem putView_safety (s : State) (v : View)
    (same : safetyView v = safetyView (viewAt s v.number)) (n : Nat) :
    safetyView (viewAt (putView s v) n) = safetyView (viewAt s n) := by
  by_cases eq : n = v.number
  · subst n; rw [viewAt_put_same]; exact same
  · rw [viewAt_put_other s v n eq]

private theorem broadcast_safety (s : State) (n : Nat) (kind : Kind)
    (arg : Argument) (v : Nat) :
    safetyView (viewAt (broadcast s n kind arg) v) = safetyView (viewAt s v) := by
  apply putView_safety
  simp [safetyView, viewAt_number]

private theorem propose_safety (s : State) (n : Nat) :
    safetyView (viewAt (propose s) n) = safetyView (viewAt s n) := by
  unfold propose
  dsimp only
  split
  · rfl
  · split
    · split
      · exact (putView_safety _ _ (by simp [safetyView, viewAt_number]) n).trans
          (broadcast_safety s _ _ _ n)
      · exact broadcast_safety s _ _ _ n
    · rfl

theorem enterView_safety (c : Config) (s : State) (target n : Nat) :
    safetyView (viewAt (enterView c s target) n) = safetyView (viewAt s n) := by
  unfold enterView
  dsimp only
  split
  · exact (propose_safety _ n).trans (putView_safety _ _ (by simp [viewAt_number]) n)
  · exact putView_safety _ _ (by simp [viewAt_number]) n

private theorem propose_clock (s : State) :
    (propose s).current = s.current ∧ (propose s).deadline = s.deadline ∧
    (propose s).now = s.now ∧ (propose s).checked = s.checked ∧
    (propose s).delivered = s.delivered ∧ (propose s).committedTip = s.committedTip := by
  unfold propose
  dsimp only
  split_ifs <;> simp [broadcast, register, putView]

private theorem broadcast_other (s : State) (target : Nat) (kind : Kind)
    (arg : Argument) (n : Nat) (other : n ≠ target) :
    viewAt (broadcast s target kind arg) n = viewAt s n := by
  apply viewAt_put_other
  simpa only [viewAt_number] using other

private theorem propose_other (s : State) (n : Nat) (other : n ≠ s.current) :
    viewAt (propose s) n = viewAt s n := by
  unfold propose
  dsimp only
  split
  · rfl
  · split
    · split
      · exact (viewAt_put_other _ _ n (by
          simpa only [viewAt_number, GenericSimplexPositive.broadcast_current] using other)).trans
          (broadcast_other s _ _ _ n other)
      · exact broadcast_other s _ _ _ n other
    · rfl

/-- Skipped views are not marked disabled (or otherwise rewritten) by entry.
This also preserves non-safety data, such as their received messages. -/
theorem enterView_other (c : Config) (s : State) (target n : Nat) (other : n ≠ target) :
    viewAt (enterView c s target) n = viewAt s n := by
  unfold enterView
  dsimp only
  split
  · exact (propose_other _ n other).trans
      (viewAt_put_other _ _ n (by simpa only [viewAt_number] using other))
  · exact viewAt_put_other _ _ n (by simpa only [viewAt_number] using other)

/-- The actual enterView computes its deadline from the pre-entry state. -/
theorem enterView_clock (c : Config) (s : State) (target : Nat) :
    (enterView c s target).current = target ∧
    (enterView c s target).deadline = s.now + viewTimeout c s target ∧
    (enterView c s target).now = s.now ∧
    (enterView c s target).checked = s.checked ∧
    (enterView c s target).delivered = s.delivered ∧
    (enterView c s target).committedTip = s.committedTip := by
  unfold enterView
  dsimp only
  split
  · exact propose_clock _
  · exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- This is a decomposition of the executable definition, not a second outer
transition. `before` is the actual state after the ordinary outer rules and
immediately before the prepared-jump branch. -/
theorem progressOuter_entry (c : Config) (s : State)
    (old : GenericSimplexVoteOrigin.OriginInvariant s) :
    ∃ before, GenericSimplexVoteOrigin.OriginInvariant before ∧
      progressOuter c s =
        if before.current < preparedAbove before then
          enterView c before (preparedAbove before + 1) else before := by
  simp only [progressOuter, Id.run, bind, pure]
  repeat' first
    | (refine ⟨_, ?_, rfl⟩
       repeat' first
         | with_reducible apply GenericSimplexVoteOrigin.enterView_origin
         | with_reducible apply GenericSimplexVoteOrigin.propose_origin
         | (with_reducible apply GenericSimplexVoteOrigin.castVote_safe_origin
            rotate_left
            solve | simp_all)
         | (with_reducible apply GenericSimplexVoteOrigin.castVote_prepared_origin
            rotate_left
            solve | apply List.mem_of_head?; assumption)
         | assumption)
    | split

/-- Statement-first contract for the internal prepared entry. The frame is
field-level, not full-state equality: a real leader may emit a proposal. -/
structure PreparedEntrySafety (c : Config) (before after : State) : Prop where
  selected : preparedAbove before ∈ before.views.map View.number
  prepared : (viewAt before (preparedAbove before)).prepared ≠ []
  maximum : ∀ n ∈ before.views.map View.number, before.current < n →
    (viewAt before n).prepared ≠ [] → n ≤ preparedAbove before
  current : after.current = preparedAbove before + 1
  deadline : after.deadline = before.now + viewTimeout c before (preparedAbove before + 1)
  now : after.now = before.now
  checked : after.checked = before.checked
  delivered : after.delivered = before.delivered
  committedTip : after.committedTip = before.committedTip
  flags : ∀ n, safetyView (viewAt after n) = safetyView (viewAt before n)
  skipped : ∀ n, n ≠ preparedAbove before + 1 → viewAt after n = viewAt before n
  origin : GenericSimplexVoteOrigin.OriginInvariant after
  audit : GenericSimplexStructure.Preserves before after

/-- General safety of the exact internal branch; no finite state enumeration. -/
theorem prepared_entry_safe (c : Config) (s : State)
    (old : GenericSimplexVoteOrigin.OriginInvariant s)
    (jump : s.current < preparedAbove s) :
    PreparedEntrySafety c s (enterView c s (preparedAbove s + 1)) := by
  obtain ⟨selected, prepared, maximum⟩ := preparedAbove_spec s jump
  obtain ⟨current, deadline, now, checked, delivered, tip⟩ :=
    enterView_clock c s (preparedAbove s + 1)
  exact ⟨selected, prepared, maximum, current, deadline, now, checked, delivered, tip,
    enterView_safety c s _, enterView_other c s _,
    GenericSimplexVoteOrigin.enterView_origin c s _ old,
    GenericSimplexStructure.enterView_preserves c s _⟩

/-- The internal theorem is wired to `progressOuter` itself, including the
ordinary propose/vote/advance rules BEFORE the maximum-prepared lookup. -/
theorem progressOuter_jump_safety (c : Config) (s : State)
    (old : GenericSimplexVoteOrigin.OriginInvariant s) :
    ∃ before, GenericSimplexVoteOrigin.OriginInvariant before ∧
      progressOuter c s = (if before.current < preparedAbove before then
        enterView c before (preparedAbove before + 1) else before) ∧
      (before.current < preparedAbove before → PreparedEntrySafety c before (progressOuter c s)) := by
  obtain ⟨before, origin, actual⟩ := progressOuter_entry c s old
  refine ⟨before, origin, actual, ?_⟩
  intro jump
  rw [actual, if_pos jump]
  exact prepared_entry_safe c before origin jump

/-- Public reachability is post-pump. Quantifying a future prepared target at
that boundary can be vacuous because the pump already consumed the jump.
Instead this general closure uses the REAL AllowedInput/advance transition,
whose step contains the prepared jump, and derives its audit, vote origins and
commit/delivery safety. No caller supplies AuditRefinement or compatibility. -/
theorem reachable_step_safety {c : Config} {faulty : Finset Nat}
    {checked : Network → Nat → Block → Prop} {initialTime : Nat} {net : Network}
    (reachable : Reachable c faulty checked initialTime net)
    (size : c.parties = 3 * c.faults + 1) (faultBound : faulty.card ≤ c.faults)
    (party : Nat) (input : Input) (allowed : AllowedInput c faulty checked net party input) :
    let next := advance c faulty net party input
    Reachable c faulty checked initialTime next ∧
    AuditRefinement c faulty next ∧
    (∀ p, CausalInvariant (next.localState p)) ∧
    (∀ p, GenericSimplexVoteOrigin.OriginInvariant (next.localState p)) ∧
    (∀ p j b, p < c.parties → p ∉ faulty → b ∈ (viewAt (next.localState p) j).prepared →
      ∃ q t time, q < c.parties ∧ q ∉ faulty ∧ t < time ∧ time < next.audit.length ∧
        auditTrace next time = .prepare p j b ∧
        GenericSimplexVAInvariant.Sent (auditTrace next) t q j .vote (some b)) ∧
    (∀ p q v w a b, p < c.parties → q < c.parties → p ∉ faulty → q ∉ faulty →
      (viewAt (next.localState p) v).committed = some a →
      (viewAt (next.localState q) w).committed = some b → a.IsPrefix b ∨ b.IsPrefix a) ∧
    (∀ p q a b, p < c.parties → q < c.parties → p ∉ faulty → q ∉ faulty →
      a ∈ (next.localState p).delivered → b ∈ (next.localState q).delivered →
      a.IsPrefix b ∨ b.IsPrefix a) := by
  have next := Reachable.next reachable party input allowed
  refine ⟨next, actual_audit_refinement next size,
    GenericSimplexGlobalCausal.reachable_causal next,
    GenericSimplexGlobalVoteOrigin.reachable_origin next, ?_, ?_, ?_⟩
  · intro p j b pm ph prepared
    obtain ⟨q, t, time, honest, earlier, within, output, sent⟩ :=
      jump_target_has_honest_voter next size faultBound pm ph prepared
    have enrolled := (GenericSimplexGlobalCausal.honest_send_local next honest
      (GenericSimplexGlobalCausal.trace_send_member sent)).1
    exact ⟨q, t, time, enrolled, honest, earlier, within, output, sent⟩
  · intro p q v w a b pm qm ph qh left right
    exact actual_state_commits_compatible next size faultBound pm qm ph qh left right
  · intro p q a b pm qm ph qh left right
    exact actual_delivered_blocks_compatible next size faultBound pm qm ph qh left right

/-! Non-vacuity at the real authenticated public boundary. Parties 1 and 2
prepare view 1 using honest votes 0,1,2, then honestly vote for its extension in
view 2. Byzantine party 3 supplies only its own enrolled vote. Party 0 remains
in view 1 until its final delivery supplies Q=3 distinct view-2 votes. -/
private def jumpDelivery (receiver sender view : Nat) (kind : Kind) (block : Block) :
    Nat × Input := (receiver, .delivery ⟨sender, view, kind, some block⟩)

def jumpSchedule : List (Nat × Input) :=
  [(0, .offer [1]), (0, .checked [[1]]), (0, .checked [[1], [2]]),
   (1, .checked [[1]]), (1, .checked [[1], [2]]), (1, .offer [2]),
   (2, .checked [[1]]), (2, .checked [[1], [2]]),
   jumpDelivery 1 0 1 .propose [[1]], jumpDelivery 2 0 1 .propose [[1]],
   jumpDelivery 1 0 1 .vote [[1]], jumpDelivery 2 0 1 .vote [[1]],
   jumpDelivery 1 2 1 .vote [[1]], jumpDelivery 2 1 1 .vote [[1]],
   jumpDelivery 2 1 2 .propose [[1], [2]],
   jumpDelivery 0 1 2 .vote [[1], [2]], jumpDelivery 0 2 2 .vote [[1], [2]]]

def jumpBefore : Network :=
  (runChecked poleConfig poleFaulty (initial poleConfig 0) jumpSchedule).getD
    (initial poleConfig 0)

def jumpInput : Input := .delivery ⟨3, 2, .vote, some [[1], [2]]⟩
def jumpAfter : Network := advance poleConfig poleFaulty jumpBefore 0 jumpInput

theorem jumpSchedule_admitted :
    (runChecked poleConfig poleFaulty (initial poleConfig 0) jumpSchedule).isSome = true := by
  decide +kernel

theorem jumpBefore_reachable : Reachable poleConfig poleFaulty poleChecked 0 jumpBefore := by
  unfold jumpBefore
  rcases run : runChecked poleConfig poleFaulty (initial poleConfig 0) jumpSchedule with _ | result
  · have admitted := jumpSchedule_admitted
    rw [run] at admitted
    simp at admitted
  · exact runChecked_reachable jumpSchedule _ result .initial run

theorem jumpInput_allowed : AllowedInput poleConfig poleFaulty poleChecked jumpBefore 0 jumpInput := by
  exact allowedB_sound (by decide +kernel)

/-- The inhabitation witness is a test, NOT the general safety proof above.
The one missing vote causes a real 1 -> 3 jump, retaining the prepared block. -/
theorem jump_nonvacuous :
    (jumpBefore.localState 0).current = 1 ∧
    count (viewAt (jumpBefore.localState 0) 2) .vote (some [[1], [2]]) = 2 ∧
    (jumpAfter.localState 0).current = 3 ∧
    [[1], [2]] ∈ (viewAt (jumpAfter.localState 0) 2).prepared := by
  decide +kernel

/-- These non-3f+1 committee sizes are OUTSIDE the proved reachable safety
chain, even though their n-f/2f+1 arithmetic is meaningful. -/
theorem nf_sizes_outside_legacy (c : Config)
    (nf : c.parties = 5 ∨ c.parties = 6 ∨ c.parties = 8) :
    c.parties ≠ 3 * c.faults + 1 ∧ c.wellFormed = false := by
  have different : c.parties ≠ 3 * c.faults + 1 := by omega
  exact ⟨different, by simp [Config.wellFormed, different]⟩

#assert_axioms preparedAbove_spec
#assert_axioms enterView_safety
#assert_axioms enterView_other
#assert_axioms enterView_clock
#assert_axioms progressOuter_entry
#assert_axioms prepared_entry_safe
#assert_axioms progressOuter_jump_safety
#assert_axioms reachable_step_safety
#assert_axioms nf_sizes_outside_legacy
#assert_axioms jumpSchedule_admitted
#assert_axioms jumpBefore_reachable
#assert_axioms jumpInput_allowed
#assert_axioms jump_nonvacuous
end Minidregg.Kernel.GenericSimplexJumpSafety

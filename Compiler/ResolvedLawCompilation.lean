/-
# Compiler.ResolvedLawCompilation -- the effective-law lowering seam

The existing CanonicalPolicyAdmission verifier and this adapter share the one
compiledLawAccepts check. The root source address remains witness.address;
resolution/manifest authenticity and durable guards are receiving obligations.
This module intentionally returns no Authorized from a graph alone.
-/
module

public import Compiler.CanonicalPolicyAdmission

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

namespace Minidregg.Compiler.ResolvedLawCompilation

open Minidregg.Pred
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.LawComposition
open Minidregg.Compiler.CanonicalPolicyAdmission

set_option autoImplicit false

/-- Canonical presentation order fixes witness coordinates without changing the
intersection semantics. The source root's digest is kept separately. -/
def predicate {input : GraphInput} (resolved : ResolvedDAG input) : Pred :=
  effective (canonicalOrder resolved.postorder)

def witness {F : Type} [Field F] [DecidableEq F]
    (profile : CompilerProfile) {input : GraphInput} (resolved : ResolvedDAG input)
    (sourceAddress : Digest) (oldState newState : State) : CompiledPolicyWitness F where
  address := sourceAddress
  oldState := oldState
  newState := newState
  auxiliary := wit profile (predicate resolved) oldState newState

/-- `witness` as compiled: the auxiliary assignment closes over the two state indexes,
built once per witness (here the result is a structure, so the bindings are not moved under
the assignment's lambda by eta-expansion). -/
def witnessFast {F : Type} [Field F] [DecidableEq F]
    (profile : CompilerProfile) {input : GraphInput} (resolved : ResolvedDAG input)
    (sourceAddress : Digest) (oldState newState : State) : CompiledPolicyWitness F :=
  let oldIndexed := indexState oldState
  let newIndexed := indexState newState
  { address := sourceAddress
    oldState := oldState
    newState := newState
    auxiliary := witIndexed profile (predicate resolved) oldIndexed newIndexed }

@[csimp] theorem witness_eq_fast : @witness = @witnessFast := by
  funext F _ _ profile input resolved sourceAddress oldState newState
  unfold witness witnessFast
  dsimp only
  rw [wit_eq_indexed]

/-- The closure identity must be authenticated by the receiving constructor;
it is never substituted for the policy membership address. -/
structure Witness (F : Type) where
  compiled : CompiledPolicyWitness F
  closureDigest : Digest

def checks {F : Type} [Field F] [DecidableEq F]
    (profile : PolicyCompilerProfile F) {input : GraphInput} (resolved : ResolvedDAG input)
    (sourceAddress expectedClosure : Digest) (supplied : Witness F) : Bool :=
  decide (supplied.compiled.address = sourceAddress) &&
  decide (supplied.closureDigest = expectedClosure) &&
  compiledLawAccepts profile (predicate resolved) supplied.compiled

theorem checks_sound {F : Type} [Field F] [DecidableEq F]
    (profile : PolicyCompilerProfile F) {input : GraphInput} (resolved : ResolvedDAG input)
    (sourceAddress expectedClosure : Digest) (supplied : Witness F)
    (accepted : checks profile resolved sourceAddress expectedClosure supplied = true) :
    supplied.compiled.address = sourceAddress ∧
    supplied.closureDigest = expectedClosure ∧
    Minidregg.Pred.eval (predicate resolved) supplied.compiled.oldState supplied.compiled.newState = true := by
  simp only [checks, Bool.and_eq_true, decide_eq_true_eq] at accepted
  exact ⟨accepted.1.1, accepted.1.2,
    compiledLawAccepts_sound profile (predicate resolved) supplied.compiled accepted.2⟩

/-- Even a valid root membership address cannot select a different closure. -/
theorem wrong_closure_refused {F : Type} [Field F] [DecidableEq F]
    (profile : PolicyCompilerProfile F) {input : GraphInput} (resolved : ResolvedDAG input)
    (sourceAddress expectedClosure : Digest) (supplied : Witness F)
    (wrong : supplied.closureDigest ≠ expectedClosure) :
    checks profile resolved sourceAddress expectedClosure supplied = false := by
  simp [checks, wrong]

end Minidregg.Compiler.ResolvedLawCompilation

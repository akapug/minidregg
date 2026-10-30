/-
# Theory.CollisionFloor — the global collision floor is true at every fixed-width digest

`HashBytes.Collision H` and `AuthTrie.Collision dig` ask for two different inputs
with one digest, anywhere in an infinite input type. At a digest of fixed width
that always exists (pigeonhole), so a theorem whose conclusion is `P ∨ Collision`
at such a digest proves nothing about `P`. This module exhibits that, as theorems
rather than prose:

* `HashBytes.collision_of_fixed_width` — any byte hash of constant output width
  collides; `collision_of_cshake256Bytes` — so does the deployed cSHAKE256 under
  every customization (the `∨ Collision (cshake256Bytes tag)` conclusions of
  `Kernel.DomainEpoch` are therefore vacuous as stated).
* `AuthTrie.collision_of_finite_digest` — any node digest into a finite type
  collides once keys are infinite (so `Theory.AuthTrie` ends its soundness
  theorems in `CollisionAmong` over the nodes the verification hashed instead).

These are the teeth of the restatement (backlog O18): each restated theorem's
floor is a collision among finitely many named inputs, which pigeonhole does not
supply.
-/
import Mathlib.Data.Fintype.EquivFin
import Mathlib.Data.Fintype.Pigeonhole
import Theory.AuthTrie
import Theory.HashBytes
import Theory.Sp800185Cshake256Spec

namespace Minidregg.Theory.CollisionFloor

open Minidregg.Theory

/-- A byte hash whose outputs all have width `n` has a collision. -/
theorem HashBytes.collision_of_fixed_width (H : HashBytes.Hash) (n : Nat)
    (width : ∀ a, (H a).length = n) : HashBytes.Collision H := by
  let f : List UInt8 → Fin (256 ^ n) := fun a =>
    ⟨HashBytes.ofBE (H a), by simpa [width a] using HashBytes.ofBE_lt (H a)⟩
  obtain ⟨a, b, ne, eq⟩ := Finite.exists_ne_map_eq_of_infinite f
  exact ⟨a, b, ne, congrArg Fin.val eq⟩

/-- The deployed cSHAKE256 collides under every customization: `∨ Collision
(cshake256Bytes tag)` is true outright. -/
theorem collision_of_cshake256Bytes (customization : List UInt8) :
    HashBytes.Collision (Compiler.Sp800185Cshake256.cshake256Bytes customization) :=
  HashBytes.collision_of_fixed_width _ 32
    (Compiler.Sp800185Cshake256.cshake256Bytes_length customization)

/-- A node digest into a finite type collides as soon as keys are infinite. -/
theorem AuthTrie.collision_of_finite_digest {K V D : Type} [Finite D] [Infinite K] [Nonempty V]
    (dig : AuthTrie.NodeIn K V D → D) : AuthTrie.Collision dig := by
  obtain ⟨v⟩ := ‹Nonempty V›
  obtain ⟨a, b, ne, eq⟩ :=
    Finite.exists_ne_map_eq_of_infinite (fun k : K => dig (.leaf k v))
  exact ⟨.leaf a v, .leaf b v, by simpa using ne, eq⟩

/-- info: 'Minidregg.Theory.CollisionFloor.collision_of_cshake256Bytes' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms collision_of_cshake256Bytes
/-- info: 'Minidregg.Theory.CollisionFloor.AuthTrie.collision_of_finite_digest' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms AuthTrie.collision_of_finite_digest

end Minidregg.Theory.CollisionFloor

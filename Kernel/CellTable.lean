/-
# Kernel.CellTable — the cell table: one ordered map from cell id to canonical bytes

A checkpoint state, a resumed snapshot and a World checkpoint all hold "every
enumerable cell with its current bytes". As a `List (CellId × List UInt8)` each
lookup is a walk (`Seed.lookup`), and a snapshot built over it layers one
closure per install. This module is the one representation they share:

* `CellTable` is `Std.ExtTreeMap Nat (List UInt8) compare`, keyed by the cell
  id's value. The EXTENSIONAL tree map: two tables with the same lookups are
  EQUAL (`ext`), so a codec's `decode ∘ encode = id` is an equation of values,
  not of tree shapes.
* `ofList` keeps the FIRST entry for an id, exactly `Seed.lookup`'s discipline
  (`get_ofList`): a list with a duplicated id means what `Seed.lookup` says it
  means, never something a later entry overwrites.
* `entries` is the canonical stream: ascending id, one entry per id
  (`entries_ascending`), and `ofList (entries t) = t` (`ofList_entries`).
-/
module

public import Kernel.DurableReceiver
public import Theory.AxiomPin
public import Std.Data.ExtTreeMap

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

namespace Minidregg.Kernel

open Minidregg.Kernel.DurableDataIntent (CellId)
open Minidregg.Kernel.DurableReceiver (Seed)
open Minidregg.Theory.TypedAuthorization (Digest)

set_option autoImplicit false

/-- Cell id value ↦ canonical bytes. -/
abbrev CellTable := Std.ExtTreeMap Nat (List UInt8) compare

namespace CellTable

/-- The bytes a table holds for a cell. -/
def get (table : CellTable) (cellId : CellId) : Option (List UInt8) :=
  table[cellId.value]?

/-- Install a cell's bytes (a later write replaces an earlier one). -/
def insert (table : CellTable) (cellId : CellId) (bytes : List UInt8) : CellTable :=
  Std.ExtTreeMap.insert table cellId.value bytes

/-- First entry wins, as `Seed.lookup` reads a cell list. -/
def ofList (cells : List (CellId × List UInt8)) : CellTable :=
  cells.foldl (fun table cell => table.insertIfNew cell.1.value cell.2) ∅

/-- The canonical stream: ascending id, one entry per id. -/
def entries (table : CellTable) : List (CellId × List UInt8) :=
  table.toList.map fun entry => (⟨entry.1⟩, entry.2)

theorem get_insert (table : CellTable) (cellId other : CellId) (bytes : List UInt8) :
    (table.insert cellId bytes).get other =
      if cellId = other then some bytes else table.get other := by
  unfold get insert
  rw [Std.ExtTreeMap.getElem?_insert]
  by_cases same : cellId = other
  · subst same; simp
  · have : cellId.value ≠ other.value := fun h => same (by cases cellId; cases other; simp_all)
    simp [this, same]

private theorem foldl_getElem? (cells : List (CellId × List UInt8)) (table : CellTable) (key : Nat) :
    (cells.foldl (fun table cell => table.insertIfNew cell.1.value cell.2) table)[key]? =
      table[key]?.or (Seed.lookup cells ⟨key⟩) := by
  induction cells generalizing table with
  | nil => simp [Seed.lookup]
  | cons cell rest ih =>
      obtain ⟨⟨identifier⟩, bytes⟩ := cell
      rw [List.foldl_cons, ih, Std.ExtTreeMap.getElem?_insertIfNew]
      simp only [Seed.lookup, Digest.mk.injEq, Nat.compare_eq_eq, Std.ExtTreeMap.mem_iff_isSome_getElem?]
      by_cases same : identifier = key
      · subst same
        cases table[identifier]? <;> simp
      · simp [same]

/-- **The table reads a cell list as `Seed.lookup` does.** -/
theorem get_ofList (cells : List (CellId × List UInt8)) (cellId : CellId) :
    (ofList cells).get cellId = Seed.lookup cells cellId := by
  unfold get ofList
  rw [foldl_getElem?, Std.ExtTreeMap.getElem?_empty, Option.none_or]

private theorem lookup_entries (list : List (Nat × List UInt8))
    (distinct : list.Pairwise (fun a b => ¬ compare a.1 b.1 = .eq)) (key : Nat) :
    Seed.lookup (list.map fun entry => ((⟨entry.1⟩ : CellId), entry.2)) ⟨key⟩ =
      (list.find? fun entry => compare entry.1 key == .eq).map Prod.snd := by
  induction list with
  | nil => rfl
  | cons head rest ih =>
      obtain ⟨identifier, bytes⟩ := head
      by_cases same : identifier = key
      · subst same
        simp [Seed.lookup]
      · have differs : (compare identifier key == Ordering.eq) = false := by simp [same]
        simp only [List.map_cons, Seed.lookup, Digest.mk.injEq, same, ↓reduceIte, List.find?_cons,
          differs]
        exact ih (List.pairwise_cons.mp distinct).2

/-- **The canonical stream reads back as the table.** -/
theorem get_entries (table : CellTable) (cellId : CellId) :
    Seed.lookup table.entries cellId = table.get cellId := by
  obtain ⟨key⟩ := cellId
  unfold entries get
  rw [lookup_entries _ Std.ExtTreeMap.distinct_keys_toList]
  cases found : table[key]? with
  | none =>
      have absent : ¬ key ∈ table := by
        rw [Std.ExtTreeMap.mem_iff_isSome_getElem?, found]; simp
      rw [(Std.ExtTreeMap.find?_toList_eq_none_iff_not_mem).mpr absent]; rfl
  | some bytes =>
      have present : key ∈ table := by
        rw [Std.ExtTreeMap.mem_iff_isSome_getElem?, found]; rfl
      rw [(Std.ExtTreeMap.find?_toList_eq_some_iff_getKey?_eq_some_and_getElem?_eq_some
        (k' := key)).mpr ⟨Std.ExtTreeMap.getKey?_eq_some present, found⟩]; rfl

/-- **Decode ∘ encode = id**: the table rebuilt from its canonical stream is
the same table (an equation, by extensionality). -/
theorem ofList_entries (table : CellTable) : ofList table.entries = table := by
  apply Std.ExtTreeMap.ext_getElem?
  intro key
  have := get_ofList table.entries ⟨key⟩
  rw [get_entries] at this
  exact this

/-- **The stream is ascending**: strictly increasing ids, hence one entry per id. -/
theorem entries_ascending (table : CellTable) :
    (table.entries.map fun entry => entry.1.value).Pairwise (· < ·) := by
  unfold entries
  rw [List.map_map]
  have ordered := Std.ExtTreeMap.ordered_keys_toList (t := table)
  rw [List.pairwise_map]
  exact ordered.imp fun lt => by simpa [Nat.compare_eq_lt] using lt

#assert_axioms get_insert
#assert_axioms get_ofList
#assert_axioms get_entries
#assert_axioms ofList_entries
#assert_axioms entries_ascending

end CellTable

end Minidregg.Kernel

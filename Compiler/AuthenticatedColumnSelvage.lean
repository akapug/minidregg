/-
# Compiler.AuthenticatedColumnSelvage -- the controller-to-Selvage commitment adapter

The authenticated-column controller (`Compiler.AuthenticatedColumnPlan`) and the
cSHAKE Merkle backend (`Compiler.Tower256CshakeMerkleController`) carry no Selvage
import: the deployed Host reaches them for codecs and the XOF call, and must not
drag the proof system into its build. This module is where their commitment
schemes become Selvage opening schemes and binding commitments, literally (no
root, index, value or proof codec changes), for the proof-carrying consumers.
-/
import Compiler.Tower256CshakeMerkleController
import Selvage.Commitment

namespace Minidregg.Compiler.AuthenticatedColumnPlan

open Minidregg.Compiler.NativeKernelPlan (WorkKind)
open Minidregg.Compiler.SemanticManifest
open Minidregg.Selvage
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization (Digest)

set_option autoImplicit false

/-- Literal adapter from the controller's executable scheme to Selvage's opening
relation. No root, index, value, or proof codec is changed. -/
def CommitmentScheme.toSelvageOpeningScheme
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    (scheme : CommitmentScheme port) :
    OpeningScheme Digest Representation Domain (List UInt8) where
  commit := scheme.commit
  openAt := scheme.openAt
  verifyOpen := fun root index value proof =>
    scheme.verifyOpening root index value proof = true
  verifyOpen_commit := scheme.verifyOpening_commit

/-- A binding authenticated-column scheme is exactly a Selvage binding
commitment. This closes the formerly duplicated commitment interface between
controller transcripts and proof-carrying history. -/
def BindingCommitmentScheme.toSelvage
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    (scheme : BindingCommitmentScheme port) :
    BindingCommitment Digest Representation Domain (List UInt8) where
  toOpeningScheme := scheme.toCommitmentScheme.toSelvageOpeningScheme
  binding := scheme.binding

@[simp] theorem BindingCommitmentScheme.toSelvage_commit
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    (scheme : BindingCommitmentScheme port)
    (column : Domain -> Representation) :
    scheme.toSelvage.commit column = scheme.commit column :=
  rfl

@[simp] theorem BindingCommitmentScheme.toSelvage_openAt
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    (scheme : BindingCommitmentScheme port)
    (column : Domain -> Representation) (index : Domain) :
    scheme.toSelvage.openAt column index = scheme.openAt column index :=
  rfl

theorem BindingCommitmentScheme.toSelvage_verifyOpen_iff
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    (scheme : BindingCommitmentScheme port)
    (root : Digest) (index : Domain) (value : Representation)
    (proof : List UInt8) :
    scheme.toSelvage.verifyOpen root index value proof <->
      scheme.verifyOpening root index value proof = true :=
  Iff.rfl

/-- A controller-accepted opening is the identical Selvage opening relation for
the adapted scheme. -/
theorem ColumnOpening.verifiesInSelvage
    {Semantic Representation Domain : Type}
    {port : ColumnPort Semantic Representation Domain}
    {scheme : CommitmentScheme port}
    {column : BoundColumn port scheme}
    (opening : ColumnOpening column) :
    scheme.toSelvageOpeningScheme.verifyOpen column.root opening.index
      opening.representationValue opening.proofBytes :=
  opening.verified

namespace Tower256Example

theorem towerBinding_toSelvage_commit_exact
    (column : SingletonDomain -> Tower256Value) :
    towerBindingCommitment.toSelvage.commit column =
      towerCommitment.commit column :=
  rfl

end Tower256Example

/-- info: 'Minidregg.Compiler.AuthenticatedColumnPlan.Tower256Example.towerBinding_toSelvage_commit_exact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms Tower256Example.towerBinding_toSelvage_commit_exact

end Minidregg.Compiler.AuthenticatedColumnPlan

namespace Minidregg.Compiler.Tower256CshakeMerkleController

open Minidregg.Compiler.AuthenticatedColumnPlan
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.TypedAuthorization (Digest)

set_option autoImplicit false

variable {Semantic Representation : Type} {k : Nat}

/-- The controller and Selvage consume literally the same Merkle root function. -/
theorem bindingMerkle_toSelvage_commit_exact
    {cshake : Cshake256} (domains : MerkleDomains cshake)
    (port : ColumnPort Semantic Representation (Fin (2 ^ k)))
    (binding : (merkleCommitmentScheme domains port).PositionBinding)
    (column : Fin (2 ^ k) -> Representation) :
    (bindingMerkleCommitmentScheme domains port binding).toSelvage.commit column =
      (merkleCommitmentScheme domains port).commit column :=
  rfl

/-- info: 'Minidregg.Compiler.Tower256CshakeMerkleController.bindingMerkle_toSelvage_commit_exact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms bindingMerkle_toSelvage_commit_exact

end Minidregg.Compiler.Tower256CshakeMerkleController

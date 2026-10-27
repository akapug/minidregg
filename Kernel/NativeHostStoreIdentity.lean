/-
The Store identity that names a deployment's physical residue on a host: the
resident units (`ApplicationLifecycleResidentProfile.unitName`), volume images,
mounts, witnesses, slices and the grain world root all carry `storeTag` of it.
It binds the genesis seed identity AND the Store's root directory, so two worlds
that share a genesis and live at different roots on one host never share a tag:
two deployments from one provisioner domain (docs/evidence/2026-09-30-grain-running,
"the volumes were not fresh"), a restored world template, a fork
(docs/review/2026-10-27-genesis-coupling §D). A Store restored or forked to a new
root takes a fresh tag by construction, with no nonce for a copy tool to mint; a
Store moved to a new root is, to the platform, a new Store. The seed alone, the
identity before this module, named every such pair alike.
-/
import Kernel.NativeHostContext
import Kernel.ApplicationLifecycleResidentProfile

namespace Minidregg.Kernel.NativeHost

open Minidregg.Theory.TypedAuthorization (Digest)

/-- The cSHAKE customization: a fixed label, then the Store root's UTF-8. -/
def storeIdentityCustomization (storeRoot : String) : List UInt8 :=
  "DREGG.NATIVE-HOST.STORE-IDENTITY/v1;root=".toUTF8.toList ++ storeRoot.toUTF8.toList

/-- The Store identity of a genesis seed identity at a Store root. -/
def storeIdentity (seed : Digest) (storeRoot : String) : Digest :=
  (Minidregg.Compiler.Sp800185Cshake256.hash (storeIdentityCustomization storeRoot)
    (Minidregg.Compiler.Sp800185Cshake256.digestBytesLE seed)).digest

/-- The deployed Host's Store identity: its genesis seed identity at its Store
root (`Settings.storageRoot`, rewritten when a Store is restored elsewhere). -/
def Config.storeIdentity (config : Config) : Digest :=
  Minidregg.Kernel.NativeHost.storeIdentity config.expectedSeed config.storage.root.toString

/-- Two roots whose UTF-8 differs reach the hash as different customizations:
the label is a fixed prefix, so the roots come back byte for byte. The hash's
collision resistance is the assumption the identity then rests on, exactly as
`seedIdentity` and `storeTag` already do
(`ApplicationLifecycleResidentProfile.unitName_collides`). -/
theorem storeIdentityCustomization_separates_roots (a b : String)
    (same : storeIdentityCustomization a = storeIdentityCustomization b) :
    a.toUTF8.toList = b.toUTF8.toList :=
  List.append_cancel_left same

/-- Satisfiable, by computation: one genesis seed at two roots is two Stores with
two tags, the pair the seed-only identity named identically. -/
theorem storeTag_separates_two_roots_of_one_seed :
    ApplicationLifecycleResidentProfile.storeTag (storeIdentity ⟨7⟩ "/var/lib/mini/a") ≠
      ApplicationLifecycleResidentProfile.storeTag (storeIdentity ⟨7⟩ "/var/lib/mini/b") := by
  native_decide

end Minidregg.Kernel.NativeHost

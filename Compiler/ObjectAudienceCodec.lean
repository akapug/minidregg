module

public import Theory.ObjectAudience
public import Compiler.StoreCodec

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

namespace Minidregg.Compiler.ObjectAudienceCodec
open Minidregg.Theory.ObjectAudience
open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
set_option autoImplicit false

/-- A structural sum encodes modes canonically; invalid mode tags fail decoding. -/
def modeStream : StreamCodec Mode :=
  StreamCodec.xmap (StreamCodec.sum StoreCodec.unitStream StoreCodec.unitStream)
    (fun mode => match mode with | .active => .inl () | .frozen => .inr ())
    (fun mode => match mode with | .inl _ => .active | .inr _ => .frozen)
    (by intro mode; cases mode <;> rfl)

def stateStream : StreamCodec State :=
  StreamCodec.xmap
    (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
      (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat (StreamCodec.product modeStream (StreamCodec.product StreamCodec.nat StreamCodec.nat))))))))))
    (fun state => (state.object, state.epoch, state.parent, state.transition,
      state.audience, state.devices, state.history, state.manifest, state.mode, state.authoritySnapshot, state.deviceSnapshot))
    (fun (object, epoch, parent, transition, audience, devices, history, manifest, mode, authoritySnapshot, deviceSnapshot) =>
      ⟨object, epoch, parent, transition, audience, devices, history, manifest, mode, authoritySnapshot, deviceSnapshot⟩)
    (by intro state; cases state; rfl)

end Minidregg.Compiler.ObjectAudienceCodec

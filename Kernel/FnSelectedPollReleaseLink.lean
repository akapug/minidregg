/-
Select the original owner release from a fully native-verified recipient history.
The four-field receipt is paired with that original record by the same replay
walk. Neither fn transport nor a caller-supplied receipt can mint this link.
-/
module

public import Kernel.FnSelectedPollCoverage
public import Kernel.FnSelectedPollReleaseShape
public import Kernel.NativeHostReplay

@[expose] public section

namespace Minidregg.Kernel.FnSelectedPollReleaseLink

open Minidregg.Kernel
open Minidregg.Kernel.FnSelectiveReleaseIngress
open Minidregg.Compiler

set_option autoImplicit false

abbrev Original := FnSelectedPollReleaseShape.Original

def select {config : NativeHost.Config} {target : NativeHost.Durable}
    (verified : NativeHostReplay.Verified config target)
    (releaseKey : Minidregg.Theory.TypedAuthorization.Digest) : Option Original :=
  (target.image.accepted.zip verified.receipts).findSome? fun pair => do
    FnSelectedPollReleaseShape.selectAt config verified.opened
      pair.1 pair.2 releaseKey

end Minidregg.Kernel.FnSelectedPollReleaseLink

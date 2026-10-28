/- Named build check: the canonical set of persisted codec tags/frames
reachable from elaborated codec/materializer/byte-encoder bodies must equal
Compiler.PersistedCodecTags' registry set, in both directions. Definitions are
traversed, not comments or theorem fixtures. Registry enumeration and the epoch
hash are excluded from discovery, so they cannot manufacture reverse coverage.
Inline receiving identities need no relocation or declaration exceptions.

SHAPES.  Each identity also has a structural fingerprint: the definitions that
spell it (its owners) and the codec definitions that use an owner, closed under
the package definitions they reference, each hashed by type and value.  Proofs
do not count (a definition's abstracted proofs are compiler auxiliaries, hashed by their
statement only), so restating a proof never moves a fingerprint; nor does the elaborator's
numbering of an auxiliary (`isCompilerAux`: matchers, sparse casesOn, proofs are hashed by
structure, not name, so a module build and a non-module build agree); adding a field,
reordering a product, changing a nested codec or a nested frame does.
`Compiler.PersistedCodecShapes.pins` is the generated record of those
fingerprints, and `#assert_persisted_codec_tags` requires every identity's
current fingerprint to equal its pin.  A codec whose structure changed while
its identity did not therefore fails the build BY NAME.  The answer is never a
hand edit: `scripts/codec-shapes-regen.py` bumps the identity's version
(everywhere it is spelled, Lean and Rust) and re-emits the pins, and since the
pins feed `DurableCheckpointCodec.persistedCodecCorpus`, the derived StoreEpoch
moves with them. -/
import Kernel.NativeHostReplay
import Compiler.PersistedCodecTags
import Compiler.PersistedCodecShapes
import Lean

namespace Minidregg.Compiler.PersistedCodecTagCensus
open Lean Elab Command Meta

partial def literals (e : Expr) : List String :=
  match e with
  | .lit (.strVal s) => if s.startsWith "DREGG" then [s] else []
  | .app f a => literals f ++ literals a
  | .lam _ _ b _ | .forallE _ _ b _ => literals b
  | .letE _ _ v b _ => literals v ++ literals b
  | .mdata _ b => literals b
  | .proj _ _ b => literals b
  | _ => []

partial def dependencies (e : Expr) : List Name :=
  match e with
  | .const n _ => [n]
  | .app f a => dependencies f ++ dependencies a
  | .lam _ _ b _ | .forallE _ _ b _ => dependencies b
  | .letE _ _ v b _ => dependencies v ++ dependencies b
  | .mdata _ b => dependencies b
  | .proj _ _ b => dependencies b
  | _ => []

/-- Static version suffixes and raw numeric byte frames, including those
embedded directly in a codec record. A descriptor's encoded data is not a tag. -/
partial def fixedFrames (e : Expr) : List Expr :=
  let args := e.getAppArgs
  let numericFrame := e.isAppOfArity ``List.cons 3 &&
    args[0]!.isConstOf ``UInt8 &&
    args[1]!.isAppOfArity ``OfNat.ofNat 3 &&
    args[1]!.getAppArgs[1]! == .lit (.natVal 68)
  let suffixedFrame := (e.isAppOfArity ``HAppend.hAppend 6 ||
      e.isAppOfArity ``List.append 3) &&
    args[args.size - 1]!.isAppOfArity ``List.cons 3 &&
    args[args.size - 1]!.getAppArgs[0]!.isConstOf ``UInt8
  let versionedPrefix := if (e.isAppOfArity ``HAppend.hAppend 6 ||
      e.isAppOfArity ``List.append 3) && args[args.size - 1]!.isAppOfArity ``List.cons 3 then
    let cons := args[args.size - 1]!.getAppArgs
    let framePrefix := args[args.size - 2]!
    let version := cons[1]!
    if cons[0]!.isConstOf ``UInt8 && !framePrefix.hasLooseBVars && !version.hasLooseBVars then
      [mkApp3 (mkConst ``List.append [.zero]) (mkConst ``UInt8) framePrefix
        (mkApp3 (mkConst ``List.cons [.zero]) (mkConst ``UInt8) version
          (mkApp (mkConst ``List.nil [.zero]) (mkConst ``UInt8)))]
    else []
  else []
  let here := (if !e.hasLooseBVars && (numericFrame || suffixedFrame) then [e] else []) ++ versionedPrefix
  here ++ match e with
    | .app f a => fixedFrames f ++ fixedFrames a
    | .lam _ _ b _ | .forallE _ _ b _ => fixedFrames b
    | .letE _ _ v b _ => fixedFrames v ++ fixedFrames b
    | .mdata _ b => fixedFrames b
    | .proj _ _ b => fixedFrames b
    | _ => []

def packageDeclaration (env : Environment) (n : Name) : Bool :=
  match env.getModuleIdxFor? n with
  | none => n.toString.startsWith "Minidregg."
  | some i =>
      match env.header.moduleNames[i.toNat]? with
      | some m => [ `Compiler, `Kernel, `Host ].contains m.getRoot
      | none => false

def codecRoot (n : Name) (info : ConstantInfo) : Bool :=
  let head := info.type.consumeMData.getForallBody.getAppFn.constName?
  let leaf := n.toString.splitOn "." |>.getLast!
  leaf.startsWith "encode" || leaf.startsWith "decode" || leaf.endsWith "Bytes" ||
    head == some ``Minidregg.Kernel.ProtectedCell.Spec ||
    head == some ``Minidregg.Compiler.DurableCheckpointCodec.Framed ||
    head == some ``Minidregg.Compiler.Tower256ConcreteBackend.StreamCodec ||
    head == some ``Minidregg.Theory.IndexedProgram.LawfulCodec ||
    head == some ``Minidregg.Compiler.StoreCodec.Wire ||
    head == some ``Minidregg.Theory.CellState.Materializer

/-- Read a directly referenced registry identity, without following the
manifest or hash back into all entries. A codec's reference remains evidence;
the mere presence of an entry in the registry does not count as reachability. -/
def registeredIdentity (name : Name) (info : ConstantInfo) : TermElabM (List UInt8) := do
  let value := mkConst name
  if info.type.isConstOf ``String then
    return (← unsafe evalExpr String (mkConst ``String) value).toUTF8.toList
  else if info.type.isConstOf ``Nat then
    return (toString (← unsafe evalExpr Nat (mkConst ``Nat) value)).toUTF8.toList
  else
    unsafe evalExpr (List UInt8) (mkApp (mkConst ``List [.zero]) (mkConst ``UInt8)) value

/-- The registry identities a definition names through their constants
(`PersistedCodecTags.world_root_v2`) rather than by spelling the literal. Such a
definition owns the identity exactly as a literal spelling does; without this,
every identity written once (in the registry only) had no owners and its
fingerprint covered nothing. Version constants (`Nat`) compose identities and own
none themselves. -/
def registryReferences (env : Environment) (e : Expr) : TermElabM (List (List UInt8)) := do
  let mut out := []
  for d in (dependencies e).eraseDups do
    if d.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." &&
        Minidregg.Compiler.PersistedCodecTags.tagAttribute.hasTag env d then
      if let some info := env.find? d then
        let type := info.type.consumeMData
        if type.isConstOf ``String ||
            (type.isAppOfArity ``List 1 && type.appArg!.isConstOf ``UInt8) then
          out := (← registeredIdentity d info) :: out
  return out

/-- Persisted identities are excluded from fingerprints: an identity names a
shape, it is not part of it (a nested codec's identity still counts through the
definition that spells it). -/
def excludedFromShape (n : Name) : Bool :=
  n.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." ||
    n.toString.startsWith "Minidregg.Compiler.PersistedCodecShapes."

def hexDigit (n : Nat) : Char :=
  #['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'][n % 16]!

def hex64 (value : UInt64) : String :=
  String.ofList ((List.range 16).reverse.map fun i => hexDigit (value.toNat / 16 ^ i % 16))

def hexOf (bytes : List UInt8) : String :=
  String.ofList (bytes.flatMap fun b => [hexDigit (b.toNat / 16), hexDigit (b.toNat % 16)])

def render (bytes : List UInt8) : String :=
  String.ofList (bytes.map fun b => if 32 ≤ b.toNat && b.toNat < 127 then Char.ofNat b.toNat else '?')

/-- A compiler-generated auxiliary (a matcher, a sparse `casesOn`, an abstracted proof): its NAME is the
elaborator's numbering, not structure. Lean shares an identical matcher across declarations when it can
see one (a derived `Repr`'s matcher is reused by a codec's `match` in a non-`module` build, but not from a
module, where the derived function is `@[no_expose]`), so the same codec gets `f.match_1` in one build and
`g.match_3` in another. -/
def isCompilerAux : Name → Bool
  | .str _ s => s.startsWith "match_" || s.startsWith "_sparseCasesOn_" || s.startsWith "_proof_"
  | _ => false

mutual
/-- `e` with every compiler auxiliary it names replaced by that auxiliary's own structural hash (recursively,
so two different matchers never collide): renumbering an auxiliary never moves a hash, any change of its
structure (an arm's body, the order of its cases, an abstracted proof's statement) does. -/
partial def auxStructural (env : Environment) (e : Expr) : Expr :=
  e.replace fun
    | .const n us => if isCompilerAux n then some (.const (Name.mkSimple s!"aux#{auxHash env n}") us) else none
    | _ => none

/-- An auxiliary's structural hash: a definition's type and value, a theorem's statement (never its proof). -/
partial def auxHash (env : Environment) (n : Name) : UInt64 :=
  match env.find? n with
  | some (.defnInfo info) => mixHash (hash (auxStructural env info.type)) (hash (auxStructural env info.value))
  | some info => hash (auxStructural env info.type)
  | none => hash n
end

/-- One definition's own structure: its type and (for a definition) its value, with compiler auxiliaries
hashed by structure (`auxStructural`). Theorems are never entered (a proof is not structure), and every
other constant it names is a separate node of the closure. -/
def declarationHash (env : Environment) (n : Name) : UInt64 :=
  match env.find? n with
  | some (.defnInfo info) => mixHash (hash (auxStructural env info.type)) (hash (auxStructural env info.value))
  | some (.thmInfo _) => hash n
  | some info => hash (auxStructural env info.type)
  | none => hash n

/-- Registered `DREGG` identities that no definition spells or names. Their fingerprint
would cover nothing (pinned 0000000000000007), so their pin would guard nothing; the census
refuses them by name. Version constants (registered, but not `DREGG` bytes) compose
identities and own none, so they are exempt. -/
def ownerless (registered : List (List UInt8)) (owners : Std.HashMap (List UInt8) (Array Name)) :
    List (List UInt8) :=
  registered.filter fun bytes => bytes.take 5 == [68,82,69,71,71] && (owners.getD bytes #[]).isEmpty

-- A tagged identity no definition references is refused; an owned one and a version constant are not.
#guard ownerless [[68,82,69,71,71,47,88], [53]] {} == [[68,82,69,71,71,47,88]]
#guard ownerless [[68,82,69,71,71,47,88]]
    (({} : Std.HashMap (List UInt8) (Array Name)).insert [68,82,69,71,71,47,88] #[`Example.wire]) == []

/-- Per identity: the owners (definitions that spell it), the codec definitions
that use an owner, closed under the package definitions they reference; the
fingerprint hashes every member's name and own structure, in name order. -/
def computeShapes (env : Environment) (owners : Std.HashMap (List UInt8) (Array Name))
    (packageRefs : Std.HashMap Name (Array Name)) (registered : List (List UInt8)) :
    Array (List UInt8 × String × Array Name) := Id.run do
  let mut referrers : Std.HashMap Name (Array Name) := {}
  for (user, refs) in packageRefs.toList do
    for target in refs do
      referrers := referrers.insert target ((referrers.getD target #[]).push user)
  let mut result := #[]
  for bytes in registered do
    let ownerNames := owners.getD bytes #[]
    let mut start : Array Name := ownerNames
    for owner in ownerNames do
      for user in referrers.getD owner #[] do
        if let some info := env.find? user then
          if codecRoot user info then start := start.push user
    let mut members : NameSet := {}
    let mut stack := start.toList
    while !stack.isEmpty do
      let n := stack.head!
      stack := stack.tail!
      if members.contains n then continue
      members := members.insert n
      stack := (packageRefs.getD n #[]).toList ++ stack
    -- compiler auxiliaries are not members by name: their structure is inside every member naming them
    let ordered := ((members.toList.filter (!isCompilerAux ·)).map (·.toString)).mergeSort (· ≤ ·)
    let fingerprint := ordered.foldl (fun acc s => mixHash acc (mixHash (hash s) (declarationHash env s.toName))) 7
    result := result.push (bytes, hex64 fingerprint, ownerNames)
  return result

elab "#assert_persisted_codec_tags" : command => do
  let env ← getEnv
  let mut queue : List Name := []
  for (name, info) in env.constants.toList do
    if packageDeclaration env name && codecRoot name info &&
        !name.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." then
      queue := name :: queue
  let mut seen : NameSet := {}
  let mut observed : List (List UInt8) := []
  let mut unregistered : Array (Name × Name × String) := #[]
  let mut owners : Std.HashMap (List UInt8) (Array Name) := {}
  let mut packageRefs : Std.HashMap Name (Array Name) := {}
  let registered := Minidregg.Compiler.PersistedCodecTags.canonicalSet
    (Minidregg.Compiler.PersistedCodecTags.entries.map (·.bytes))
  while !queue.isEmpty do
    let name := queue.head!
    queue := queue.tail!
    if seen.contains name then continue
    seen := seen.insert name
    if let some (.defnInfo info) := env.find? name then
      if name.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." then
        if Minidregg.Compiler.PersistedCodecTags.tagAttribute.hasTag env name then
          observed := (← liftTermElabM <| registeredIdentity name (.defnInfo info)) :: observed
        continue
      let source := match env.getModuleIdxFor? name with
        | some i => env.header.moduleNames[i.toNat]!
        | none => env.mainModule
      let type := info.type.consumeMData
      let leaf := name.toString.splitOn "." |>.getLast!
      let constants := if type.isAppOfArity ``List 1 && type.appArg!.isConstOf ``UInt8 &&
          (leaf.endsWith "Frame" || leaf.endsWith "FrameName" || leaf == "frame" || leaf == "magic")
        then [mkConst name] else []
      for frame in constants ++ fixedFrames info.value do
        let bytes ← liftTermElabM <| unsafe evalExpr (List UInt8)
          (mkApp (mkConst ``List [.zero]) (mkConst ``UInt8)) frame
        if bytes.take 5 == [68,82,69,71,71] then
          observed := bytes :: observed
          owners := owners.insert bytes ((owners.getD bytes #[]).push name)
          unless registered.contains bytes do
            unregistered := unregistered.push (name, source, s!"complete frame {bytes}")
      for tag in literals info.value do
        let bytes := tag.toUTF8.toList
        observed := bytes :: observed
        owners := owners.insert bytes ((owners.getD bytes #[]).push name)
        unless registered.contains bytes do
          unregistered := unregistered.push (name, source, tag)
      for bytes in (← liftTermElabM <| registryReferences env info.value) do
        owners := owners.insert bytes ((owners.getD bytes #[]).push name)
      let deps := dependencies info.value
      if packageDeclaration env name then
        packageRefs := packageRefs.insert name
          ((deps.filter (fun d => packageDeclaration env d && !excludedFromShape d)).eraseDups.toArray)
      queue := deps ++ queue
  let reachable := Minidregg.Compiler.PersistedCodecTags.canonicalSet observed
  let registryOnly := Minidregg.Compiler.PersistedCodecTags.entries.filter
    (fun entry => !reachable.contains entry.bytes)
  unless reachable == registered do
    throwError m!"persisted codec tag set equality failed: reachable-only {unregistered.toList}; registry-only {registryOnly.map (·.name)}"
  let shapes := computeShapes env owners packageRefs registered
  let orphans := ownerless registered owners
  unless orphans.isEmpty do
    throwError m!"registered identities with no owner (no definition spells or names them, so their pins guard nothing): {orphans.map render}"
  let pinned := Minidregg.Compiler.PersistedCodecShapes.pins
  let mut changed : Array String := #[]
  let mut unpinned : Array String := #[]
  for (bytes, fingerprint, ownerNames) in shapes do
    match pinned.find? (fun pin => pin.1 == hexOf bytes) with
    | none => unpinned := unpinned.push (render bytes)
    | some pin =>
        unless pin.2 == fingerprint do
          changed := changed.push s!"{render bytes} (pinned {pin.2}, now {fingerprint}; owners {ownerNames.toList})"
  let stale := pinned.filter (fun pin => !shapes.any (fun shape => hexOf shape.1 == pin.1))
  -- Structural pins are advisory (ember, 10-28): a byte-identical rewrite moves a fingerprint, so a moved
  -- or missing pin warns and never stops a build. Tag-set equality and ownership above stay errors.
  unless changed.isEmpty do
    logWarning m!"persisted codec structure changed under an unchanged identity (advisory): {changed.toList}"
  unless unpinned.isEmpty && stale.isEmpty do
    logWarning m!"persisted codec shape pins out of date (advisory): unpinned {unpinned.toList}; stale {stale.map (·.1)}"
  logInfo m!"#assert_persisted_codec_tags: {seen.size} definitions reached; {reachable.length} canonical identities; reachable set = registry set (both directions); {shapes.size} structural fingerprints ({changed.size} moved, {unpinned.size} unpinned, {stale.size} stale pins; advisory)"

/-- Regeneration: the same census, writing the pins module instead of checking it. -/
elab "#emit_persisted_codec_shapes " path:str : command => do
  let env ← getEnv
  let mut queue : List Name := []
  for (name, info) in env.constants.toList do
    if packageDeclaration env name && codecRoot name info &&
        !name.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." then
      queue := name :: queue
  let mut seen : NameSet := {}
  let mut owners : Std.HashMap (List UInt8) (Array Name) := {}
  let mut packageRefs : Std.HashMap Name (Array Name) := {}
  let registered := Minidregg.Compiler.PersistedCodecTags.canonicalSet
    (Minidregg.Compiler.PersistedCodecTags.entries.map (·.bytes))
  while !queue.isEmpty do
    let name := queue.head!
    queue := queue.tail!
    if seen.contains name then continue
    seen := seen.insert name
    if let some (.defnInfo info) := env.find? name then
      if name.toString.startsWith "Minidregg.Compiler.PersistedCodecTags." then continue
      let type := info.type.consumeMData
      let leaf := name.toString.splitOn "." |>.getLast!
      let constants := if type.isAppOfArity ``List 1 && type.appArg!.isConstOf ``UInt8 &&
          (leaf.endsWith "Frame" || leaf.endsWith "FrameName" || leaf == "frame" || leaf == "magic")
        then [mkConst name] else []
      for frame in constants ++ fixedFrames info.value do
        let bytes ← liftTermElabM <| unsafe evalExpr (List UInt8)
          (mkApp (mkConst ``List [.zero]) (mkConst ``UInt8)) frame
        if bytes.take 5 == [68,82,69,71,71] then
          owners := owners.insert bytes ((owners.getD bytes #[]).push name)
      for tag in literals info.value do
        let bytes := tag.toUTF8.toList
        owners := owners.insert bytes ((owners.getD bytes #[]).push name)
      for bytes in (← liftTermElabM <| registryReferences env info.value) do
        owners := owners.insert bytes ((owners.getD bytes #[]).push name)
      let deps := dependencies info.value
      if packageDeclaration env name then
        packageRefs := packageRefs.insert name
          ((deps.filter (fun d => packageDeclaration env d && !excludedFromShape d)).eraseDups.toArray)
      queue := deps ++ queue
  let shapes := computeShapes env owners packageRefs registered
  let orphans := ownerless registered owners
  unless orphans.isEmpty do
    throwError m!"registered identities with no owner (no definition spells or names them, so their pins guard nothing): {orphans.map render}"
  let mut out := "module\n\n@[expose] public section\n\n/- GENERATED by scripts/codec-shapes-regen.py from `#emit_persisted_codec_shapes`.\n" ++
    "Do not edit: the structural fingerprint of every persisted codec identity, checked by\n" ++
    "`Compiler.PersistedCodecTagCensus` and hashed into the derived StoreEpoch. -/\n" ++
    "namespace Minidregg.Compiler.PersistedCodecShapes\n\n" ++
    "/-- (identity octets in hex, structural fingerprint in hex). -/\n" ++
    "def pins : List (String × String) := [\n"
  let mut index := 0
  for (bytes, fingerprint, _) in shapes do
    index := index + 1
    let comma := if index == shapes.size then "" else ","
    out := out ++ s!"  (\"{hexOf bytes}\", \"{fingerprint}\"){comma}  -- {render bytes}\n"
  out := out ++ "]\n\nend Minidregg.Compiler.PersistedCodecShapes\n"
  IO.FS.writeFile path.getString out
  logInfo m!"#emit_persisted_codec_shapes: {shapes.size} fingerprints written to {path.getString}"

#assert_persisted_codec_tags
end Minidregg.Compiler.PersistedCodecTagCensus

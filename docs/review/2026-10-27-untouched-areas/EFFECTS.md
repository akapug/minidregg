# Effects/: the decision (deputy, 2026-10-27)

**Verdict: REPAIR the label now; the registry is a Phase-3 redesign, not a wire for the opening.**

## What is there
`Effects/EffectSpec.lean` declares an effect as `Op`, `State`, `sem : Op → State → State`, and derives
the term, executor and descriptor by initiality (`derive`, `derived_agrees`, `executor_unique`,
`descriptor_faithful`). Its one declaration, `moveEffect`, is over `Kernel.State.KernelState` and
`Kernel.move`. `Effects/Placeholder.lean` names the rest as `[EFFECT-registry]`.

## Why "one effect through the registry behind a shell verb" would be theatre today
- `KernelState`/`move` is not the deployed money path: no module in the `Host.Main` closure calls
  `Kernel.move` or builds a `KernelState` (`git grep` over Host/ and Kernel/Native*: no hit). The
  deployed write path is `Kernel.DeclaredResourceController` (`step`, line 627, over a
  `PreparedInvocation deployment profile ambient ground command`; `admit*`, lines 1755-2095, monadic
  over a `CredentialSignatureIO.Oracle`), the Book under `Theory.CanonicalResourceKernel`, and the
  receivers (job money 160-163, activity 210-214, the platform arms).
- The engine's shape, a total `Op → State → State` free monad, cannot state what the live admission
  is: a dependent prepared invocation, a refusal with its clause, an authority read, an oracle. A
  registry over `EffectSpec` as it stands would dispatch a toy beside the real path: ATLAS law 5 (an
  abstraction is a generalisation of the live types, instanced in the CI closure, or it does not
  exist) and law 13 (never land beside what it supersedes).

## The repair now (label)
The first declaration is a model of conservation, not a deployed effect. Any page or document that
cites Effects as "the derivation engine the Host runs" is wrong; the Assurance census
(docs/ASSURANCE-CENSUS-2026-10-27.md) carries the deployed/research line.

## The Phase-3 design (statement first, when it is taken up)
1. Widen the declaration, not the emitter (law 11): `EffectSpec` gains a refusal (`sem : Op → State →
   Except Refusal State`), an authority demand (the `Pred` the op must satisfy over a view), and a
   frame (the cells an op may touch), so it can state `DeclaredResourceController.step`'s contract.
2. The keystone, as a `Prop` before any proof: for the registry `R` the Host dispatches through,
   `dispatch R code op s = (R.lookup code).sem op s` (agreement), `dispatch` on an unregistered
   code refuses by name (teeth), and every registered op changes only its frame (frame law); poles:
   a two-entry registry whose dispatch admits one op and refuses an out-of-frame one (satisfiable),
   a ghost entry whose reading differs (teeth).
3. The first live declaration is the one already pure enough: the declared-resource write of a content
   cell (`doc append`'s Host arm), so the shell verb that exercises it exists today. Its Host arm then
   calls `dispatch`, and the hand arm is deleted in the same commit.
4. Seam: the Host arm is the platform lane's (L1, lane/lean-critical); the change waits for its
   receiver work to land, then one lane holds both sides.

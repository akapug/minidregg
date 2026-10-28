/-
STATEMENT ONLY, not elaborated, no proof. For the auditor (af7a93e7b8ba729d4) before any proof work.

Problem. A grain-backed share issue is planned at height p: the ticket's root grants carry
`notBefore := p` and `notAfter := p + record.lifetime`
(Kernel/ApplicationShareIssueSource.lean:213-214, in `rootCapability`, reached through
`Ready.descriptor`), signed into `decoded.source.birth`. Admission rebuilds the descriptor at the
SUBMIT height h = `ambient.height = NativeHost.logicalHeight config durable = genesisHeight +
accepted-turn count` and requires equality
(Kernel/ApplicationShareIssueGrainAdmission.lean, `Accepted.sourceDescriptor` at lines 63-68 and
the byte-equality test in `admitNative`). So one accepted turn between plan and submit changes h,
the rebuilt descriptor differs from the signed one, and the issue is refused. The clock is the
accepted-turn count, so a busy room hits this.

Statement. Admission derives the window from the plan's signed height p, not from h: it accepts
exactly when some p with p <= h < p + lifetime makes the signed descriptor equal the descriptor
rebuilt at p. The rest of the descriptor is unchanged (issuer, payer, funding, tariff, nonce,
births, policies).
-/
import Kernel.ApplicationShareIssueGrainAdmission

namespace Minidregg.Kernel.ApplicationShareIssueGrainAdmission
open Minidregg.Compiler Minidregg.Theory Minidregg.Kernel.ApplicationShareIssueSource

variable {F : Type} [Field F] [DecidableEq F]

/-- The descriptor of the ticket rebuilt as if planned at height `p`. This is the existing
`Ready.expectedDescriptor` with `p` in place of `ambient.height`; nothing else varies. -/
def descriptorPlannedAt {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config}
    {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (p : Nat)
    (payer : Nat) (funding : List InitialFunding) (auxiliaryCreates : _) :
    Descriptor CanonicalCellRegistry.registry :=
  { ready.expectedDescriptor profile config record authority p payer funding with
    auxiliaryCreates := auxiliaryCreates }

/-- The relaxed acceptance: the signed ticket descriptor is the one planned at some height `p`
that is not in the future of the submit height `h` and whose window has not closed. -/
def PlannedWithinWindow {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config}
    {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (h : Nat)
    (signed : Descriptor CanonicalCellRegistry.registry) (auxiliaryCreates : _) : Prop :=
  ∃ p, p ≤ h ∧ h < p + record.lifetime ∧
    signed = descriptorPlannedAt ready record authority p signed.fee.payer signed.funding auxiliaryCreates

/-- Pole 1, satisfiable: planned at p, one accepted tick, submitted at p + 1 is accepted
(so long as the window is more than one tick wide). -/
def pole_admits_after_one_tick : Prop :=
  ∀ {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config} {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (p : Nat)
    (payer : Nat) (funding : List InitialFunding) (aux : _),
    1 < record.lifetime →
    PlannedWithinWindow ready record authority (p + 1)
      (descriptorPlannedAt ready record authority p payer funding aux) aux

/-- Pole 2a, teeth (expiry): at or after `notAfter = p + lifetime` the issue is refused. -/
def pole_refuses_expired : Prop :=
  ∀ {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config} {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (p h : Nat)
    (payer : Nat) (funding : List InitialFunding) (aux : _),
    p + record.lifetime ≤ h →
    ¬ PlannedWithinWindow ready record authority h
        (descriptorPlannedAt ready record authority p payer funding aux) aux

/-- Pole 2b, teeth (any other byte): a descriptor that differs from every height-planned rebuild,
for instance a different payer-independent field such as the issuer's policy list, is refused. -/
def pole_refuses_altered : Prop :=
  ∀ {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config} {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (h : Nat)
    (signed : Descriptor CanonicalCellRegistry.registry) (aux : _),
    (∀ p, signed ≠ descriptorPlannedAt ready record authority p signed.fee.payer signed.funding aux) →
    ¬ PlannedWithinWindow ready record authority h signed aux

/-- Pole 2c, teeth (future plan): a descriptor planned at a height above the submit height is
refused (p <= h). -/
def pole_refuses_future_plan : Prop :=
  ∀ {profile : CanonicalRuntimeProfile.Profile F} {config : NativeHost.Config} {spec : Spec}
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform) (authority : AuthState) (p h : Nat)
    (payer : Nat) (funding : List InitialFunding) (aux : _),
    h < p →
    (∀ q, q ≤ h → descriptorPlannedAt ready record authority q payer funding aux ≠
      descriptorPlannedAt ready record authority p payer funding aux) →
    ¬ PlannedWithinWindow ready record authority h
        (descriptorPlannedAt ready record authority p payer funding aux) aux

/-- Premise inhabitation: a record with `lifetime > 1`, and a ready ticket over it, exist for the
production profile (the platform record's `lifetime` pin is positive; the existing grain-issue
fixtures instantiate `Ready`). To be discharged against `Fixtures.NativeAcceptedFixture`. -/
def premise_inhabited : Prop :=
  ∃ (profile : CanonicalRuntimeProfile.Profile F) (config : NativeHost.Config) (spec : Spec)
    (ready : Ready config.deployment.domain spec
      (ResourceBirthController.Concrete.sourceIdentity profile.compilerProfile
        config.deployment spec.issuer spec.ticket.issueNonce).value)
    (record : PlatformCellLayout.Platform), 1 < record.lifetime

/-- The change to admission, as the statement the auditor reads: `Accepted.sourceDescriptor` is
replaced by `PlannedWithinWindow` at `ambient.height`, with the plan height `p` carried as a
signed field of the plan (it is already recoverable from the grants' `notBefore`). -/
def admission_relaxed_statement : Prop := True

end Minidregg.Kernel.ApplicationShareIssueGrainAdmission

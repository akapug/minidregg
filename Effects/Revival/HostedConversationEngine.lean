/- Generated declaration: protocol/hosted-conversation.json owns these rows. -/
module
public import Effects.Revival.HostedLifecycle
public import Effects.Revival.HostedConversation
@[expose] public section
namespace Minidregg.Effects.Revival.HostedConversationEngine
open HostedLifecycle
def rules : List Rule := [
  ⟨"open", 0, 0, 2, 1, false⟩,
  ⟨"send", 1, 1, 2, 1, true⟩,
  ⟨"receive", 2, 1, 2, 1, true⟩,
  ⟨"rendezvous", 3, 1, 2, 1, true⟩,
  ⟨"close", 4, 1, 2, 2, true⟩]
def declaration := HostedLifecycle.spec rules
def receivingHandler := HostedLifecycle.handler rules
def receivingRegistry := HostedLifecycle.registry rules
def receive := HostedLifecycle.receive rules
end Minidregg.Effects.Revival.HostedConversationEngine

/- Hosted conversation receiving obligations, stated before receiving proofs.
The source admission uses the generated descriptor reader; physical outcomes
must additionally instantiate these trace obligations against the native sender. -/
module
public import Effects.Revival.HostedConversation
@[expose] public section
namespace Minidregg.Effects.Revival.HostedConversation
structure Binding where
  app subject session appGeneration sessionGeneration : Nat
  deriving DecidableEq
structure Intent where
  binding : Binding
  operation : Nat
  preimage : List UInt8
  deriving DecidableEq
inductive Event where
  | admitted (intent : Intent)
  | retained (intent : Intent)
  | sent (intent : Intent)
  | uncertain (intent : Intent)
  deriving DecidableEq
/-- A candidate receiver is judged on its own trace, not through its own decoder.
Every physical send has both current admission and exact earlier custody; an
uncertain operation can never silently send again, including after reconnect. -/
def Receives (current : Intent → Prop) (trace : List Event) : Prop :=
  ∀ before intent after, trace = before ++ .sent intent :: after →
    current intent ∧ .admitted intent ∈ before ∧ .retained intent ∈ before ∧
      .uncertain intent ∉ before ∧ .sent intent ∉ before
def Keystone (receiver : Intent → List Event) (current : Intent → Prop) : Prop :=
  ∀ intent, Receives current (receiver intent)
def poleBinding : Binding := ⟨1, 2, 3, 4, 5⟩
def poleIntent : Intent := ⟨poleBinding, 6, [7, 8]⟩
def delivered (intent : Intent) : List Event := [.admitted intent, .retained intent, .sent intent]
def replayed (intent : Intent) : List Event := delivered intent ++ [.uncertain intent, .sent intent]
def Satisfiable : Prop := Receives (fun _ => True) (delivered poleIntent)
def Teeth : Prop :=
  ¬ Receives (fun _ => False) (delivered poleIntent) ∧
  ¬ Receives (fun _ => True) (replayed poleIntent) ∧
  ¬ Receives (fun _ => True) [.admitted poleIntent, .sent poleIntent]
def Premise : Prop := ∃ current intent, current intent ∧ Receives current (delivered intent)
end Minidregg.Effects.Revival.HostedConversation

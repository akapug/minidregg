#!/usr/bin/env bash
# check-receiver-verifier.sh -- the receiving pipeline's one verifier, its one `Ran` mint, its live-only Host.
#   (1) `Ran.mk` appears exactly once, in Compiler/CredentialSignatureAdmission.lean (the live shim);
#   (2) that file has no instance making `Ran` inhabited and no unsafe/implemented_by/extern/axiom;
#   (3) `Ran` is a field-less Prop, so `⟨⟩` or `by constructor` mints it WITHOUT the text `Ran.mk`, and the census
#       (check 1 of TokenCensus.Core) skips theorems and proofs: so no Lean file other than the admission file may
#       name the type `Ran` at all, except Kernel/Receiving.lean's two statement lines (admitted_live_ran);
#   (4) nothing builds a `Verifier` by hand outside Theory/ and the admission file;
#   (5) the recorded-transcript oracle (`Oracle.recorded`, `.recorded transcript`) is named only in fixtures,
#       assurance, verify, scripts, tests, the oracle's own two files, Kernel/Receiving.lean's empty-transcript
#       receiver and the SubjectKeyRotation theorem; never in Host/.
#   Self-test: `--plant ran-instance|second-mint|handbuilt|ran-forge|recorded-in-host` must FAIL the gate.
set -euo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel); cd "$root"
adm=Compiler/CredentialSignatureAdmission.lean
check() { # $1 base dir, $2 file with relative lean paths
  local base=$1 list=$2 fail=0 a="$1/$adm" g
  local mints; mints=$(grep -c 'Ran\.mk' "$a" || true)
  [ "$mints" = 1 ] || { echo "FAIL: Ran.mk appears $mints times in $adm (want exactly 1, the live shim)"; fail=1; }
  if grep -nE 'instance[^:]*:[^=]*\b(Inhabited|Nonempty|Decidable|Zero|One|OfNat|EmptyCollection)\b[^=]*\bRan\b' "$a"; then echo "FAIL: an instance makes Ran inhabited"; fail=1; fi
  if grep -nE '\b(unsafe|implemented_by|extern|axiom)\b' "$a" | grep -vE '^[0-9]+:\s*(--|/-)|`|\*\*'; then echo "FAIL: unsafe/implemented_by/extern/axiom in $adm"; fail=1; fi
  while IFS= read -r g; do
    [ "$g" = "$adm" ] && continue
    case "$g" in TokenCensus/*) continue;; esac
    if [ "$g" = Kernel/Receiving.lean ]; then
      n=$(grep -E '(^|[^.A-Za-z_])Ran\b|CredentialSignatureAdmission\.Ran\b' "$base/$g" | grep -vE '^\s*(--|/-)|`\(?Ran|\(`Ran`\)' | grep -c 'Ran config' || true)
      [ "$n" -le 2 ] || { echo "FAIL: $g names Ran on $n lines (want the two statement lines)"; fail=1; }
    elif [ "$g" != Theory/ReceivingVerifier.lean ] && grep -q 'CredentialSignatureAdmission' "$base/$g" &&
         grep -E '(^|[^.A-Za-z_])Ran +[a-z(]|CredentialSignatureAdmission\.Ran\b' "$base/$g" | grep -vE '^\s*(--|/-)' | grep -qv 'Eval\.Ran'; then
      echo "FAIL: $g names the type Ran"; fail=1
    fi
    case "$g" in Theory/*|TokenCensus/*) ;; *)
      if grep -nE 'Verifier +(IO|Id) *where|:= *\{ *Answered' "$base/$g" >/dev/null 2>&1; then echo "FAIL: $g builds a Verifier by hand"; fail=1; fi;; esac
    if grep -nE 'Oracle\.recorded|\(\.recorded ' "$base/$g" >/dev/null 2>&1; then
      case "$g" in
        Fixtures/*|Assurance/*|Verify/*|scripts/*|tests/*|Compiler/CredentialSignature*|Kernel/Receivers/SubjectKeyRotation.lean) ;;
        Kernel/Receiving.lean) grep -nE 'Oracle\.recorded' "$base/$g" | grep -vq 'Transcript\.empty' && { echo "FAIL: $g names .recorded beyond the empty-transcript receiver"; fail=1; } || true;;
        *) echo "FAIL: $g names the recorded-transcript oracle (only fixtures/assurance may)"; fail=1;;
      esac
    fi
  done < "$list"
  return $fail
}
case "${1:-}" in
  --plant)
    t=$(mktemp -d); mkdir -p "$t/Compiler" "$t/Host" "$t/Kernel"; cp "$adm" "$t/$adm"
    : > "$t/list"
    case "$2" in
      ran-instance) printf '\ninstance : Nonempty (Ran c q a) := sorry\n' >> "$t/$adm";;
      second-mint) printf '\ndef forged : Ran c q a := Ran.mk\n' >> "$t/$adm";;
      handbuilt) printf 'def v : Verifier IO where\n  Answered := fun _ _ => True\n' > "$t/Kernel/X.lean"; echo Kernel/X.lean > "$t/list";;
      ran-forge) printf 'theorem x : Minidregg.Compiler.CredentialSignatureAdmission.Ran c q a := ⟨⟩\n' > "$t/Kernel/X.lean"; echo Kernel/X.lean > "$t/list";;
      recorded-in-host) printf 'def o := (.recorded transcript)\n' > "$t/Host/X.lean"; echo Host/X.lean > "$t/list";;
      *) echo "unknown plant"; exit 2;;
    esac
    if check "$t" "$t/list" >/dev/null; then echo "plant NOT caught: $2"; exit 1; fi; echo "plant caught: $2"; exit 0;;
esac
git ls-files '*.lean' > "$(mktemp)".l 2>/dev/null; lst=$(mktemp); git ls-files '*.lean' > "$lst"
check "$root" "$lst" && echo "OK: receiver-verifier: one Ran mint, no Ran forge by name, no hand-built Verifier, recorded oracle off Host"

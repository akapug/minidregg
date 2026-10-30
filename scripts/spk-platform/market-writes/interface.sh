# One executable declaration path for the three app-interface prototypes.
# APP_INTERFACE_PYTHON is a venv with app-interface/requirements.txt installed.
app_interface_driver="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app-interface" && pwd)/row.py"
typed_app_row() {
  local app=$1 result rc run_dir="$out/interface-$1-$BASHPID-$RANDOM"
  result=$("${APP_INTERFACE_PYTHON:-python3}" "$app_interface_driver" qualify "$app" \
    --route "$dir" --package-id "$pkg" --out "$run_dir" 2>"$out/interface-$app.err")
  rc=$?
  if [[ $rc == 0 ]]; then
    echo "1 typed $app write/read-back through declaration; $run_dir/result.json (Hermes NOT_RUN)"
  else
    echo "0 typed $app exit=$rc: ${result:0:350}; $run_dir/result.json; $out/interface-$app.err"
  fi
}

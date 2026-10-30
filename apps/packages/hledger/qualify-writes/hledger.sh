# shellcheck shell=bash
# state, app and out are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
write_Hledger() {
  local typed descriptor
  typed=$(typed_app_row hledger)
  [[ ${typed%% *} == 1 ]] || { echo "$typed"; return; }
  descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
  if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
    cp "$descriptor" "$out/hledger-descriptor-inspection.json"
    echo "1 ${typed#* }; descriptor lists api and web (bridgeConfig.apiPath /)"
  else
    echo "0 typed write passed, but installed descriptor does not list both api and web: $descriptor"
  fi
}

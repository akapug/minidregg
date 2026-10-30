# The typed firefly-iii declaration owns the account write and read-back; the installed
# descriptor must also list api beside web.
write_FireflyIII() {
  local typed descriptor
  typed=$(typed_app_row firefly-iii)
  [[ ${typed%% *} == 1 ]] || { echo "$typed"; return; }
  descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
  if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
    cp "$descriptor" "$out/firefly-iii-descriptor-inspection.json"
    echo "1 ${typed#* }; descriptor lists api and web (bridgeConfig.apiPath /)"
  else
    echo "0 typed write passed, but installed descriptor does not list both api and web: $descriptor"
  fi
}

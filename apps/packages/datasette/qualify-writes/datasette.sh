# Datasette 0.65.5 deliberately exposes read-only HTTP APIs. Qualification records
# the version and database-list reads beneath the HTML, then proves that the
# installed bridge descriptor offers both API kinds to Hermes.
write_Datasette() {
  local got dbs descriptor
  got=$(req GET '/-/versions.json')
  [[ $got == 200 ]] && jq -e '.datasette.version == "0.65.5"' "$body" >/dev/null || {
    echo "0 GET /-/versions.json $got without Datasette 0.65.5"
    return
  }
  dbs=$(req GET '/-/databases.json')
  [[ $dbs == 200 ]] && jq -e 'type == "array"' "$body" >/dev/null || {
    echo "0 GET /-/databases.json $dbs without a JSON array"
    return
  }
  descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
  if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
    cp "$descriptor" "$out/datasette-descriptor-inspection.json"
    echo "1 read-only by design (0.65.5): recorded GET /-/versions.json $got, GET /-/databases.json $dbs; descriptor lists api and web (bridgeConfig.apiPath /)"
  else
    echo "0 read-only API reads passed, but installed descriptor does not list both api and web: $descriptor"
  fi
}

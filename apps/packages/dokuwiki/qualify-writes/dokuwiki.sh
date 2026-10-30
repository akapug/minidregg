write_DokuWiki() {
  jar=""
  jreq GET '/doku.php?id=featured&do=edit'; local edit=$JS
  local fields=() f
  while IFS= read -r -d '' f; do fields+=(--data-urlencode "$f"); done < <(python3 -I "$here/market-writes/form-fields.py" dw__editform <"$body")
  [[ $edit == 200 && ${#fields[@]} -gt 0 ]] || { echo "0 edit form $edit, no dw__editform hidden fields"; return; }
  [[ " ${fields[*]} " == *sectok=* ]] || { echo "0 edit form $edit carries no sectok"; return; }
  jreq POST '/doku.php?id=featured' "${fields[@]}" --data-urlencode $'wikitext======= Featured ======\nwritten by a resident\n' \
    --data-urlencode 'summary=resident' --data-urlencode 'do[save]=Save'; local save=$JS
  jreq GET '/doku.php?id=featured&do=export_raw'; local got=$JS
  if [[ $save =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'written by a resident' "$body"; then
    local descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
    cp "$descriptor" "$out/dokuwiki-descriptor-inspection.json"
    jq -e '.interfaces | map(.kind) | (index("web") != null and index("api") != null)' \
      "$out/dokuwiki-descriptor-inspection.json" >/dev/null || { echo '0 write passed but descriptor lacks web+api'; return; }
    jq '{interfaces: [.interfaces[] | {id, kind, version, root}]}' \
      "$out/dokuwiki-descriptor-inspection.json" > "$out/dokuwiki-descriptor-summary.json"
    echo "1 POST do[save] $save; export_raw $got exact; descriptor web+api"
  else
    echo "0 POST do[save] $save; export_raw $got without the text"
  fi
}

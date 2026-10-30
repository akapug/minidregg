write_MediaWiki() {
  jar=""
  jreq GET '/api.php?action=query&meta=tokens&assert=user&format=json&formatversion=2'; local tokens=$JS
  local token=""
  [[ $tokens != 200 ]] || token=$(python3 -I -c 'import json,sys; print(json.load(sys.stdin)["query"]["tokens"]["csrftoken"])' <"$body" 2>/dev/null)
  [[ $tokens == 200 && -n $token && $token != '+\\' ]] || { echo "0 CSRF token $tokens [$(snip)]"; return; }
  jreq POST '/api.php' --data-urlencode 'action=edit' --data-urlencode 'title=Featured' \
    --data-urlencode 'text=MediaWiki qualification: written by a resident' --data-urlencode 'summary=resident qualification' \
    --data-urlencode "token=$token" --data-urlencode 'format=json' --data-urlencode 'formatversion=2'; local edit=$JS
  local edited=0 editbody; editbody=$(snip)
  grep -q '"result":"Success"' "$body" && edited=1
  jreq GET '/api.php?action=query&prop=revisions&titles=Featured&rvprop=content&rvslots=main&format=json&formatversion=2'; local got=$JS
  [[ $edit == 200 && $edited == 1 && $got == 200 ]] && grep -q 'MediaWiki qualification: written by a resident' "$body" && { echo "1 API edit $edit; exact content readback $got"; return; }
  echo "0 API edit $edit [$editbody]; readback $got without exact text [$(snip)]"
}

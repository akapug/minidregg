# IPython Notebook tools and persistence qualification now come from
# apps/interfaces/ipython-notebook.json via data-interface.sh. Kernel execution
# requires the correlated JSON channels conversation described in
# docs/app-interfaces/DATA-2026-10-28.md; saving a notebook does not prove execution.

# Mercurial 3.8.4 (package 5a34f1e1: uwsgi + nginx in front of hgweb on /var/repo; the packaged hgrc sets
# allow_push = * and push_ssl = false, .sandstorm/main.py refuses a push unless X-Sandstorm-Permissions
# holds `push`, which the owner does). The write is a push over hg's HTTP wire protocol,
# POST /?cmd=unbundle&heads=force with a HG10UN changegroup that b8-hg-push.py builds by hand (no hg
# client needed; checked against a stock hgweb with hg 7.2: `hg verify` clean, raw-file serves the text).
# The read-back is hgweb's own: GET /raw-file/<node>/featured.txt and GET /rev/<node> (webcommands).
write_Mercurial() {
  local res; res=$(python3 -I "$here/market-writes/b8-hg-push.py" "$dir" featured.txt $'written by a resident\n' 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 POST /?cmd=unbundle: ${res:0:200}"; return; }
  local node; node=$(jq -r .node <<<"$res")
  local raw; raw=$(req GET "/raw-file/$node/featured.txt")
  local raw_ok=0; [[ $raw == 200 ]] && grep -q 'written by a resident' "$body" && raw_ok=1
  local rev; rev=$(req GET "/rev/$node")
  [[ $raw_ok == 1 && $rev == 200 ]] && grep -q "${node:0:12}" "$body" \
    && echo "1 POST unbundle pushed changeset ${node:0:12}; GET raw-file $raw holds the text; GET /rev $rev" \
    || echo "0 pushed ${node:0:12} but raw-file $raw (text ok $raw_ok), rev $rev"
}

# MediaWiki 1.37.4 (package 16bcca05: nginx + php-fpm, sqlite in /var/wiki; opt/app/LocalSettings.php).
# Login is the packaged SandstormAuth session provider (SandstormSessionProvider.php): the owner's
# X-Sandstorm-* headers make the session, there is no login form, so the API needs no login call. The
# edit is the stock API (rest of the MW 1.37 core): GET /api.php?action=query&meta=tokens for the CSRF
# token, then POST /api.php action=edit (title, text, summary, token), read back with action=parse
# (prop=wikitext) and ?action=raw. A first userinfo call lets the provider create the user before the
# token is minted.
write_MediaWiki() {
  jar=""
  jreq GET '/api.php?action=query&meta=userinfo&format=json'; local ui=$JS
  jreq GET '/api.php?action=query&meta=tokens&type=csrf&format=json'; local tk=$JS
  local tok; tok=$(jq -r '.query.tokens.csrftoken // empty' "$body" 2>/dev/null)
  [[ $ui == 200 && $tk == 200 && -n $tok ]] || { echo "0 GET api.php userinfo $ui, tokens $tk: no csrftoken ($(head -c 100 "$body" | tr -d '\n'))"; return; }
  jreq POST /api.php --data-urlencode action=edit --data-urlencode format=json --data-urlencode title=Featured \
    --data-urlencode $'text=== Featured ==\nwritten by a resident\n' --data-urlencode 'summary=resident' --data-urlencode "token=$tok"; local ed=$JS
  jq -e '.edit.result == "Success"' "$body" >/dev/null 2>&1 || { echo "0 POST api.php action=edit $ed: $(head -c 160 "$body" | tr -d '\n')"; return; }
  jreq GET '/api.php?action=parse&page=Featured&prop=wikitext&format=json'; local pa=$JS
  local parsed=0; [[ $pa == 200 ]] && jq -e '.parse.wikitext["*"] | contains("written by a resident")' "$body" >/dev/null 2>&1 && parsed=1
  jreq GET '/index.php?title=Featured&action=raw'; local raw=$JS
  [[ $parsed == 1 && $raw == 200 ]] && grep -q 'written by a resident' "$body" \
    && echo "1 POST api.php action=edit $ed Success; action=parse $pa and action=raw $raw hold the text" \
    || echo "0 edited but parse $pa (ok $parsed), raw $raw without the text"
}

# Firefly III 4.7.9 (package 3392ef75: Laravel 5.x on nginx + php-fpm 7.2 with a bundled mysqld; routes/web.php,
# app/Http/Middleware/Sandstorm.php). The Sandstorm middleware logs the session in from X-Sandstorm-User-Id
# (and needs SANDSTORM=1 in php-fpm's environment, clear_env=no), so the write is the page's own form:
# GET /accounts/create/asset (form id `store`: hidden _token, what, active, plus the currency_id select),
# POST /accounts/store (AccountFormRequest: name, accountRole, currency_id, include_net_worth), which
# answers a redirect; the read-back is the account list GET /accounts/asset. The Laravel session cookie
# binds the token to the POST, so both calls share the jar.
write_FireflyIII() {
  jar=""
  jreq GET /accounts/create/asset; local form=$JS
  local fields=() f
  while IFS= read -r -d '' f; do fields+=(--data-urlencode "$f"); done < <(python3 -I "$here/market-writes/form-fields.py" store <"$body")
  [[ " ${fields[*]} " == *_token=* ]] || { echo "0 GET /accounts/create/asset $form: no _token in form#store"; return; }
  local cur; cur=$(python3 -I "$here/market-writes/b8-select-default.py" currency_id <"$body")
  [[ -n $cur ]] || { echo "0 GET /accounts/create/asset $form: no currency_id option"; return; }
  jreq POST /accounts/store "${fields[@]}" --data-urlencode 'name=featured by a resident' --data-urlencode "currency_id=$cur" \
    --data-urlencode accountRole=defaultAsset --data-urlencode include_net_worth=1; local post=$JS
  [[ $post =~ ^(200|302|303)$ ]] || { echo "0 POST /accounts/store $post"; return; }
  jreq GET /accounts/asset; local got=$JS
  [[ $got == 200 ]] && grep -q 'featured by a resident' "$body" \
    && echo "1 POST /accounts/store $post (currency_id $cur); GET /accounts/asset $got lists it" \
    || echo "0 POST /accounts/store $post; GET /accounts/asset $got without the account"
}

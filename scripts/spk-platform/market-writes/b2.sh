# Batch B2 writes: lists, ledgers and a calendar. Reasoned from each package's own source (no live probe).
# Yet Another TODO (package: a Go gorilla/mux app, /app on 8080, DB_PATH /var/db.sqlite3; the page's
# own form is POST /todos/new with descr, sort_col, sort_dir, and it answers with a redirect to /).
write_YetAnotherTODO() {
  local made; made=$(req POST /todos/new --data-urlencode 'descr=featured by a resident' --data-urlencode sort_col=done --data-urlencode sort_dir=asc)
  local got; got=$(req GET /)
  [[ $made =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /todos/new $made; GET / $got lists it"
}

# OrgTodo 0.1.7 (package: `npm start` = node build/app.js, express, body parsed as text for every type;
# sqlite at /var/tasks.db). POST /tasks (addTask) inserts columns (done, priority, deadline) the tasks
# table does not have: do not use it. POST /tasks/:id is the sync path (upsertTodo) and takes the wire entry
# as JSON text {id, hash, fulltext}; GET /tasks returns {entries: {id: wire entry}}.
write_OrgTodo() {
  local entry='{"id":"featured-1","hash":"h-featured-1","fulltext":"* TODO featured by a resident\n:PROPERTIES:\n:ID: featured-1\n:END:\n"}'
  local post; post=$(req POST /tasks/featured-1 -H 'Content-Type: text/plain' --data "$entry")
  local got; got=$(req GET /tasks)
  [[ $post == 200 && $got == 200 ]] && jq -e '.entries["featured-1"].fulltext | contains("featured by a resident")' "$body" >/dev/null \
    && echo "1 POST /tasks/featured-1 $post; GET /tasks $got holds it"
}

# SandCal 0.9.3 (package: a Haskell scotty app, routes /event/new, /import, /export.ics; DB /var/sandcal.db).
# SandCal has no CalDAV endpoint (its routes are the web UI, an ICS import form and an ICS export feed), so
# the write is the import form: POST /import multipart with the .ics under the form's own file input (named
# from GET /import, with any hidden inputs it carries), read back from GET /export.ics.
write_SandCal() {
  local ics=$'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//mini//resident//EN\r\nBEGIN:VEVENT\r\nUID:resident-1@mini\r\nDTSTAMP:20261027T200000Z\r\nDTSTART:20261028T150000Z\r\nDTEND:20261028T160000Z\r\nSUMMARY:planned by a resident\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
  jar=""
  jreq GET /import; local form=$JS
  local fname; fname=$(grep -o '<input[^>]*type="file"[^>]*>' "$body" | head -1 | grep -o 'name="[^"]*"' | head -1 | sed 's/name="//; s/"//')
  [[ $form == 200 && -n $fname ]] || { echo "0 GET /import $form, no file input"; return; }
  local fields=() f
  while IFS= read -r -d '' f; do fields+=(-F "$f"); done < <(python3 -I "$here/market-writes/form-fields.py" "$(grep -o '<form[^>]*enctype="multipart/form-data"[^>]*>' "$body" | head -1 | grep -o ' id="[^"]*"' | sed 's/ id="//; s/"//')" <"$body")
  printf '%s' "$ics" >"$out/bodies/featured.ics"
  jreq POST /import "${fields[@]}" -F "$fname=@$out/bodies/featured.ics;type=text/calendar;filename=featured.ics"; local post=$JS
  jreq GET /export.ics; local got=$JS
  [[ $post =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'planned by a resident' "$body" && echo "1 POST /import $post (file input $fname); GET /export.ics $got"
}
write_ExpenseOwl() {
  local p; p=$(req PUT /expense -H 'Content-Type: application/json' -d '{"name":"featured by a resident","category":"Other","amount":-3.5,"date":"2026-10-27T12:00:00Z"}')
  [[ $p =~ ^20 ]] || p=$(req POST /expense -H 'Content-Type: application/json' -d '{"name":"featured by a resident","category":"Other","amount":-3.5,"date":"2026-10-27T12:00:00Z"}')
  local g; g=$(req GET /expenses)
  [[ $p =~ ^20 && $g == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /expense $p; GET /expenses $g"
}

# Batch B2 writes: lists, ledgers and a calendar. Reasoned from each package's own source (no live probe).
# Yet Another TODO (package: a Go gorilla/mux app, /app on 8080, DB_PATH /var/db.sqlite3; the page's
# own form is POST /todos/new with descr, sort_col, sort_dir, and it answers with a redirect to /).
write_YetAnotherTODO() {
  local made; made=$(req POST /todos/new --data-urlencode 'descr=featured by a resident' --data-urlencode sort_col=done --data-urlencode sort_dir=asc)
  local got; got=$(req GET /)
  [[ $made =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /todos/new $made; GET / $got lists it"
}

# Row evidence (lane/app-batch-2): install refused, "grain refused: invalid or oversized sandstorm-manifest"
# (package 727e6323). Cause: its sandstorm-manifest is 1,500,456 bytes (inline SVG and PNG metadata art)
# against a 1 MiB MAX_MANIFEST that Sandstorm does not have; the limit is now 16 MiB. Not a package defect.
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

# ExpenseOwl (package 07a8207b, /opt/app/main, tanq16/expenseowl internal/api, data in /var/data). The route
# table is in the binary's embedded page script (the add-expense form): fetch('/expense', {method: 'PUT', body:
# JSON {name, category, amount, date}}), and GET /expenses lists JSON. The method is PUT in this build; the run on
# e89fe7b8b answered POST /expense 405 (the handler allows only PUT), with GET /expenses 200 and [] left.
# Amount stays positive (an earlier negative amount left the list empty).

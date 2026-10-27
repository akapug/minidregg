# Batch B2 writes: lists, ledgers and a calendar.
# YetAnotherTODO: row evidence (the page body captured on j: form method=post action=/todos/new, field descr).
write_YetAnotherTODO() {
  local p; p=$(req POST /todos/new --data-urlencode 'descr=featured by a resident' --data-urlencode sort_col=id --data-urlencode sort_dir=asc)
  local g; g=$(req GET /)
  [[ $p =~ ^(200|302|303)$ && $g == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /todos/new $p; GET / $g" \
    || echo "0 POST /todos/new $p, GET / $g: item not in the page"
}
# ExpenseOwl: upstream API (tanq16/expenseowl): POST /expense JSON {name,category,amount,date}, GET /expenses lists JSON.
# Row evidence: the first attempt (negative amount) left GET /expenses at [], so the amount is sent positive.
write_ExpenseOwl() {
  local p; p=$(req POST /expense -H 'Content-Type: application/json' \
    -d '{"name":"featured by a resident","category":"Other","amount":3.5,"date":"2026-10-27T12:00:00Z"}')
  local g; g=$(req GET /expenses)
  [[ $p =~ ^20 && $g == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /expense $p; GET /expenses $g" \
    || echo "0 POST /expense $p, GET /expenses $g: expense not in the list"
}
# OrgTodo: no recipe proven. Row evidence: install refused, "grain refused: invalid or oversized sandstorm-manifest"
# (package 727e6323, a defect of the package or the manifest limit); reasoned write once it installs: upstream POST of a todo.
write_OrgTodo() { echo "0 install refused: invalid or oversized sandstorm-manifest (package 727e6323ee98810826f91b15530e74f4); no write attempted"; }
# SandCal: row evidence: front page GET / 200 has nav only (/, /week, /import "Export"), no form. Reasoned recipe: the
# import page carries the upload form (iCalendar import through the page itself); read back from the event list.
write_SandCal() {
  local f; f=$(req GET /import)
  local action; action=$(grep -o '<form[^>]*action="[^"]*"' "$body" | head -1 | sed 's/.*action="//; s/"//')
  local tok; tok=$(grep -oE 'name="(csrf[_a-z]*|_csrf|authenticity_token)" value="[^"]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $f == 200 && -n $action ]] || { echo "0 GET /import $f: no upload form found (SandCal's new-event form not located; reasoned only)"; return; }
  printf 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//resident//EN\r\nBEGIN:VEVENT\r\nUID:featured-1@resident\r\nDTSTAMP:20261027T120000Z\r\nDTSTART:20261028T120000Z\r\nDTEND:20261028T130000Z\r\nSUMMARY:featured by a resident\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' >"$body.ics"
  local p; p=$(req POST "$action" -F "csrf_token=$tok" -F "file=@$body.ics;type=text/calendar")
  local g; g=$(req GET /)
  [[ $p =~ ^(200|302|303)$ && $g == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST $action (ics) $p; GET / $g" \
    || echo "0 POST $action $p, GET / $g: event not listed"
}

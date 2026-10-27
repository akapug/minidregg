# Batch B2 writes: lists, ledgers and a calendar.
write_YetAnotherTODO() { local g; g=$(req GET /); echo "0 probe: GET / $g"; }
write_OrgTodo() { local g; g=$(req GET /); echo "0 probe: GET / $g"; }
write_SandCal() { local g; g=$(req GET /); echo "0 probe: GET / $g"; }
write_ExpenseOwl() {
  local p; p=$(req PUT /expense -H 'Content-Type: application/json' -d '{"name":"featured by a resident","category":"Other","amount":-3.5,"date":"2026-10-27T12:00:00Z"}')
  [[ $p =~ ^20 ]] || p=$(req POST /expense -H 'Content-Type: application/json' -d '{"name":"featured by a resident","category":"Other","amount":-3.5,"date":"2026-10-27T12:00:00Z"}')
  local g; g=$(req GET /expenses)
  [[ $p =~ ^20 && $g == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /expense $p; GET /expenses $g"
}

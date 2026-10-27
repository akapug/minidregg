# The DAV rows (docs/APP-MARKET-2026-10-27.md section 2b): what a resident or a desktop client
# does over WebDAV/CalDAV, through the same owner route as a browser. They need a Host that
# admits the DAV calls (lane/app-market-dav and the cut that carries it).
write_DavrosTree() {
  local mk; mk=$(req MKCOL /remote.php/webdav/agent-notes)
  local put; put=$(req PUT /remote.php/webdav/agent-notes/plan.txt -H 'Content-Type: text/plain' --data-binary 'filed by a resident over WebDAV')
  local mv; mv=$(req MOVE /remote.php/webdav/agent-notes/plan.txt -H 'Destination: https://grain.test/remote.php/webdav/agent-notes/plan-final.txt' -H 'Overwrite: F')
  local pf; pf=$(req PROPFIND /remote.php/webdav/agent-notes -H 'Depth: 1' -H 'Content-Type: application/xml' \
    --data-binary '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getcontentlength/></d:prop></d:propfind>')
  [[ $mk == 201 && $put =~ ^20 && $mv =~ ^20 && $pf == 207 ]] && grep -q 'plan-final.txt' "$body" \
    && echo "1 MKCOL $mk, PUT $put, MOVE $mv, PROPFIND depth 1 $pf lists plan-final.txt" \
    || echo "0 MKCOL $mk, PUT $put, MOVE $mv, PROPFIND $pf"
}
write_SandCalDAV() {
  local ics=$'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//mini//resident//EN\r\nBEGIN:VEVENT\r\nUID:resident-1@mini\r\nDTSTAMP:20261027T200000Z\r\nDTSTART:20261028T150000Z\r\nDTEND:20261028T160000Z\r\nSUMMARY:planned by a resident\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
  local opt; opt=$(req OPTIONS /caldav/)
  local dav; dav=$(grep -i '^dav:' "$body.headers" | tr -d '\r')
  local pf; pf=$(req PROPFIND /caldav/ -H 'Depth: 1' -H 'Content-Type: application/xml' --data-binary '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>')
  echo "0 probe: OPTIONS $opt ($dav), PROPFIND /caldav/ $pf; the calendar collection path and PUT of $(( ${#ics} )) bytes of iCalendar come next"
}

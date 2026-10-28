# The DAV rows (docs/APP-MARKET-2026-10-27.md section 2b). SandCal has no CalDAV endpoint (its write is
# the ICS import in b2.sh); Davros's legacy root is /remote.php/webdav/ (current: /dav/).
# what a resident or a desktop client
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

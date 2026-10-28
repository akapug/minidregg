# Batch 6 (forms and tools): write recipes. The run that produced the rows (w2, store 93d1a37db7768c6b,
# frozen tree 25290d1d): SandForms and Badgepack lifecycle PASS; OwnTracks and Hummingbird refused at
# install by the bridge (named in their functions). No recipe below was exercised live (the no-probing
# rule landed first); each says where it comes from.

# SandForms (Meteor 1.2.1, DDP): source from the package's own source maps (/prompts/prompts.js:
# Meteor.methods 'Prompts.create'(text, required) inserts a prompt, publication "prompts" is public).
# The page body (get-j) is an empty Meteor shell, so the write is a DDP method over the owner route.


# OwnTracks (mnutt/owntracks-recorder, ot-recorder --http-port, per the package's start script):
# the Recorder's HTTP mode takes a location JSON on POST /pub with the user and device as the
# X-Limit-U / X-Limit-D headers (OwnTracks Recorder docs); /api/0/last is the read-API the package's
# own map page calls (strings in the package). Install is currently refused: "bridge apiPath must
# start and end with '/'" (row k), so the write waits on that.
write_OwnTracks() {
  local tst; tst=$(date +%s)
  local post; post=$(req POST "/pub?u=featured&d=resident" -H 'Content-Type: application/json' -H 'X-Limit-U: featured' -H 'X-Limit-D: resident' \
    --data "{\"_type\":\"location\",\"lat\":52.5200,\"lon\":13.4050,\"tst\":$tst,\"tid\":\"fr\",\"acc\":10}")
  local got; got=$(req GET '/api/0/last?user=featured&device=resident')
  [[ $post =~ ^20 && $got == 200 ]] && grep -q '52.52' "$body" && echo "1 POST /pub $post; GET /api/0/last $got"
}

# Badgepack: the page's own script (get-l in the run) calls fetch(`/api/badges`, POST multipart with
# fields badgeData=<JSON> and file=<image>) and lists with GET /api/badges and GET /api/badges/<id>.
# badgeData fields are the ones the manual-metadata form builds (badgeName and issuerName required).
write_Badgepack() {
  local png="$out/bodies/l-badge.png" id="badge_featured_$(date +%s)"
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\xa7\x9a\x8f\x1b\x00\x00\x00\x00IEND\xaeB`\x82' >"$png"
  local data="{\"id\":\"$id\",\"version\":\"2.0\",\"type\":\"ManualBadge\",\"badgeName\":\"Featured badge by a resident\",\"description\":null,\"issuerName\":\"Resident\",\"issuerUrl\":null,\"issuerEmail\":null,\"credentialProvider\":\"Unknown\",\"issuanceDate\":null,\"expiresDate\":null,\"recipientIdentity\":null,\"rawData\":{\"manual\":true}}"
  local post; post=$(req POST /api/badges -F "badgeData=$data" -F "file=@$png;type=image/png")
  local got; got=$(req GET /api/badges)
  [[ $post =~ ^20 && $got == 200 ]] && grep -q 'Featured badge by a resident' "$body" && echo "1 POST /api/badges multipart $post; GET /api/badges $got"
}

# Hummingbird (mnutt/hummingbird as packaged: /opt/app/sandstorm.js, lib/tracker.js, lib/dashboard.js,
# lib/metrics/*.js, lib/auth.js). Row evidence (e89fe7b8b): lifecycle failed with get-m exit=22, HTTP 403 on /.
# Cause: dashboard.js defaultHandler answers 403 "Forbidden: invalid permissions" unless X-Sandstorm-Permissions
# holds `view-data`, and the harness then gave the owner role 0, "tracker", which may only beacon. The owner
# now holds allAccess (6b5f87872), which includes view-data. The package has no HTTP read of its data: the
# dashboard is socket.io, and each metric emits its count by io.volatile.emit (view_totals every 50 ms). So the
# write is the beacon GET /tracking_pixel* (permission `tracker`, answers the GIF, Metric.insert) and the read
# is a view_totals event of at least 1 on socket.io, both in b6-hb.py over the owner route.
write_Hummingbird() {
  local res; res=$(python3 -I "$(dirname "${BASH_SOURCE[0]}")/b6-hb.py" "$dir" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] && echo "1 GET /tracking_pixel.gif 200; socket.io view_totals >= 1: ${res:0:120}" || echo "0 ${res:0:200}"
}

# Batch 6 (forms and tools): write recipes. The run that produced the rows (w2, store 93d1a37db7768c6b,
# frozen tree 25290d1d): SandForms and Badgepack lifecycle PASS; OwnTracks and Hummingbird refused at
# install by the bridge (named in their functions). No recipe below was exercised live (the no-probing
# rule landed first); each says where it comes from.

# SandForms (Meteor 1.2.1, DDP): source from the package's own source maps (/prompts/prompts.js:
# Meteor.methods 'Prompts.create'(text, required) inserts a prompt, publication "prompts" is public).
# The page body (get-j) is an empty Meteor shell, so the write is a DDP method over the owner route.
write_SandForms() {
  python3 -I "$(dirname "${BASH_SOURCE[0]}")/b6-ddp-prompt.py" "$dir" "featured question $(date +%s)" 2>&1 | tail -1
}

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

# Hummingbird (mnutt/hummingbird, Node): the package's server source shows /tracking_pixel* is the
# beacon (pixelHandler inserts req.params = the query string as a Metric); metrics are read over its
# own web client, whose HTTP read endpoint is not in the package strings I read, so the read-back is
# unverified. Install is currently refused: "invalid bridge ViewInfo: invalid or duplicate permission
# name" (row m), so this waits on that.
write_Hummingbird() {
  local hit; hit=$(req GET '/tracking_pixel.gif?url=https%3A%2F%2Fgrain.test%2Ffeatured&featured=resident')
  local got; got=$(req GET /1.0/metrics)
  [[ $hit == 200 && $got == 200 ]] && grep -q 'featured' "$body" && echo "1 GET /tracking_pixel.gif $hit; GET /1.0/metrics $got"
}

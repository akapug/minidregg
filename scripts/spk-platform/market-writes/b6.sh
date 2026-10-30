# Batch 6 (forms and tools). Package contracts are recorded beside each recipe.
# The 2026-10-29 OwnTracks run reached the recorder; its named readback failure
# is a package identity-normalization defect, described below. Hummingbird uses
# the shared native conversation interpreter, not a standalone HTTP recipe.

# SandForms (Meteor 1.2.1, DDP): source from the package's own source maps (/prompts/prompts.js:
# Meteor.methods 'Prompts.create'(text, required) inserts a prompt, publication "prompts" is public).
# The page body (get-j) is an empty Meteor shell, so the write is a DDP method over the owner route.


# OwnTracks 7191aab6 (ot-recorder 0.6.9) overrides u/d and user/device with
# X-Sandstorm-Username. It sanitizes that name for storage but not lookup:
# "Grain%20owner" writes last/grain-20owner/... and the same-session GET misses it.
# A 200 [] POST is the friends response, not a write receipt. Require this exact
# timestamp in readback; an earlier location cannot qualify a new write.
write_OwnTracks() {
  local tst post got; tst=$(date +%s)
  post=$(req POST "/pub?u=featured&d=resident" -H 'Content-Type: application/json' \
    --data "{\"_type\":\"location\",\"lat\":52.5200,\"lon\":13.4050,\"tst\":$tst,\"tid\":\"fr\",\"acc\":10}")
  cp "$body" "$body.post"
  got=$(req GET '/api/0/last?user=featured&device=resident')
  if [[ $post =~ ^20 && $got == 200 ]] &&
      jq -e --argjson tst "$tst" 'any(.[]; .tst == $tst and .lat == 52.52 and .lon == 13.405)' "$body" >/dev/null 2>&1; then
    echo "1 POST /pub $post; GET /api/0/last $got; exact location timestamp $tst"
  else
    echo "0 owntracks-readback-absent: POST /pub $post; GET /api/0/last $got; timestamp $tst absent; retained $body.post and $body (package username normalization must agree at write and lookup)"
  fi
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

# Hummingbird now uses apps/interfaces/hummingbird.json: transient analytics
# require opening Socket.IO before the beacon and reading a correlated hit
# before the 200 ms interval resets. The native shared conversation owns this.

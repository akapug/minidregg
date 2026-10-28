# batch b1 (notes): write recipes, REASONED from each package's own source (no live probe);
# the lifecycle rows are the run's evidence, the writes are the integrator's to prove.

# SandMD is a HackMD 0.x fork (app output: rproxy on 4444, HackMD config.js warnings). Recipe:
# HackMD's POST /new with a markdown body creates a note and redirects to /<id>; GET /<id>/download
# returns it. Same shape as write_HedgeDoc (a body-parser defect there would show here by name).
write_SandMD() {
  local made; made=$(req POST /new -H 'Content-Type: text/markdown' --data-binary $'# featured\nwritten by a resident\n')
  local note; note=$(grep -i '^location:' "$body.headers" | tr -d '\r' | awk '{print $2}'); note=${note#https://grain.test}; note=${note#http://grain.test}
  [[ $made =~ ^30 && -n $note ]] || { echo "0 POST /new $made (no redirect to the new note)"; return; }
  local got; got=$(req GET "$note/download")
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body" && echo "1 POST /new $made -> $note; GET download $got" || echo "0 GET $note/download $got without the content"
}

# TextEditor is a Meteor app (package source server/server.js): the document is Data "default_id",
# written by the DDP method /Data/update ($set value) and read back from publication thedocument.
write_TextEditor() {
  python3 -I "$here/market-writes/b1-ddp.py" "$dir" 2>&1 | tail -1
}

# Dillinger (package source server.js, Core.fetchMd): POST /factory/fetch_markdown {name, unmd}
# writes /var/dillinger/downloads/files/md/<name>.md; GET /files/md/<name>.md returns it.
write_Dillinger() {
  local post; post=$(req POST /factory/fetch_markdown -H 'Content-Type: application/json' --data '{"name":"featured","unmd":"# featured\nwritten by a resident\n"}')
  [[ $post == 200 ]] && grep -q '"error":false' "$body" || { echo "0 POST /factory/fetch_markdown $post: $(head -c 120 "$body")"; return; }
  local got; got=$(req GET /files/md/featured.md)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body" && echo "1 POST fetch_markdown $post; GET /files/md/featured.md $got" || echo "0 GET /files/md/featured.md $got without the content"
}

# Batch B3 writes: boards and drawing. Reasoned from each package's own source (unpacked from the
# signed .spk under the lane's scratch/), no live probe.
b3_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/b3-sio.py"

# diagrams.net 20.5.2 (package e7f8ac92: root process /server, Sandstorm's own static-publishing server
# speaking WebSession directly, no http-bridge; its strings say "PUT only supported under /var").
# client/ssindex.html, SandstormFile.saveFile: `new mxXmlRequest('var/drawiodiagram.xml', data, 'PUT')`
# and the load is `mxUtils.get('var/drawiodiagram.xml')`. The saved object is one drawio XML document.
write_DiagramsNet() {
  local id="featured-$RANDOM$RANDOM"
  local xml='<mxfile host="app.diagrams.net"><diagram id="'$id'" name="Page-1"><mxGraphModel dx="800" dy="600" grid="1" gridSize="10" page="1" pageWidth="827" pageHeight="1169"><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" value="'$id' drawn by a resident" style="rounded=0;whiteSpace=wrap;html=1;" vertex="1" parent="1"><mxGeometry x="120" y="120" width="160" height="60" as="geometry"/></mxCell></root></mxGraphModel></diagram></mxfile>'
  local put; put=$(req PUT /var/drawiodiagram.xml -H 'Content-Type: application/xml' --data-binary "$xml")
  local got; got=$(req GET /var/drawiodiagram.xml)
  [[ $put =~ ^20 && $got == 200 ]] && grep -q "$id drawn by a resident" "$body" \
    && echo "1 PUT /var/drawiodiagram.xml $put; GET $got holds the mxfile $id" \
    || echo "0 PUT /var/drawiodiagram.xml $put, GET $got: document not read back"
}

# EtherDraw 0.2 (package 71ebb151: node server.js, express + socket.io 1.0.6 + ueberDB sqlite at var/sqlite3.db).
# server.js: socket.on('subscribe', {room}) then 'draw:progress' / 'draw:end' (room, uid, JSON string of the
# path) -> src/util/draw.js endExternalPath -> db.storeProject(room). There is no HTTP read of a drawing
# (GET /d/* is the static page), so the read-back is what a second subscriber is sent: 'project:load' whose
# paper.js JSON must carry the stroke's name. Note it is served from the server's in-memory project (the
# sqlite write ran at draw:end); a restart-surviving read would need a grain stop/start, not done here.
write_EtherDraw() {
  local res; res=$(python3 -I "$b3_py" etherdraw "$dir" featured 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] && echo "1 socket.io draw:end stroke, read back in project:load: ${res:0:100}" \
    || echo "0 socket.io: ${res:0:200}"
}

# Scrumblr 0.5 (package cf6ae092: run.sh starts the bundled redis-server (redis.conf, dir /var, save 10 1)
# then `node server.js 8000`; express + socket.io 1.4.8). server.js: client.on('message') with
# {action:'joinRoom', data:room}, then {action:'createCard', data:{id,text,x,y,rot,colour}} ->
# db.createCard (redis); {action:'initializeMe'} answers 'initCards' from db.getAllCards. The read-back is
# a fresh client's initCards, so the card went through the inner redis.
write_Scrumblr() {
  local res; res=$(python3 -I "$b3_py" scrumblr "$dir" /featured 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] && echo "1 socket.io createCard, read back in a fresh client's initCards: ${res:0:100}" \
    || echo "0 socket.io: ${res:0:200}"
}

# Swagger Editor 2.10.4 (package c6dbeddc: nginx on 8000 via http-bridge, .sandstorm/service-config/nginx.conf
# `location /editor/ { dav_methods PUT; alias /var/editor/; }`; launcher.sh seeds /var/editor/spec;
# swagger-editor/config/defaults.json has "backendEndpoint": "/editor/spec", which the editor PUTs on every
# change). The saved object is one spec document.

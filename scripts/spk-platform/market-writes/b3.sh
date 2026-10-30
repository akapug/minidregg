# Batch B3 writes: boards and drawing. Reasoned from each package's own source (unpacked from the
# signed .spk under the lane's scratch/), no live probe.

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

# Source-pinned declarations replace the former per-app Socket.IO recipes.
write_EtherDraw() { echo '0 etherdraw-empty-project-readiness-defect: declared populated-project read is read-only'; }
write_Scrumblr() { echo '0 native-conversation-receiver-not-attached: scrumblr card.write requires native qualification'; }

# Swagger Editor 2.10.4 (package c6dbeddc: nginx on 8000 via http-bridge, .sandstorm/service-config/nginx.conf
# `location /editor/ { dav_methods PUT; alias /var/editor/; }`; launcher.sh seeds /var/editor/spec;
# swagger-editor/config/defaults.json has "backendEndpoint": "/editor/spec", which the editor PUTs on every
# change). The saved object is one spec document.

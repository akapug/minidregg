# Batch 8 (second wave): write recipes, reasoned from each package's own source (no live probe).

# IPython Notebook 4.2.2 (package 57dedad4: `jupyter notebook --port=8888 --notebook-dir=/var/home`; no
# token or password in 4.2, the grain route is the auth; 186 MB spk / 668 MB unpacked: class L, so the world
# needs MINI_IMPORT_PROFILE=market-large-v1). Jupyter's REST API starts kernels and stores notebooks but has no
# execute call, so the cell runs as an execute_request on the kernel's websocket (jupyter-exec.py); the REST
# calls bracket it. No network: the kernel talks to the notebook server over loopback ZeroMQ only, and the
# code is arithmetic. Steps: POST /api/kernels (the kernelspec default), run `print('resident computed', 6*7)`,
# PUT /api/contents/featured.ipynb with that cell and its real output, GET it back and read the output,
# then DELETE the kernel.
write_IPythonNotebook() {
  local ks; ks=$(req GET /api/kernelspecs)
  local spec; spec=$(jq -r '.default // empty' "$body" 2>/dev/null)
  [[ $ks == 200 && -n $spec ]] || { echo "0 GET /api/kernelspecs $ks: no default kernel"; return; }
  local k; k=$(req POST /api/kernels -H 'Content-Type: application/json' --data "{\"name\":\"$spec\"}")
  local kid; kid=$(jq -r '.id // empty' "$body" 2>/dev/null)
  [[ $k =~ ^20 && -n $kid ]] || { echo "0 POST /api/kernels $k: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local code="print('resident computed', 6*7)" res
  res=$(python3 -I "$here/market-writes/jupyter-exec.py" "$dir" "$kid" "$code" 2>&1 | tail -1)
  req DELETE "/api/kernels/$kid" >/dev/null
  [[ $res == *'"ok": true'* && $res == *'resident computed 42'* ]] || { echo "0 execute_request on kernel $kid: ${res:0:200}"; return; }
  local nb; nb=$(jq -cn --arg code "$code" --argjson res "$res" --arg spec "$spec" \
    '{type:"notebook",content:{nbformat:4,nbformat_minor:0,metadata:{kernelspec:{name:$spec,display_name:$spec}},
      cells:[{cell_type:"code",execution_count:1,metadata:{},source:$code,outputs:[{output_type:"stream",name:"stdout",text:$res.stdout}]}]}}')
  local put; put=$(req PUT /api/contents/featured.ipynb -H 'Content-Type: application/json' --data "$nb")
  [[ $put =~ ^20 ]] || { echo "0 PUT /api/contents/featured.ipynb $put: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local got; got=$(req GET /api/contents/featured.ipynb)
  [[ $got == 200 ]] && jq -e '.content.cells[0].outputs[0].text | contains("resident computed 42")' "$body" >/dev/null \
    && echo "1 kernel $kid ran the cell; PUT featured.ipynb $put; GET $got holds the output 'resident computed 42'"
}

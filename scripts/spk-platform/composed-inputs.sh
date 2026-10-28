#!/bin/bash
# composed-inputs.sh WORLD-IDENTITY.json CANDIDATE_DIR OUT_DIR: the three inputs the composed
# scenario's apps, connector and residents phases read (native/resource-client/composed-scenario.py),
# derived from a jworld-scratch world (dregg-infra edge/mini/journey/jworld-scratch.sh) through the
# real installers, as the Store operator (the uid that runs the world's units; on dregg-build the
# lanes user). Nothing here invents an identity: every value comes from the world's inventory, the
# candidate's manifest, the node's pinned config and genesis, and the operator's own custody.
#
#   OUT_DIR/platform-inputs.json   mini platform inputs (what the constructor's platform-provision.py writes)
#   OUT_DIR/app-selection.json     mini-spk-same-store-selection-v1 (owner, members, package, ids)
#   OUT_DIR/documents-binding.json mini-protected-same-store-v1 (owner, member, reader, reviewer)
#   OUT_DIR/resident-binding.json  mini-same-world-resident-binding-v1
#   OUT_DIR/composed-args.txt      the exact `composed-scenario.py spec ...` arguments to add
#
# The SPK platform on the scenario's own Store: ROOT SETUP (deploy/spk-host/install-user-world under
# sudo -n), the operator broker unit, `same-store-profile.py` (grain init-store against the existing
# config). It REFUSES BY NAME, before any effect, a world whose pinned config lacks the operator
# policy a grain host needs (`lifecycleManagement`, `completionCustodianKey`, `grainBirthTariff`): those
# are pinned at genesis by the workroom provisioner's WORKROOM_OPERATOR_POLICY and are absent from the
# demo's genesis-params.json today; the refusal names the fields. Reads MINI_TEST_SPK (the pinned
# sntfy) or fetches it with fetch-test-spk.sh.
set -euo pipefail
umask 077
[[ $# == 3 ]] || { echo "usage: $0 WORLD-IDENTITY.json CANDIDATE_DIR OUT_DIR" >&2; exit 2; }
world=$1 cand=$2 out=$3
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
refuse() { echo "composed-inputs: $*" >&2; exit 1; }
[[ -f $world && -d $cand && ! -e $out ]] || refuse "need an inventory file, a candidate directory and a fresh OUT_DIR"
jq -e '.type == "mini-world-identity-v1" and (.members | type == "object" and length >= 4)' "$world" >/dev/null \
  || refuse "WORLD-IDENTITY.json is not mini-world-identity-v1 with at least four members (owner, member, reader, reviewer / two authors and a witness)"
mkdir -m 700 "$out"
manifest=$cand/manifest.json
[[ -f $manifest ]] || refuse "candidate has no manifest.json"
# The scratch world's node: the sponsor workspace names the Store, config and sockets.
sponsor_ws=$(jq -r '.members | to_entries[] | select(.value.entry == "sponsor") | .value.workspace' "$world" | head -1)
[[ -n $sponsor_ws && -f $sponsor_ws/workspace.json ]] || refuse "the inventory names no sponsor workspace"
config=$(jq -r .config "$sponsor_ws/workspace.json")
socket=$(jq -r .socket "$sponsor_ws/workspace.json")
host=$(jq -r .host "$sponsor_ws/workspace.json")
node=$(dirname "$(dirname "$config")")
[[ -f $config && -S $socket && -x $host ]] || refuse "sponsor workspace does not pin a config, a live public socket and a Host"
private_socket=$(jq -r '.operator // empty' "$node/ingress.json" 2>/dev/null || true)
[[ -n $private_socket ]] || private_socket=$(dirname "$(dirname "$socket")")/operator/mini.sock
# A grain install talks to the Host over the private operator socket (mini serve-operator), never the public
# one; a world served by a single public `mini serve` cannot install, so say so here, not as spk-host's bare ENOENT.
[[ -S $private_socket ]] || refuse "no live private operator socket at $private_socket: the world serves only its public socket; bring it up with serve-operator + serve-public-proxy (edge store-entry.sh, public-ingress.sh)"
genesis=$node/genesis.json
[[ -f $genesis ]] || refuse "no genesis.json beside the node's config ($node)"
# ── the operator policy a grain host needs, pinned at genesis ────────────────
missing=()
for field in lifecycleManagement completionCustodianKey grainBirthTariff; do
  jq -e --arg f "$field" 'has($f)' "$config" >/dev/null || missing+=("$field")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  refuse "operatorPolicyRequired: the world's pinned config lacks ${missing[*]}; a grain host needs them pinned at genesis (scripts/workroom/provision.sh WORKROOM_OPERATOR_POLICY: lifecycleManagement {managementSubject, managementKeyId} with a management key pair the operator holds, completionCustodianKey = the completion custodian's public key, grainBirthTariff {base, perBirth}); the demo's genesis-params.json does not carry them and deploy/candidate/params.sh does not pass them: a genesis change for L9/infra and L1, not a derivation"
fi
management_subject=$(jq -r .lifecycleManagement.managementSubject "$config")
management_key=$(jq -r .lifecycleManagement.managementKeyId "$config")
# The management custody: the operator's key for the pinned management subject, beside the node.
for candidate_key in "$node/keys/management.key" "$node/tool.key" "$node/keys/tool.key"; do
  # A world may name the management key as an alias (management.key -> sponsor.key); the attach
  # protocol takes custody only of a regular file, so the alias resolves to the file it names.
  [[ -f $candidate_key ]] && mgmt_seed=$(readlink -e "$candidate_key") && break
done
[[ -n ${mgmt_seed:-} ]] || refuse "managementCustodyRequired: no management seed beside the node for subject $management_subject (keys/management.key)"
mgmt_pub=${mgmt_seed%.key}.pub
[[ -f $mgmt_pub ]] || refuse "no public half $mgmt_pub"
completion_seed=$node/keys/completion.seed
completion_pub=$node/keys/completion.pub
[[ -f $completion_seed && -f $completion_pub ]] || refuse "completionCustodyRequired: $completion_seed / $completion_pub (the key whose public half the config pins as completionCustodianKey)"
[[ $(jq -r .completionCustodianKey "$config") == "$(od -An -tx1 -v "$completion_pub" | tr -d ' \n')" ]] || refuse "the completion seed beside the node is not the one the config pins"
# ── the candidate's manifest, with the roles the same-store adapters read ───────
# The world runs the copy of the candidate its install placed beside the Store (the sponsor's Host
# names it); the adapters compare member workspaces against the manifest's paths, so the manifest is
# that installed copy's, provided every role's bytes are the CANDIDATE_DIR manifest's.
installed=$(dirname "$(dirname "$host")")/manifest.json
if [[ -f $installed && $(readlink -f "$installed") != $(readlink -f "$manifest") ]]; then
  jq -e --slurpfile c "$manifest" '.sha256 == $c[0].sha256' "$installed" >/dev/null \
    || refuse "the world's installed candidate ($installed) is not CANDIDATE_DIR's (role digests differ)"
  manifest=$installed
fi
for role in host mini store verifier spkHost; do
  jq -e --arg r "$role" 'has($r) and (.sha256 | has($r))' "$manifest" >/dev/null || refuse "candidate manifest lacks role $role"
done
bwrap=$(sh "$repo/deploy/grain-host/resolve-bwrap") || refuse "no usable bwrap"
jq --arg bwrap "$bwrap" --arg sha "$(sha256sum "$bwrap" | cut -d ' ' -f1)" '. + {bwrap:$bwrap} | .sha256 += {bwrap:$sha}' "$manifest" >"$out/manifest.json"
# ── the SPK platform on this Store: root setup, broker, profile ─────────────────
op_uid=$(id -u) op_name=$(id -un)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$op_uid}
units=/run/user/$op_uid/systemd/user
[[ $(loginctl show-user "$op_uid" -p Linger --value) == yes ]] || refuse "operator linger is required"
store=$("$host" "$config" profile | jq -er '.storeTag | select(test("^[0-9a-f]{16}$"))')
grains=/var/lib/mini-spk-worlds/$store
[[ ! -e $grains ]] || refuse "a grain world for store $store already exists at $grains"
mkdir -m 700 -p "$units" "$out/bin" "$out/evidence"
for binary in mini-spk-broker mini-spk-volume-helper; do install -m 755 "$cand/bin/$binary" "$out/bin/$binary"; done
# The runtime the broker runs is the manifest's spkHost, the one the grain profile pins
# (same-store-profile.py), at its path and digest; a private copy would be a second spelling.
spk_host=$(jq -er .spkHost "$out/manifest.json") spk_host_sha=$(jq -er .sha256.spkHost "$out/manifest.json")
[[ $(sha256sum "$spk_host" | cut -d ' ' -f1) == "$spk_host_sha" ]] || refuse "the manifest's spkHost $spk_host differs from its digest"
install -m 755 "$repo/deploy/spk-host/spk-ingest" "$out/bin/spk-ingest"
runid=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
helper=/usr/local/libexec/mini-spk-volume-helper-$runid
start=$(awk -F: -v user="$op_name" '$1==user && $3>=32 {print $2;exit}' /etc/subuid)
[[ $start =~ ^[0-9]+$ ]] || refuse "no /etc/subuid range for $op_name"
deployment=$(jq -r '.deployment // .domain' "$genesis" | sha256sum | cut -d ' ' -f1)
hostid=$(sha256sum /etc/machine-id | cut -d ' ' -f1)
printf 'ROOT SETUP BEGIN store=%s\n' "$store" | tee -a "$out/root-setup.log"
sudo -n -- "$repo/deploy/spk-host/install-user-world" install "$out/bin/mini-spk-volume-helper" "$helper" "$store" "$deployment" "$hostid" "$op_uid" "$start" 16 >>"$out/root-setup.log" 2>&1
printf 'ROOT SETUP store=%s helper=%s\n' "$store" "$helper" | tee -a "$out/root-setup.log"
registry=/etc/mini-spk-volumes/$store.json
jq -n --slurpfile registry "$registry" --arg binary "$spk_host" --arg sha "$spk_host_sha" --arg ingest "$out/bin/spk-ingest" --arg op "$op_name" \
  --arg bwrap "$bwrap" --arg bwrapSha "$(sha256sum "$bwrap" | cut -d ' ' -f1)" '
  $registry[0] as $r | {protocol:"mini-spk-broker-config-v3",store:$r.store,grainsRoot:$r.grainsRoot,spkRoot:($r.grainsRoot+"/spk"),brokerSocket:($r.grainsRoot+"/runtime-"+$r.store+"/broker.sock"),operatorUser:$op,unitPrefix:"mini",spkHost:$binary,spkHostSha256:$sha,bwrap:$bwrap,bwrapSha256:$bwrapSha,ingestHelper:$ingest,volumeHelper:$r.helper,appUids:$r.appUids,residentHomeReadOnlyPaths:[]}' >"$grains/broker/config.json"
chmod 600 "$grains/broker/config.json"
sed "s|%h/.local/libexec/mini-spk-broker|$out/bin/mini-spk-broker|" "$repo/deploy/spk-host/mini-spk-broker@.service" >"$units/mini-spk-broker@$store.service"
systemctl --user daemon-reload
systemctl --user start "mini-spk-broker@$store.service"
broker=$grains/runtime-$store/broker.sock
for attempt in $(seq 1 100); do [[ ! -S $broker ]] || break; sleep 0.1; done
[[ -S $broker ]] || refuse "operator broker socket did not appear"
# The grain-host profile over the EXISTING config (no genesis, no services).
jq -n --arg manifest "$out/manifest.json" --arg commit "$(jq -r .sourceCommit "$manifest")" --arg config "$config" --arg sha "$(sha256sum "$config" | cut -d ' ' -f1)" \
  --arg private "$private_socket" --arg grains "$grains" --arg broker "$broker" --arg semantics "$(jq -r .expectedSemantics "$genesis")" \
  --arg cseed "$completion_seed" --arg cpub "$completion_pub" --arg bwrap "$bwrap" --arg root "$out/evidence/profile" \
  --arg ms "$management_subject" --arg mk "$management_key" --arg mseed "$mgmt_seed" --arg mpub "$mgmt_pub" '
  {protocol:"mini-spk-same-store-profile-input-v1",manifest:$manifest,expectedSourceCommit:$commit,miniConfig:$config,miniConfigSha256:$sha,
   privateSocket:$private,grainsRoot:$grains,brokerSocket:$broker,semantics:$semantics,completionSeed:$cseed,completionPublicKey:$cpub,bwrap:$bwrap,root:$root,
   management:{subject:$ms,keyId:$mk,keyEpoch:"2",seedPath:$mseed,publicKeyPath:$mpub}}' >"$out/profile-input.json"
python3 -I "$here/same-store-profile.py" "$out/profile-input.json" >"$out/profile.stdout"
# ── platform-inputs.json: the constructor's shape, from this world ──────────────
inventory=$(jq '[.members | to_entries[] | {key: .value.subject, value: {subject: .value.subject, workspace: .value.workspace, home: .value.home}}] | from_entries' "$world")
authority='{}'
# The factory, as the sponsor holds it (genesis gave the sponsor its reference), and the metered parent
# and tool tasks mini apps bootstrap registered: every capability is the one the sponsor's reference names.
[[ $(jq -r .target "$sponsor_ws/refs/factory.json" 2>/dev/null) == "$(jq -r .factoryId "$genesis")" ]] \
  || refuse "the sponsor workspace holds no reference to genesis's factory $(jq -r .factoryId "$genesis") (refs/factory.json)"
for role in factory parent tool; do
  ref=$sponsor_ws/refs/$role.json
  [[ -f $ref ]] || refuse "meteredTasksRequired: no $ref; run \`mini apps bootstrap --dir $sponsor_ws\` first (deploy/market/INSTALL.md §4 step 0)"
  key=task; [[ $role != factory ]] || key=target
  authority=$(jq --arg role "$role" --arg key "$key" --slurpfile r "$ref" '.[$role] = {($key): $r[0].target, ownerCapability: $r[0].observeCapability, managementCapability: $r[0].operationCapability}' <<<"$authority")
done
jq -n --arg config "$config" --arg genesis "$genesis" --arg manifest "$out/manifest.json" --arg public "$socket" --arg private "$private_socket" \
  --arg sponsor "$sponsor_ws" --argjson inventory "$inventory" --argjson authority "$authority" \
  --arg cseed "$completion_seed" --arg cpub "$completion_pub" --arg ms "$management_subject" --arg mk "$management_key" --arg mseed "$mgmt_seed" --arg mpub "$mgmt_pub" \
  --arg domain "$(jq -r .domain "$genesis")" --arg msha "$(sha256sum "$out/manifest.json" | cut -d ' ' -f1)" --arg csha "$(sha256sum "$config" | cut -d ' ' -f1)" '
  {identity:{domain:($domain|tonumber),manifestSha256:$msha,configSha256:$csha},config:$config,genesis:$genesis,manifest:$manifest,
   publicSocket:$public,privateSocket:$private,operatorWorkspace:$sponsor,memberInventory:$inventory,
   custody:{completionSeed:$cseed,completionPublic:$cpub,
     owner:{subject:$ms,keyId:$mk,keyEpoch:"2",seed:$mseed,publicKey:$mpub},
     management:{subject:$ms,keyId:$mk,keyEpoch:"2",seed:$mseed,publicKey:$mpub}},
   authority:$authority}' >"$out/platform-inputs.json"
# ── the metered workroom: parent reserved, tool attached (workroom-ready.sh) ──────
bash "$here/workroom-ready.sh" "$world" "$out/evidence/workroom" || refuse "the metered workroom is not ready"
# The rooms phase creates "<op>-room" (composed-scenario.py generate; the gate passes op "jd3"); every member
# holds it under that name, so the app and the resident adopt that room.
op=${COMPOSED_OP:-jd3}
# ── the selection: owner, members, package, unused ids ───────────────────────────
spk=${MINI_TEST_SPK:-$("$here/fetch-test-spk.sh")}
names=$(jq -r '.members | keys[]' "$world")
owner=$(sed -n 2p <<<"$names"); member=$(sed -n 3p <<<"$names"); reader=$(sed -n 4p <<<"$names"); reviewer=$(sed -n 1p <<<"$names")
jq -n --arg evidence "$out/evidence" --arg grains "$grains" --arg broker "$broker" --arg spk "$spk" --arg sha "$(sha256sum "$spk" | cut -d ' ' -f1)" \
  --arg owner "$owner" --arg member "$member" --arg op "$op" '
  {protocol:"mini-spk-same-store-selection-v1",evidence:$evidence,grainsRoot:$grains,brokerSocket:$broker,
   package:{path:$spk,sha256:$sha},sizeClass:"S",
   app:{owner:$owner,room:($op+"-room"),members:{owner:{subject:$owner,expectedHost:"grain-owner.test"},member:{subject:$member,expectedHost:"grain-member.test"}},
        resources:"930001",capabilities:"960001"}}' >"$out/app-selection.json"
# ── the documents binding: four distinct members, their own workspaces ───────────
jq -n --arg manifest "$out/manifest.json" --arg msha "$(sha256sum "$out/manifest.json" | cut -d ' ' -f1)" --arg config "$config" --arg socket "$socket" \
  --arg store "$node" --slurpfile w "$world" --arg owner "$owner" --arg member "$member" --arg reader "$reader" --arg reviewer "$reviewer" '
  $w[0].members as $m | {protocol:"mini-protected-same-store-v1",manifestPath:$manifest,manifestSha256:$msha,configPath:$config,socketPath:$socket,storePath:$store,
   owner:{workspace:$m[$owner].workspace,home:$m[$owner].home},member:{workspace:$m[$member].workspace,home:$m[$member].home},
   reader:{workspace:$m[$reader].workspace,home:$m[$reader].home},reviewer:{workspace:$m[$reviewer].workspace,home:$m[$reviewer].home}}' >"$out/documents-binding.json"
# ── the resident binding: the typed resident's fixtures and the room the rooms phase makes ───
jq -n --arg inputs "$out/platform-inputs.json" --arg base "$(dirname "$node")" --arg a0 "$owner" --arg a1 "$member" --arg witness "$reader" \
  --arg reference "$(jq -r --arg o "$owner" '.members[$o].workspace' "$world")/refs/${op}-room.notes.json" --arg registration "$out/resident-registration-receipt.json" \
  --arg op "$op" --arg acp "$repo/testing/journeys/shared-resident-fixture-acp" --arg acpsha "$(sha256sum "$repo/testing/journeys/shared-resident-fixture-acp" | cut -d ' ' -f1)" \
  --arg prov "$repo/testing/journeys/shared-resident-fixture-provider.py" --arg provsha "$(sha256sum "$repo/testing/journeys/shared-resident-fixture-provider.py" | cut -d ' ' -f1)" '
  {protocol:"mini-same-world-resident-binding-v1",platformInputs:$inputs,base:$base,authors:[$a0,$a1],providerWitness:$witness,
   room:{alias:($op+"-room"),mode:"adopt"},sharedDocumentReference:$reference,registration:$registration,task:8802,
   fixtureAcp:{path:$acp,sha256:$acpsha},fixtureProvider:{path:$prov,sha256:$provsha},requestCounts:[1,1],preserveOnSuccess:true}' >"$out/resident-binding.json"
printf -- '--app-world-inputs %s %s --documents-binding %s --residents-binding %s\n' "$out/platform-inputs.json" "$out/app-selection.json" "$out/documents-binding.json" "$out/resident-binding.json" >"$out/composed-args.txt"
printf 'COMPOSED INPUTS store=%s grains=%s broker=%s\n' "$store" "$grains" "$broker" | tee -a "$out/result.log"
cat "$out/composed-args.txt"

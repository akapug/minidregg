# native/resource-client/journey.d/lib/evidence.sh -- evidence helpers the acceptance scripts share.
#
#   . "$REPO/native/resource-client/journey.d/lib/evidence.sh"
#
# sha256 [ARGS...]: `sha256sum` where the box has it (every Linux box: dregg-ref has no `shasum`),
# else `shasum -a 256` (macOS). Both print `HEX  NAME` and both take `-c FILE`.
#
# durable_image STORE_ROOT OUTPUT [CONFIG]: the Store's durable image (seed and every log record),
# read under the Store's own anchor identity as the Host's transport opens it (`Config.anchorIdentity`,
# printed by `HOST CONFIG profile` as storeAnchorIdentity, never re-derived here). CONFIG defaults
# to $CONFIG; HOST and STORE_BINARY are the caller's. The legacy single-blob `read-to` image no longer
# exists: the Store keeps a durable log, so `read-to` refuses ("published byte record is missing").

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

durable_image() {
  _image_id=$("$HOST" "${3:-$CONFIG}" profile | jq -er .storeAnchorIdentity) || return 2
  "$STORE_BINARY" --anchor-identity "$_image_id" durable-read "$1" 1 1 "$2"
}

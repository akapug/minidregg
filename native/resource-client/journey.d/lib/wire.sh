# native/resource-client/journey.d/lib/wire.sh -- wire constants a hand-authored intent carries,
# read from the Lean the Host is compiled from, so a script never holds a second literal.
#
#   . "$REPO/native/resource-client/journey.d/lib/wire.sh"
#   version=$(content_command_version "$REPO")
#
# content_command_version REPO prints `Kernel/ContentResource.commandVersion`: the schemaVersion of
# an invocation target whose payload is `content` or `read` (Kernel/ResourceTransaction refuses any
# other with unsupportedVersion). A scalar target's version is the scalar grammar's own 1.

lean_nat_def() {  # FILE NAME: the value of `def NAME : Nat := N` in FILE
  value=$(sed -n "s/^def $2 : Nat := \([0-9][0-9]*\)\$/\1/p" "$1")
  case "$value" in
    ''|*[!0-9]*) echo "wire.sh: no single \`def $2 : Nat\` in $1" >&2; return 2 ;;
  esac
  printf '%s\n' "$value"
}

content_command_version() { lean_nat_def "$1/Kernel/ContentResource.lean" commandVersion; }

# response_marker REPO SYMBOL prints a Host reply marker's byte from the registry
# (protocol/host-operations.json `response_markers`), e.g. NO_RECORD: the reply to a request the
# Host refused before any append.
response_marker() {
  jq -er --arg s "$2" '[.response_markers[] | select(.symbol == $s) | .code] |
    if length == 1 then .[0] else error("no single response marker \($s)") end' \
    "$1/protocol/host-operations.json"
}

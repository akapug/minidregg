#!/usr/bin/env bash
# check-fixture-authority.sh RANGE -- the fixture-authority gate row (cv 01a1147b-103d).
#
# Over the commits of RANGE (e.g. main..next, or a queued lane range):
#   1. a commit that changes an AUTHORITY file (scripts/pipeline/fixture-authorities.txt, column 3, or a
#      `self` row's file) changes nothing in Kernel/, Compiler/, Host/, Theory/ or native/ (one commit may
#      not move the implementation and the answer that tests it together), and carries an
#      `Authority-Change: <reason>` trailer;
#   2. a commit that changes a file that LOOKS generated (*FixtureData*, golden/, *.snapshot,
#      native/*/fixtures/) has it listed in fixture-authorities.txt (no unlisted generated fixture).
# It prints each authority-change commit (the keeper logs them as semantic changes) and exits 1 on a
# violation, naming the commit and the files.
#
# Renames: commits are read with `git diff-tree -M` (default 50% similarity), so a moved file is ONE entry
# under its new path and is judged there exactly as a modification of that path would be: a renamed
# authority is an authority change (trailer, no implementation in the commit) whether or not its content
# moved, and a renamed generated file must be listed under its new path. A deletion is still reported as
# a deletion. Shape (b) of ROOT 10-17: -M with the renamed path judged as a modification, not -M100%.
# Self-test (runs first, every call; FIXTURE_AUTHORITY_SELFTEST=0 inside it): in a scratch repository,
# a rename that also edits the authority without the trailer must go RED, a plain authority edit without
# the trailer must go RED (control), and a rename of the authority with the trailer and no
# implementation must pass.
set -euo pipefail
range=${1:?usage: check-fixture-authority.sh RANGE}
if [ "${FIXTURE_AUTHORITY_SELFTEST:-1}" = 1 ]; then
  self=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
  st=$(mktemp -d); trap 'rm -rf "$st"' EXIT
  (
    # `sed -i` differs between GNU and BSD sed (BSD reads the script as the backup suffix and edits nothing,
    # so the control commit was empty and the gate looked green): edit through a temp file instead.
    sedi() { local e=$1 f=$2; sed "$e" "$f" > "$f.new" && mv "$f.new" "$f"; }
    set -e; cd "$st"; git init -q .; git config user.email st@local; git config user.name selftest
    mkdir -p scripts/pipeline A B
    printf 'B/FooFixtureData.lean | gen.sh | B/FooAuthority.lean | checked\n' > scripts/pipeline/fixture-authorities.txt
    printf 'key1 = 1\nkey2 = 2\nkey3 = 3\nkey4 = 4\n' > A/FooAuthority.lean
    git add -A; git commit -qm base; base=$(git rev-parse HEAD)
    git mv A/FooAuthority.lean B/FooAuthority.lean; sedi 's/key4 = 4/key4 = 5/' B/FooAuthority.lean
    git add -A; git commit -qm "rename and edit, no trailer"
    if FIXTURE_AUTHORITY_SELFTEST=0 bash "$self" "$base..HEAD" >out 2>&1; then echo "self-test FAIL: a rename that edits the authority without a trailer passed"; exit 1; fi
    grep -q "without an Authority-Change: trailer" out || { echo "self-test FAIL: rename+edit red for the wrong reason: $(cat out)"; exit 1; }
    git reset -q --hard "$base"; sedi 's/key4 = 4/key4 = 5/' A/FooAuthority.lean
    sedi 's#B/FooAuthority.lean#A/FooAuthority.lean#' scripts/pipeline/fixture-authorities.txt
    git commit -qam "plain edit, no trailer"
    if FIXTURE_AUTHORITY_SELFTEST=0 bash "$self" "$base..HEAD" >out 2>&1; then echo "self-test FAIL: a plain authority edit without a trailer passed (control)"; exit 1; fi
    grep -q "without an Authority-Change: trailer" out || { echo "self-test FAIL: the control went red for the wrong reason: $(cat out)"; exit 1; }
    git reset -q --hard "$base"; git mv A/FooAuthority.lean B/FooAuthority.lean
    git commit -qm "move the authority" -m "Authority-Change: path only"
    FIXTURE_AUTHORITY_SELFTEST=0 bash "$self" "$base..HEAD" >out 2>&1 || { echo "self-test FAIL: an exact rename with the trailer went red: $(cat out)"; exit 1; }
  ) || { echo "fixture-authority: RED (self-test)"; exit 1; }
  echo "fixture-authority: self-test PASS (rename+edit without trailer RED; plain edit without trailer RED; rename with trailer OK)"
fi
root=$(git rev-parse --show-toplevel)
table=$root/scripts/pipeline/fixture-authorities.txt
mapfile -t rows < <(grep -v '^\s*#' "$table" | grep -v '^\s*$')
authorities=() ; generated=()
for row in "${rows[@]}"; do
  IFS='|' read -r gen _ auth status <<<"$row"
  gen=$(echo "$gen" | xargs); auth=$(echo "$auth" | xargs); status=$(echo "$status" | xargs)
  generated+=("$gen")
  [ "$auth" != "-" ] && authorities+=("$auth")
done
is_authority() { local f=$1 a; for a in "${authorities[@]}"; do [ "$f" = "$a" ] && return 0; done; return 1; }
is_listed() { local f=$1 g; for g in "${generated[@]}"; do [[ "$f" == $g ]] && return 0; done; return 1; }
looks_generated() { [[ "$1" == *FixtureData* || "$1" == */golden/* || "$1" == *.snapshot || "$1" == native/*/fixtures/* ]]; }
red=0
for commit in $(git rev-list --reverse "$range"); do
  mapfile -t files < <(git diff-tree -M --no-commit-id --name-only -r "$commit")
  auth_files=() ; impl_files=() ; unlisted=()
  for f in "${files[@]}"; do
    is_authority "$f" && auth_files+=("$f")
    case "$f" in Kernel/*|Compiler/*|Host/*|Theory/*|native/*) is_authority "$f" || impl_files+=("$f");; esac
    if looks_generated "$f" && ! is_listed "$f" && ! is_authority "$f"; then unlisted+=("$f"); fi
  done
  subject=$(git log -1 --format=%s "$commit")
  if [ ${#auth_files[@]} -gt 0 ]; then
    trailer=$(git log -1 --format=%B "$commit" | grep -m1 '^Authority-Change:' || true)
    echo "fixture-authority: AUTHORITY CHANGE $commit ${auth_files[*]} -- ${trailer:-<no trailer>} ($subject)"
    if [ ${#impl_files[@]} -gt 0 ]; then
      echo "fixture-authority: RED $commit changes the authority (${auth_files[*]}) AND the implementation (${impl_files[*]:0:5}...) in one commit" >&2
      red=1
    fi
    if [ -z "$trailer" ]; then
      echo "fixture-authority: RED $commit changes an authority without an Authority-Change: trailer" >&2
      red=1
    fi
  fi
  if [ ${#unlisted[@]} -gt 0 ]; then
    echo "fixture-authority: RED $commit changes generated-looking files with no row in fixture-authorities.txt: ${unlisted[*]}" >&2
    red=1
  fi
done
[ $red = 0 ] && echo "fixture-authority: OK over $range"
exit $red

#!/usr/bin/env bash
#
# End-to-end smoke test for the METIS programs.
#
# Runs every command line program against the sample inputs in Graphs/ and
# checks both the exit status and that the partition actually produced is
# well formed. Building the library is not enough of a signal on its own:
# the GKfree() prototype bug this suite was written for compiled fine and
# then corrupted the heap at run time.
#
# Usage: .github/scripts/smoke-test.sh <build-dir> [source-dir]
set -uo pipefail

BUILD_DIR=${1:?usage: smoke-test.sh <build-dir> [source-dir]}
SRC_DIR=${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}

BUILD_DIR=$(cd "$BUILD_DIR" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$SRC_DIR"/Graphs/* "$WORK"/
cd "$WORK" || exit 1

# Graphs/ ships a committed 4elt.graph.part.10 reference. Remove any prebuilt
# partition files so that check_partition() can only ever pass on output this
# run actually produced, not on a stale copy.
rm -f ./*.part.* ./*.npart.* ./*.epart.*

failures=0
pass() { printf '  ok   %-12s %s\n' "$1" "$2"; }
fail() { printf '  FAIL %-12s %s\n' "$1" "$2"; failures=$((failures + 1)); }

# Resolve a program name to its built binary (.exe on Windows).
bin() {
  for c in "$BUILD_DIR/$1" "$BUILD_DIR/$1.exe"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

# run <name> <expected-substring> <args...>
run() {
  local name=$1 expect=$2; shift 2
  local exe out rc
  if ! exe=$(bin "$name"); then fail "$name" "binary not found in $BUILD_DIR"; return; fi
  out=$("$exe" "$@" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    fail "$name" "exited $rc"
    printf '%s\n' "$out" | tail -n 5 | sed 's/^/       | /'
    return
  fi
  if [ -n "$expect" ] && ! grep -q "$expect" <<<"$out"; then
    fail "$name" "output missing '$expect'"
    printf '%s\n' "$out" | tail -n 5 | sed 's/^/       | /'
    return
  fi
  pass "$name" "$(grep -m1 -E "$expect" <<<"$out" 2>/dev/null | sed 's/^ *//' || echo 'exit 0')"
}

# check_partition <file> <expected-vertices> <expected-parts>
check_partition() {
  local file=$1 want_v=$2 want_p=$3 got_v got_p
  if [ ! -f "$file" ]; then fail "partition" "$file was not written"; return; fi
  got_v=$(grep -c . "$file")
  got_p=$(sort -u "$file" | grep -c .)
  if [ "$got_v" -ne "$want_v" ]; then
    fail "partition" "$file has $got_v vertices, expected $want_v"; return
  fi
  if [ "$got_p" -ne "$want_p" ]; then
    fail "partition" "$file has $got_p parts, expected $want_p"; return
  fi
  pass "partition" "$file: $got_v vertices across $got_p parts"
}

echo "Smoke testing binaries in $BUILD_DIR"

run graphchk   "format of the graph is correct" 4elt.graph
run pmetis     "Edge-Cut"                       4elt.graph 10
check_partition 4elt.graph.part.10 15606 10
run kmetis     "Edge-Cut"                       4elt.graph 16
check_partition 4elt.graph.part.16 15606 16
run oemetis    "Nonzeros"                       4elt.graph
run onmetis    "Nonzeros"                       4elt.graph
run mesh2dual  "Dual"                           metis.mesh
run mesh2nodal "Nodal"                          metis.mesh
run partdmesh  "Edge-Cut"                       metis.mesh 4
run partnmesh  ""                               metis.mesh 4

echo
if [ $failures -ne 0 ]; then
  echo "SMOKE TEST FAILED ($failures failure(s))"
  exit 1
fi
echo "SMOKE TEST PASSED"

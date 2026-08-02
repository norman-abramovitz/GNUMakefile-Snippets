#!/bin/sh
# run-tests.sh — run every tests/test-*.sh; a test passes iff it exits 0.
set -u
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fail=0; total=0
for t in "$dir"/test-*.sh; do
    [ -e "$t" ] || { echo "no tests found in $dir" >&2; exit 1; }
    total=$((total + 1))
    if out=$(sh "$t" 2>&1); then
        echo "PASS $(basename "$t")"
    else
        fail=$((fail + 1))
        echo "FAIL $(basename "$t")"
        printf '%s\n' "$out" | sed 's/^/     /'
    fi
done
echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]

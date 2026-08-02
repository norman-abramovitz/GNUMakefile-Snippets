#!/bin/sh
# test-wrapper.sh — make targets drive the scripts from a consumer mount.
set -eu
. "$(dirname "$0")/helpers.sh"
make_upstream
make_consumer
export SNIPPETS_REMOTE="$FIX/upstream"
cp "$SNIP"/snippets-*.sh "$SNIP/snippets.mk" "$FIX/consumer/mk/snippets/"
printf 'include mk/snippets/snippets.mk\n' > "$FIX/consumer/Makefile"

# offline status through make: clean copy → exit 0, says clean
(cd "$FIX/consumer" && make --no-print-directory snippets-status SNIPPETS_OFFLINE=yes) \
    > "$FIX/out" || fail "wrapper offline status exit"
grep -q 'clean' "$FIX/out" || fail "wrapper status output"

# stale copy through make: recipe fails (nonzero), then merge fixes it
rc=0
(cd "$FIX/consumer" && make --no-print-directory snippets-status) > "$FIX/out" 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "wrapper should fail on stale"
(cd "$FIX/consumer" && make --no-print-directory snippets-merge) > "$FIX/out" \
    || fail "wrapper merge exit"
(cd "$FIX/consumer" && make --no-print-directory snippets-status) > /dev/null \
    || fail "not current after wrapper merge"

echo ok

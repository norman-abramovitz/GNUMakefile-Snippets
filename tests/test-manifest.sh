#!/bin/sh
# test-manifest.sh — generation, stock verification, staleness gate.
set -eu
. "$(dirname "$0")/helpers.sh"
mkdir -p "$FIX/tree"
printf 'a\n' > "$FIX/tree/a.mk"
printf 'b\n' > "$FIX/tree/b.sh"

sh "$SNIP/snippets-manifest.sh" -C "$FIX/tree" -o example/upstream -T snippets/ \
    || fail "generate exit"
MF="$FIX/tree/snippets.sha256"
[ -f "$MF" ] || fail "no manifest"
grep -q '^# origin: example/upstream$' "$MF" || fail "origin header"
grep -q '^# tree: snippets/$' "$MF" || fail "tree header"
grep -q '  a.mk$' "$MF" || fail "a.mk entry"
grep -q '  b.sh$' "$MF" || fail "b.sh entry"
grep -q 'snippets.sha256' "$MF" && fail "manifest lists itself"

# stock tool verifies the generated file
(cd "$FIX/tree" && \
    { sha256sum -c snippets.sha256 2>/dev/null || shasum -a 256 -c snippets.sha256 2>/dev/null; } \
    | grep -q 'a.mk: OK') || fail "stock -c verification"

# check mode: fresh → 0, after an edit → 1
sh "$SNIP/snippets-manifest.sh" -C "$FIX/tree" -o example/upstream -T snippets/ -c \
    || fail "fresh check should pass"
printf 'a2\n' > "$FIX/tree/a.mk"
rc=0
sh "$SNIP/snippets-manifest.sh" -C "$FIX/tree" -o example/upstream -T snippets/ -c || rc=$?
[ "$rc" -eq 1 ] || fail "stale check exit $rc"

echo ok

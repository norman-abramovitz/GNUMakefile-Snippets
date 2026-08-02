#!/bin/sh
# test-patch.sh — local delta extraction, applicable upstream.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
make_consumer
export SNIPPETS_REMOTE="$FIX/upstream"
F="$FIX/consumer/mk/snippets/demo.mk"

# local edit → patch file with upstream-relative paths
edit_local "$F"
(cd "$FIX" && sh "$SNIP/snippets-patch.sh" -m "$M") > "$FIX/out" || fail "patch exit"
P="$FIX/snippets-patches/demo.mk.patch"
[ -f "$P" ] || fail "no patch written"
grep -q '+line7 LOCAL' "$P" || fail "patch content"
grep -q 'a/snippets/demo.mk' "$P" || fail "upstream-relative label"

# the patch applies cleanly in the upstream repo
git -C "$FIX/upstream" apply --check "$P" || fail "patch does not apply upstream"

# unchanged copy → no patch, exit 0
make_consumer
rm -rf "$FIX/snippets-patches"
(cd "$FIX" && sh "$SNIP/snippets-patch.sh" -m "$M") || fail "unchanged exit"
[ ! -e "$FIX/snippets-patches/demo.mk.patch" ] || fail "patch for unchanged file"

# DRYRUN writes nothing
edit_local "$F"
(cd "$FIX" && DRYRUN=yes sh "$SNIP/snippets-patch.sh" -m "$M") > "$FIX/out" || fail "dryrun exit"
grep -q 'DRYRUN' "$FIX/out" || fail "no dryrun preview"
[ ! -e "$FIX/snippets-patches/demo.mk.patch" ] || fail "dryrun wrote a patch"

echo ok

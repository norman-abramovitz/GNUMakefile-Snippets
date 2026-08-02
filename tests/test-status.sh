#!/bin/sh
# test-status.sh — classification states and exit codes.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
export SNIPPETS_REMOTE="$FIX/upstream"

status() { sh "$SNIP/snippets-status.sh" "$@"; }
state_of() { awk -F'\t' -v p="$2" '$2 == p { print $1; exit }' "$1"; }

# stale: vendored v-0.1.0, upstream moved to v-0.2.0
make_consumer
rc=0; status -m "$M" > "$FIX/s" || rc=$?
[ "$rc" -eq 1 ] || fail "stale exit $rc"
[ "$(state_of "$FIX/s" demo.mk)" = "stale" ] || fail "want stale: $(cat "$FIX/s")"

# diverged: local edit on top of stale
edit_local "$FIX/consumer/mk/snippets/demo.mk"
rc=0; status -m "$M" > "$FIX/s" || rc=$?
[ "$rc" -eq 1 ] || fail "diverged exit $rc"
[ "$(state_of "$FIX/s" demo.mk)" = "diverged" ] || fail "want diverged"

# offline: same edit is locally-modified; clean copy is clean; exits 1 then 0
rc=0; status -m "$M" -o > "$FIX/s" || rc=$?
[ "$rc" -eq 1 ] || fail "offline modified exit $rc"
[ "$(state_of "$FIX/s" demo.mk)" = "locally-modified" ] || fail "want locally-modified"
make_consumer
status -m "$M" -o > "$FIX/s" || fail "offline clean should exit 0"
[ "$(state_of "$FIX/s" demo.mk)" = "clean" ] || fail "want clean"

# current: vendored at the newest tag
rev2=$(git -C "$FIX/upstream" rev-parse v-0.2.0)
git -C "$FIX/upstream" show v-0.2.0:snippets/demo.mk > "$FIX/consumer/mk/snippets/demo.mk"
sha2=$(sl_sha256 "$FIX/consumer/mk/snippets/demo.mk")
sl_update_entry "$M" demo.mk "$sha2" "$rev2" v-0.2.0 2026-08-02
status -m "$M" > "$FIX/s" || fail "current should exit 0"
[ "$(state_of "$FIX/s" demo.mk)" = "current" ] || fail "want current"

# ahead: local edit while upstream is unchanged at the newest tag
edit_local "$FIX/consumer/mk/snippets/demo.mk"
rc=0; status -m "$M" > "$FIX/s" || rc=$?
[ "$rc" -eq 1 ] || fail "ahead exit $rc"
[ "$(state_of "$FIX/s" demo.mk)" = "ahead" ] || fail "want ahead"

# unknown: rev '-' routes to pin; missing: file gone
make_consumer
sl_update_entry "$M" demo.mk "$(sl_sha256 "$FIX/consumer/mk/snippets/demo.mk")" - - -
rc=0; status -m "$M" > "$FIX/s" || rc=$?
[ "$(state_of "$FIX/s" demo.mk)" = "unknown" ] || fail "want unknown"
make_consumer
rm "$FIX/consumer/mk/snippets/demo.mk"
rc=0; status -m "$M" > "$FIX/s" || rc=$?
[ "$(state_of "$FIX/s" demo.mk)" = "missing" ] || fail "want missing"

# mixed revs across entries is called out
make_consumer
cp "$FIX/consumer/mk/snippets/demo.mk" "$FIX/consumer/mk/snippets/other.mk"
sl_update_entry "$M" other.mk "$(sl_sha256 "$FIX/consumer/mk/snippets/other.mk")" \
    "$(git -C "$FIX/upstream" rev-parse v-0.2.0)" v-0.2.0 2026-08-02
rc=0; status -m "$M" -o > "$FIX/s" || rc=$?
grep -q 'mixed revs' "$FIX/s" || fail "mixed revs not reported"

echo ok

#!/bin/sh
# test-report.sh — prose covers each drift direction, with diff evidence.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
export SNIPPETS_REMOTE="$FIX/upstream"
F="$FIX/consumer/mk/snippets/demo.mk"
report() { sh "$SNIP/snippets-report.sh" -m "$M"; }

# stale: names the move and shows the upstream diff
make_consumer
report > "$FIX/r" || fail "report exit (stale)"
grep -q 'Upstream moved' "$FIX/r" || fail "stale prose"
grep -q '^   +line1 demo v2' "$FIX/r" || fail "stale diff evidence"

# diverged: names both sides, shows both diffs
edit_local "$F"
report > "$FIX/r" || fail "report exit (diverged)"
grep -q 'Both sides changed' "$FIX/r" || fail "diverged prose"
grep -q '^   +line1 demo v2' "$FIX/r" || fail "diverged upstream diff"
grep -q '^   +line7 LOCAL' "$FIX/r"   || fail "diverged local diff"

# ahead: suggests contributing back
make_consumer
rev2=$(git -C "$FIX/upstream" rev-parse v-0.2.0)
git -C "$FIX/upstream" show v-0.2.0:snippets/demo.mk > "$F"
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" "$rev2" v-0.2.0 2026-08-02
edit_local "$F"
report > "$FIX/r" || fail "report exit (ahead)"
grep -q 'snippets-patch' "$FIX/r" || fail "ahead prose"

# current: says so
make_consumer
git -C "$FIX/upstream" show v-0.2.0:snippets/demo.mk > "$F"
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" "$rev2" v-0.2.0 2026-08-02
report > "$FIX/r" || fail "report exit (current)"
grep -q 'Current' "$FIX/r" || fail "current prose"

echo ok

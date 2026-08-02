#!/bin/sh
# test-merge.sh — three-way merge: clean, conflicting, fallback, DRYRUN.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
export SNIPPETS_REMOTE="$FIX/upstream"
F="$FIX/consumer/mk/snippets/demo.mk"
merge() { sh "$SNIP/snippets-merge.sh" "$@"; }

# stale, no local edits: fast-forwards to v-0.2.0, manifest advances
make_consumer
merge -m "$M" > "$FIX/out" || fail "clean merge exit"
grep -q 'demo.mk: merged to v-0.2.0' "$FIX/out" || fail "merge message"
git -C "$FIX/upstream" show v-0.2.0:snippets/demo.mk > "$FIX/expect"
cmp -s "$F" "$FIX/expect" || fail "content after clean merge"
row=$(sl_entry "$M" demo.mk)
[ "$(printf '%s' "$row" | cut -f4)" = "v-0.2.0" ] || fail "manifest tag not advanced"
[ "$(printf '%s' "$row" | cut -f2)" = "$(sl_sha256 "$F")" ] || fail "manifest sha not advanced"
sh "$SNIP/snippets-status.sh" -m "$M" > /dev/null || fail "not current after merge"

# diverged, non-overlapping: both sides' changes land, exit 0
make_consumer
edit_local "$F"
merge -m "$M" > "$FIX/out" || fail "diverged merge exit"
grep -q '^line1 demo v2$' "$F" || fail "upstream change missing"
grep -q '^line7 LOCAL$'  "$F" || fail "local change lost"

# same-line edits: conflict markers, exit 1, manifest still advances
make_consumer
sed 's/^line1 demo$/line1 CONFLICT/' "$F" > "$F.t" && mv "$F.t" "$F"
rc=0; merge -m "$M" > "$FIX/out" || rc=$?
[ "$rc" -eq 1 ] || fail "conflict exit $rc"
grep -q '<<<<<<<' "$F" || fail "no conflict markers"
grep -q 'conflict' "$FIX/out" || fail "conflict not reported"
[ "$(printf '%s' "$(sl_entry "$M" demo.mk)" | cut -f4)" = "v-0.2.0" ] \
    || fail "manifest should advance on conflicted merge"

# as-vendored checksum broken: named fallback, two-way diff, file untouched
make_consumer
rev=$(git -C "$FIX/upstream" rev-parse v-0.1.0)
zeros=$(printf '%064d' 0)
sl_update_entry "$M" demo.mk "$zeros" "$rev" v-0.1.0 2026-08-02
cp "$F" "$FIX/before"
rc=0; merge -m "$M" > "$FIX/out" 2> "$FIX/err" || rc=$?
[ "$rc" -eq 1 ] || fail "fallback exit $rc"
grep -q 'FALLBACK' "$FIX/err" || fail "fallback not named"
cmp -s "$F" "$FIX/before" || fail "fallback touched the file"

# DRYRUN previews, changes nothing
make_consumer
cp "$F" "$FIX/before"
DRYRUN=yes merge -m "$M" > "$FIX/out" || fail "dryrun exit"
grep -q 'DRYRUN' "$FIX/out" || fail "no dryrun preview"
cmp -s "$F" "$FIX/before" || fail "dryrun touched the file"
[ "$(printf '%s' "$(sl_entry "$M" demo.mk)" | cut -f4)" = "v-0.1.0" ] \
    || fail "dryrun touched the manifest"

echo ok

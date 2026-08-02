#!/bin/sh
# test-pin.sh — history search and bootstrap stamping.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
export SNIPPETS_REMOTE="$FIX/upstream"
F="$FIX/consumer/mk/snippets/demo.mk"
pin() { sh "$SNIP/snippets-pin.sh" "$@"; }
rev1=$(git -C "$FIX/upstream" rev-parse v-0.1.0)
rev2=$(git -C "$FIX/upstream" rev-parse v-0.2.0)

# unknown provenance, pristine v-0.1.0 content → identified by history search
make_consumer
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" - - -
pin -m "$M" > "$FIX/out" || fail "pin exit"
row=$(sl_entry "$M" demo.mk)
[ "$(printf '%s' "$row" | cut -f3)" = "$rev1" ]    || fail "pinned rev"
[ "$(printf '%s' "$row" | cut -f4)" = "v-0.1.0" ]  || fail "pinned tag"

# locally edited copy matches no revision → rev: unknown, exit 1
make_consumer
edit_local "$F"
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" - - -
rc=0; pin -m "$M" > "$FIX/out" || rc=$?
[ "$rc" -eq 1 ] || fail "unidentified exit $rc"
[ "$(printf '%s' "$(sl_entry "$M" demo.mk)" | cut -f3)" = "unknown" ] || fail "unknown rev"

# bootstrap: -t stamps entries matching that tag's content
make_consumer
git -C "$FIX/upstream" show v-0.2.0:snippets/demo.mk > "$F"
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" - - -
pin -m "$M" -t v-0.2.0 > "$FIX/out" || fail "bootstrap exit"
row=$(sl_entry "$M" demo.mk)
[ "$(printf '%s' "$row" | cut -f3)" = "$rev2" ]   || fail "bootstrap rev"
[ "$(printf '%s' "$row" | cut -f4)" = "v-0.2.0" ] || fail "bootstrap tag"

# DRYRUN stamps nothing
make_consumer
sl_update_entry "$M" demo.mk "$(sl_sha256 "$F")" - - -
DRYRUN=yes pin -m "$M" > "$FIX/out" || fail "dryrun exit"
grep -q 'DRYRUN' "$FIX/out" || fail "no dryrun preview"
[ "$(printf '%s' "$(sl_entry "$M" demo.mk)" | cut -f3)" = "-" ] || fail "dryrun stamped"

echo ok

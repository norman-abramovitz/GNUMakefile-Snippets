#!/bin/sh
# test-lib.sh — manifest parse, checksum, atomic update.
set -eu
. "$(dirname "$0")/helpers.sh"
. "$SNIP/snippets-lib.sh"
make_upstream
make_consumer

# Headers
[ "$(sl_header "$M" origin)" = "example/upstream" ] || fail "origin header"
[ "$(sl_header "$M" tree)"   = "snippets/" ]        || fail "tree header"

# Entry row: path, sha-of-file, 40-char rev, tag
row=$(sl_entry "$M" demo.mk)
[ -n "$row" ] || fail "demo.mk not found in manifest"
[ "$(printf '%s' "$row" | cut -f1)" = "demo.mk" ] || fail "entry path"
sha=$(printf '%s' "$row" | cut -f2)
[ "$sha" = "$(sl_sha256 "$FIX/consumer/mk/snippets/demo.mk")" ] || fail "entry sha"
rev=$(printf '%s' "$row" | cut -f3)
[ "${#rev}" -eq 40 ] || fail "entry rev"
[ "$(printf '%s' "$row" | cut -f4)" = "v-0.1.0" ] || fail "entry tag"

# Stock-tool compatibility: shasum/sha256sum -c verifies despite comments
(cd "$FIX/consumer/mk/snippets" && \
    { sha256sum -c snippets.sha256 2>/dev/null || shasum -a 256 -c snippets.sha256 2>/dev/null; } \
    | grep -q 'demo.mk: OK') || fail "stock -c verification"

# Unparseable line is warned, not swallowed
echo 'garbage line' >> "$M"
err=$(sl_entries "$M" 2>&1 >/dev/null)
printf '%s' "$err" | grep -q 'unparseable' || fail "unparseable line not warned"

# Update in place: new sha/rev/tag, entry count unchanged
make_consumer
printf 'edited\n' > "$FIX/consumer/mk/snippets/demo.mk"
newsha=$(sl_sha256 "$FIX/consumer/mk/snippets/demo.mk")
newrev=$(git -C "$FIX/upstream" rev-parse v-0.2.0)
sl_update_entry "$M" demo.mk "$newsha" "$newrev" v-0.2.0 2026-08-02
row=$(sl_entry "$M" demo.mk)
[ "$(printf '%s' "$row" | cut -f2)" = "$newsha" ]  || fail "updated sha"
[ "$(printf '%s' "$row" | cut -f4)" = "v-0.2.0" ]  || fail "updated tag"
[ "$(sl_entries "$M" | wc -l | tr -d ' ')" = "1" ] || fail "duplicate entry after update"

# Append when untracked
sl_update_entry "$M" extra.sh "$newsha" "$newrev" v-0.2.0 2026-08-02
[ "$(sl_entries "$M" | wc -l | tr -d ' ')" = "2" ] || fail "append"

echo ok

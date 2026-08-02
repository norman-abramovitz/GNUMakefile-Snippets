#!/bin/sh
# test-fetch.sh — file-at-rev retrieval and latest-tag, offline via SNIPPETS_REMOTE.
set -eu
. "$(dirname "$0")/helpers.sh"
make_upstream
make_consumer
export SNIPPETS_REMOTE="$FIX/upstream"

# file at pinned rev matches git's own view
rev=$(git -C "$FIX/upstream" rev-parse v-0.1.0)
sh "$SNIP/snippets-fetch.sh" -m "$M" file demo.mk "$rev" "$FIX/out"
git -C "$FIX/upstream" show v-0.1.0:snippets/demo.mk > "$FIX/expect"
cmp -s "$FIX/out" "$FIX/expect" || fail "fetched content differs"

# latest-tag resolves the newest v-* tag with its commit
want="v-0.2.0 $(git -C "$FIX/upstream" rev-parse 'v-0.2.0^{commit}')"
got=$(sh "$SNIP/snippets-fetch.sh" -m "$M" latest-tag)
[ "$got" = "$want" ] || fail "latest-tag: got '$got' want '$want'"

# a prerelease of the same x.y.z must not outrank the release itself
git -C "$FIX/upstream" tag v-0.2.0-dev.1
got=$(sh "$SNIP/snippets-fetch.sh" -m "$M" latest-tag)
[ "$got" = "$want" ] || fail "latest-tag with prerelease tag: got '$got' want '$want'"

# two-digit minor/patch components must sort numerically, not lexically
(cd "$FIX/upstream" && $GIT commit -q --allow-empty -m three && git tag v-0.9.0 \
    && $GIT commit -q --allow-empty -m four && git tag v-0.10.0)
want2="v-0.10.0 $(git -C "$FIX/upstream" rev-parse 'v-0.10.0^{commit}')"
got2=$(sh "$SNIP/snippets-fetch.sh" -m "$M" latest-tag)
[ "$got2" = "$want2" ] || fail "latest-tag two-digit: got '$got2' want '$want2'"

# tag-rev resolves a named tag
want="v-0.1.0 $(git -C "$FIX/upstream" rev-parse 'v-0.1.0^{commit}')"
got=$(sh "$SNIP/snippets-fetch.sh" -m "$M" tag-rev v-0.1.0)
[ "$got" = "$want" ] || fail "tag-rev: got '$got' want '$want'"

# missing path: exit 3, named error
rc=0
err=$(sh "$SNIP/snippets-fetch.sh" -m "$M" file nope.mk "$rev" "$FIX/out2" 2>&1) || rc=$?
[ "$rc" -eq 3 ] || fail "missing path exit $rc, want 3"
printf '%s' "$err" | grep -q 'nope.mk' || fail "error does not name the path"

echo ok

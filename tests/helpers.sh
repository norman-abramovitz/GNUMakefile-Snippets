#!/bin/sh
# helpers.sh — sourced by every test. Builds throwaway fixtures in $FIX.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SNIP="$ROOT/snippets"
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT
GIT="git -c user.email=test@test -c user.name=test"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Fixture upstream: snippets/demo.mk with two tagged revisions. v2 changes
# only line1; local test edits touch only line7 — far enough apart that a
# three-way merge is clean, close enough that editing the SAME line conflicts.
make_upstream() {
    git init -q "$FIX/upstream"
    mkdir -p "$FIX/upstream/snippets"
    printf 'line1 demo\nline2\nline3\nline4\nline5\nline6\nline7\n' \
        > "$FIX/upstream/snippets/demo.mk"
    (cd "$FIX/upstream" && git add -A && $GIT commit -qm one && git tag v-0.1.0)
    sed 's/^line1 demo$/line1 demo v2/' "$FIX/upstream/snippets/demo.mk" \
        > "$FIX/upstream/snippets/demo.mk.t" \
        && mv "$FIX/upstream/snippets/demo.mk.t" "$FIX/upstream/snippets/demo.mk"
    (cd "$FIX/upstream" && git add -A && $GIT commit -qm two && git tag v-0.2.0)
}

# In-place local edit of a vendored copy, portable (no sed -i): line7 → LOCAL.
edit_local() { sed 's/^line7$/line7 LOCAL/' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

# Consumer that vendored demo.mk at v-0.1.0, manifest alongside.
make_consumer() {
    rev=$(git -C "$FIX/upstream" rev-parse v-0.1.0)
    mkdir -p "$FIX/consumer/mk/snippets"
    git -C "$FIX/upstream" show v-0.1.0:snippets/demo.mk \
        > "$FIX/consumer/mk/snippets/demo.mk"
    sha=$(. "$SNIP/snippets-lib.sh" && sl_sha256 "$FIX/consumer/mk/snippets/demo.mk")
    cat > "$FIX/consumer/mk/snippets/snippets.sha256" <<EOF
# snippets.sha256 — vendored-snippet lifecycle manifest
# origin: example/upstream
# tree: snippets/

# file: demo.mk  rev: $rev  tag: v-0.1.0  vendored: 2026-08-02
$sha  demo.mk
EOF
    M="$FIX/consumer/mk/snippets/snippets.sha256"
}

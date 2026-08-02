#!/bin/sh
# snippets-fetch.sh — retrieve upstream snippet content for the lifecycle verbs.
#
#   snippets-fetch.sh [-m manifest] file <relpath> <rev> <outfile>
#   snippets-fetch.sh [-m manifest] latest-tag
#
# SNIPPETS_REMOTE=<path-to-git-clone> replaces the network entirely
# (tests, mirrors, air-gapped builds). Exit: 0 ok, 2 usage, 3 unreachable.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

manifest="$here/snippets.sha256"
while getopts m: opt; do
    case $opt in m) manifest=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
[ -f "$manifest" ] || sl_die "no manifest: $manifest"
origin=$(sl_header "$manifest" origin)
tree=$(sl_header "$manifest" tree)

# Portable "highest vX.Y.Z" sort (no GNU sort -V): strip prefix, sort numerically.
semver_max() { sed 's/^v-//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1; }

cmd=${1:-}
case $cmd in
file)
    [ $# -eq 4 ] || sl_die "usage: snippets-fetch.sh file <relpath> <rev> <outfile>"
    rel=$2 rev=$3 out=$4
    if [ -n "${SNIPPETS_REMOTE:-}" ]; then
        git -C "$SNIPPETS_REMOTE" show "$rev:$tree$rel" > "$out" 2>/dev/null || {
            echo "ERROR: cannot read $tree$rel at $rev from $SNIPPETS_REMOTE" >&2
            rm -f "$out"; exit 3
        }
    else
        url="https://raw.githubusercontent.com/$origin/$rev/$tree$rel"
        curl -fsSL -o "$out" "$url" || {
            echo "ERROR: fetch failed (network?): $url" >&2
            rm -f "$out"; exit 3
        }
    fi
    ;;
latest-tag)
    if [ -n "${SNIPPETS_REMOTE:-}" ]; then
        best=$(git -C "$SNIPPETS_REMOTE" tag -l 'v-*' | semver_max)
        [ -n "$best" ] || { echo "ERROR: no v-* tags in $SNIPPETS_REMOTE" >&2; exit 3; }
        echo "v-$best $(git -C "$SNIPPETS_REMOTE" rev-parse "v-$best^{commit}")"
    else
        url="https://github.com/$origin.git"
        names=$(git ls-remote --tags "$url" 'refs/tags/v-*' 2>/dev/null \
            | awk '{print $2}' | sed 's#refs/tags/##; s/\^{}$//' | sort -u)
        best=$(printf '%s\n' "$names" | semver_max)
        [ -n "$best" ] || { echo "ERROR: cannot list v-* tags for $origin (network?)" >&2; exit 3; }
        # Prefer the peeled (^{}) line: annotated tags list the tag object first.
        rev=$(git ls-remote --tags "$url" "refs/tags/v-$best^{}" 2>/dev/null | awk '{print $1; exit}')
        [ -n "$rev" ] || rev=$(git ls-remote --tags "$url" "refs/tags/v-$best" 2>/dev/null | awk '{print $1; exit}')
        [ -n "$rev" ] || { echo "ERROR: cannot resolve v-$best (network?)" >&2; exit 3; }
        echo "v-$best $rev"
    fi
    ;;
tag-rev)
    [ $# -eq 2 ] || sl_die "usage: snippets-fetch.sh tag-rev <tag>"
    t=$2
    if [ -n "${SNIPPETS_REMOTE:-}" ]; then
        rev=$(git -C "$SNIPPETS_REMOTE" rev-parse "$t^{commit}" 2>/dev/null) \
            || { echo "ERROR: unknown tag $t in $SNIPPETS_REMOTE" >&2; exit 3; }
    else
        url="https://github.com/$origin.git"
        rev=$(git ls-remote --tags "$url" "refs/tags/$t^{}" 2>/dev/null | awk '{print $1; exit}')
        [ -n "$rev" ] || rev=$(git ls-remote --tags "$url" "refs/tags/$t" 2>/dev/null | awk '{print $1; exit}')
        [ -n "$rev" ] || { echo "ERROR: cannot resolve $t for $origin (network?)" >&2; exit 3; }
    fi
    echo "$t $rev"
    ;;
*)  sl_die "usage: snippets-fetch.sh [-m manifest] file|latest-tag|tag-rev ..." ;;
esac

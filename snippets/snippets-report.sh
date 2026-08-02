#!/bin/sh
# snippets-report.sh — plain-language account of where every file stands.
#
#   snippets-report.sh [-m manifest] [-t tag]
#
# Read-only companion to snippets-status: for each tracked file, what
# upstream changed since the pinned rev, what changed locally, and what a
# merge would mean — with the diffs as evidence. Needs upstream access
# (network or SNIPPETS_REMOTE).
# Exit: 0 (status is the gate, not this), 2 usage, 3 upstream unreachable.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

manifest="$here/snippets.sha256"; target=
while getopts m:t: opt; do
    case $opt in m) manifest=$OPTARG ;; t) target=$OPTARG ;; *) exit 2 ;; esac
done
[ -f "$manifest" ] || sl_die "no manifest: $manifest"
# shellcheck disable=SC1007
mdir=$(CDPATH= cd -- "$(dirname -- "$manifest")" && pwd)

tmp=$(mktemp -d) || sl_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

if [ -n "$target" ]; then
    line=$(sh "$here/snippets-fetch.sh" -m "$manifest" tag-rev "$target") || exit 3
else
    line=$(sh "$here/snippets-fetch.sh" -m "$manifest" latest-tag) || exit 3
fi
utag=${line%% *}; urev=${line#* }

indent() { sed 's/^/   /'; }

echo "Snippet report - comparing against $utag"
echo
sl_entries "$manifest" > "$tmp/entries"
tab=$(printf '\t')
while IFS="$tab" read -r path sha rev tag ven; do
    f="$mdir/$path"
    echo "== $path (vendored: $tag, $ven)"
    if [ ! -f "$f" ]; then
        echo "   Listed in the manifest but absent locally."; echo; continue
    fi
    if [ "$rev" = "-" ] || [ "$rev" = "unknown" ]; then
        echo "   No recorded origin revision - snippets-pin can identify it."
        echo; continue
    fi
    lsha=$(sl_sha256 "$f")
    if ! sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$urev" "$tmp/new" 2>/dev/null; then
        echo "   No longer present upstream at $utag."; echo; continue
    fi
    nsha=$(sl_sha256 "$tmp/new")
    why=
    if ! sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$rev" "$tmp/base" 2>/dev/null; then
        why="the pinned revision $rev cannot be fetched"
    elif [ "$(sl_sha256 "$tmp/base")" != "$sha" ]; then
        why="content at $rev does not match the as-vendored checksum"
    fi
    if [ -n "$why" ]; then
        echo "   Cannot verify the original vendored content: $why."
        echo "   Falling back to a two-way comparison with $utag:"
        diff -u "$f" "$tmp/new" | indent
        echo; continue
    fi
    up=no; loc=no
    [ "$nsha" = "$sha" ] || up=yes
    [ "$lsha" = "$sha" ] || loc=yes
    case "$up/$loc" in
    no/no)
        echo "   Current: upstream unchanged since vendoring, no local edits." ;;
    yes/no)
        echo "   Upstream moved ($tag -> $utag); no local edits, so"
        echo "   snippets-merge will fast-forward cleanly. Upstream changes:"
        diff -u "$tmp/base" "$tmp/new" | indent ;;
    no/yes)
        echo "   Carries local changes upstream does not have; upstream is"
        echo "   unchanged at $utag. Consider contributing them: snippets-patch."
        echo "   Local changes:"
        diff -u "$tmp/base" "$f" | indent ;;
    yes/yes)
        echo "   Both sides changed since $tag - snippets-merge will three-way"
        echo "   merge; overlapping hunks will conflict. Upstream changes:"
        diff -u "$tmp/base" "$tmp/new" | indent
        echo "   Local changes:"
        diff -u "$tmp/base" "$f" | indent ;;
    esac
    echo
done < "$tmp/entries"

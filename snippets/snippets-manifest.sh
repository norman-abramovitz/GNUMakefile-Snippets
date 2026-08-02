#!/bin/sh
# snippets-manifest.sh — (re)generate the authoritative upstream manifest.
#
#   snippets-manifest.sh [-C treedir] [-o origin] [-T tree] [-c]
#
# Writes treedir/snippets.sha256: origin/tree header plus one checksum
# line per regular file in the flat tree (manifest itself excluded),
# LC_ALL=C sorted. Provenance (rev/tag/vendored) is stamped consumer-side
# by snippets-pin — upstream ships checksums only.
#   -c   check: exit 1 if the existing manifest is stale (release gate).
# Exit: 0 fresh/regenerated, 1 stale (-c), 2 usage/environment.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

dir=$here; origin=norman-abramovitz/GNUMakefile-Snippets; tree=snippets/; check=no
while getopts C:o:T:c opt; do
    case $opt in
        C) dir=$OPTARG ;;
        o) origin=$OPTARG ;;
        T) tree=$OPTARG ;;
        c) check=yes ;;
        *) exit 2 ;;
    esac
done
[ -d "$dir" ] || sl_die "no such tree: $dir"

tmp=$(mktemp "$dir/snippets.sha256.XXXXXX") || sl_die "mktemp failed in $dir"
trap 'rm -f "$tmp"' EXIT
{
    echo "# snippets.sha256 — vendored-snippet lifecycle manifest"
    echo "# origin: $origin"
    echo "# tree: $tree"
    echo
    # shellcheck disable=SC2012,SC2045  # flat tree, names never contain spaces
    for f in $(ls "$dir" | LC_ALL=C sort); do
        [ -f "$dir/$f" ] || continue
        [ "$f" = "snippets.sha256" ] && continue
        case $f in snippets.sha256.*) continue ;; esac
        echo "$(sl_sha256 "$dir/$f")  $f"
    done
} > "$tmp"

if [ "$check" = yes ]; then
    if [ -f "$dir/snippets.sha256" ] && cmp -s "$tmp" "$dir/snippets.sha256"; then
        echo "manifest: fresh"
    else
        echo "ERROR: $dir/snippets.sha256 is stale - run: make manifest" >&2
        exit 1
    fi
elif sl_dryrun; then
    echo "DRYRUN: would write $dir/snippets.sha256"
else
    mv "$tmp" "$dir/snippets.sha256"
    # mktemp made this 0600; a manifest is meant to be readable like any
    # other vendored file. Best-effort - a failure here doesn't undo the
    # write.
    chmod 644 "$dir/snippets.sha256" 2>/dev/null || true
    trap - EXIT
    echo "wrote $dir/snippets.sha256"
fi

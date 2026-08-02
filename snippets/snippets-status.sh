#!/bin/sh
# snippets-status.sh — classify every tracked file against its provenance.
#
#   snippets-status.sh [-m manifest] [-o] [-t tag]
#
#   -o   offline: checksum classification only, upstream marked unchecked
#   -t   compare against a specific tag instead of the newest v-* tag
#
# One "state<TAB>path<TAB>note" line per file, set-level notes after.
# States: current clean locally-modified stale diverged ahead missing
#         unknown removed-upstream
# Exit: 0 all current/clean, 1 drift, 2 usage, 3 network needed.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

manifest="$here/snippets.sha256"; offline=no; target=
while getopts m:ot: opt; do
    case $opt in
        m) manifest=$OPTARG ;;
        o) offline=yes ;;
        t) target=$OPTARG ;;
        *) exit 2 ;;
    esac
done
[ -f "$manifest" ] || sl_die "no manifest: $manifest"
# shellcheck disable=SC1007
mdir=$(CDPATH= cd -- "$(dirname -- "$manifest")" && pwd)

tmp=$(mktemp -d) || sl_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

utag=; urev=
if [ "$offline" = no ]; then
    if [ -n "$target" ]; then
        line=$(sh "$here/snippets-fetch.sh" -m "$manifest" tag-rev "$target") || exit 3
    else
        line=$(sh "$here/snippets-fetch.sh" -m "$manifest" latest-tag) || exit 3
    fi
    utag=${line%% *}; urev=${line#* }
fi

sl_entries "$manifest" > "$tmp/entries"
drift=0
tab=$(printf '\t')
# shellcheck disable=SC2034
while IFS="$tab" read -r path sha rev tag ven; do
    f="$mdir/$path"; state=; note=
    if [ ! -f "$f" ]; then
        state=missing; note="vendored copy absent"
    elif [ "$rev" = "-" ] || [ "$rev" = "unknown" ]; then
        state=unknown; note="no provenance - run snippets-pin"
    else
        lsha=$(sl_sha256 "$f")
        if [ -z "$urev" ]; then
            if [ "$lsha" = "$sha" ]; then state=clean; note="matches as-vendored; upstream unchecked"
            else state=locally-modified; note="differs from as-vendored; upstream unchecked"
            fi
        else
            if sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$urev" "$tmp/u" 2>/dev/null; then
                usha=$(sl_sha256 "$tmp/u")
            else
                usha=
            fi
            if [ -z "$usha" ]; then
                state=removed-upstream; note="not present at $utag"
            elif [ "$usha" = "$sha" ]; then
                if [ "$lsha" = "$sha" ]; then state=current; note="at $utag"
                else state=ahead; note="local changes, upstream unchanged at $utag - snippets-patch"
                fi
            else
                if [ "$lsha" = "$sha" ]; then state=stale; note="upstream moved to $utag - snippets-merge"
                else state=diverged; note="both sides changed since ${tag} - snippets-merge"
                fi
            fi
        fi
    fi
    printf '%s\t%s\t%s\n' "$state" "$path" "$note"
    case $state in current|clean) ;; *) drift=1 ;; esac
done < "$tmp/entries"

nrev=$(cut -f3 "$tmp/entries" | grep -vE '^(-|unknown)$' | sort -u | wc -l | tr -d ' ')
if [ "$nrev" -gt 1 ]; then
    echo "note: mixed revs across files - vendored from $nrev different upstream commits"
    drift=1
fi
exit "$drift"

#!/bin/sh
# snippets-merge.sh — three-way merge of vendored files against upstream.
#
#   snippets-merge.sh [-m manifest] [-t tag] [path ...]
#
# base = upstream at the pinned rev, theirs = upstream at the target tag
# (newest v-* unless -t), mine = the local copy. Clean hunks apply;
# conflicts get standard markers. Every applied merge advances the
# manifest entry to the target rev/tag and new as-vendored checksum —
# conflict markers included, so status stays honest afterwards.
#
# Degradations, always named: base unfetchable or base != as-vendored
# checksum → two-way diff printed, file untouched. No provenance → skip,
# pin first. DRYRUN=yes previews everything and writes nothing.
# Exit: 0 all clean, 1 conflicts/fallbacks/skips, 2 usage, 3 network.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

manifest="$here/snippets.sha256"; target=
while getopts m:t: opt; do
    case $opt in m) manifest=$OPTARG ;; t) target=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
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

sl_entries "$manifest" > "$tmp/entries"
rc=0
tab=$(printf '\t')
# shellcheck disable=SC2034
while IFS="$tab" read -r path sha rev tag ven; do
    if [ $# -gt 0 ]; then
        case " $* " in *" $path "*) ;; *) continue ;; esac
    fi
    f="$mdir/$path"
    if [ ! -f "$f" ]; then
        sl_warn "$path: missing locally - skipped"; rc=1; continue
    fi
    if [ "$rev" = "-" ] || [ "$rev" = "unknown" ]; then
        sl_warn "$path: no provenance - run snippets-pin first"; rc=1; continue
    fi
    sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$urev" "$tmp/new" 2>/dev/null || {
        sl_warn "$path: not present upstream at $utag - skipped"; rc=1; continue; }
    nsha=$(sl_sha256 "$tmp/new")
    lsha=$(sl_sha256 "$f")
    if [ "$nsha" = "$sha" ] && [ "$lsha" = "$sha" ]; then
        echo "$path: already current"
        continue
    fi
    fallback=
    if ! sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$rev" "$tmp/base" 2>/dev/null; then
        fallback="cannot fetch base at $rev"
    elif [ "$(sl_sha256 "$tmp/base")" != "$sha" ]; then
        fallback="base at $rev does not match the as-vendored checksum"
    fi
    if [ -n "$fallback" ]; then
        echo "$path: FALLBACK - $fallback; two-way diff vs $utag follows, file untouched:" >&2
        diff -u "$f" "$tmp/new" >&2 || true
        rc=1; continue
    fi
    if sl_dryrun; then
        echo "DRYRUN: would merge $path: $tag ($rev) -> $utag ($urev)"
        continue
    fi
    # Non-git consumers are silently fine: rev-parse fails, the warning
    # is skipped, nothing else changes.
    if git -C "$mdir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && [ -n "$(git -C "$mdir" status --porcelain -- "$path" 2>/dev/null)" ]; then
        sl_warn "$path: has uncommitted changes in git - pre-merge content is not recoverable from history"
    fi
    cp "$f" "$tmp/work"
    conflicts=0
    git merge-file -L "$path (local)" -L "$path ($tag)" -L "$path ($utag)" \
        "$tmp/work" "$tmp/base" "$tmp/new" || conflicts=$?
    if [ "$conflicts" -ge 127 ]; then
        sl_warn "$path: git merge-file failed ($conflicts)"; rc=1; continue
    fi
    mv "$tmp/work" "$f"
    sl_update_entry "$manifest" "$path" "$nsha" "$urev" "$utag" "$(sl_today)"
    if [ "$conflicts" -gt 0 ]; then
        echo "$path: merged with $conflicts conflict(s) - resolve the markers"
        rc=1
    else
        echo "$path: merged to $utag"
    fi
done < "$tmp/entries"
exit "$rc"

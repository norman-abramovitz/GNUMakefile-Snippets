#!/bin/sh
# snippets-pin.sh — record provenance for vendored copies that lack it.
#
#   snippets-pin.sh [-m manifest] [-t tag] [path ...]
#
# Without -t: for every entry lacking provenance (explicit paths always),
# walk the upstream history of the file newest-first; the first revision
# whose content matches the local copy becomes rev (+ its v-* tag when one
# points at that commit). No match → rev: unknown is recorded and later
# verbs fall back to two-way comparison, honestly labelled.
# With -t TAG: bootstrap stamping after copying a release — every entry
# whose content matches TAG's content is stamped with TAG's commit.
# Needs a git history: SNIPPETS_REMOTE, else a temp clone (network).
# Exit: 0 all pinned, 1 something unidentified, 2 usage, 3 unreachable.
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
origin=$(sl_header "$manifest" origin)
tree=$(sl_header "$manifest" tree)

tmp=$(mktemp -d) || sl_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

repo=${SNIPPETS_REMOTE:-}
if [ -z "$repo" ]; then
    git clone -q "https://github.com/$origin.git" "$tmp/clone" 2>/dev/null \
        || { echo "ERROR: cannot clone $origin (network?)" >&2; exit 3; }
    repo="$tmp/clone"
fi

stamp() { # path sha rev
    _tag=$(git -C "$repo" tag -l 'v-*' --points-at "$3" | head -1)
    [ -n "$_tag" ] || _tag=-
    if sl_dryrun; then
        echo "DRYRUN: would pin $1 at $3 ($_tag)"
    else
        sl_update_entry "$manifest" "$1" "$2" "$3" "$_tag" "$(sl_today)"
        echo "$1: pinned at $3 ($_tag)"
    fi
}

trev=
if [ -n "$target" ]; then
    trev=$(git -C "$repo" rev-parse "$target^{commit}" 2>/dev/null) \
        || sl_die "unknown tag: $target"
fi

sl_entries "$manifest" > "$tmp/entries"
rc=0
tab=$(printf '\t')
# shellcheck disable=SC2034
while IFS="$tab" read -r path sha rev tag ven; do
    explicit=no
    if [ $# -gt 0 ]; then
        case " $* " in *" $path "*) explicit=yes ;; *) continue ;; esac
    fi
    if [ -z "$target" ] && [ "$explicit" = no ] \
        && [ "$rev" != "-" ] && [ "$rev" != "unknown" ]; then
        continue
    fi
    f="$mdir/$path"
    [ -f "$f" ] || { sl_warn "$path: missing locally - skipped"; rc=1; continue; }
    lsha=$(sl_sha256 "$f")
    if [ -n "$target" ]; then
        if git -C "$repo" show "$trev:$tree$path" > "$tmp/c" 2>/dev/null \
            && [ "$(sl_sha256 "$tmp/c")" = "$lsha" ]; then
            stamp "$path" "$lsha" "$trev"
        else
            sl_warn "$path: content does not match $target - left unpinned"
            rc=1
        fi
        continue
    fi
    hit=
    for r in $(git -C "$repo" log --format=%H -- "$tree$path"); do
        if git -C "$repo" show "$r:$tree$path" > "$tmp/c" 2>/dev/null \
            && [ "$(sl_sha256 "$tmp/c")" = "$lsha" ]; then
            hit=$r; break
        fi
    done
    if [ -n "$hit" ]; then
        stamp "$path" "$lsha" "$hit"
    else
        echo "$path: no upstream revision matches - recording rev: unknown" >&2
        sl_dryrun || sl_update_entry "$manifest" "$path" "$lsha" unknown - "$(sl_today)"
        rc=1
    fi
done < "$tmp/entries"
exit "$rc"

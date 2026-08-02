#!/bin/sh
# snippets-patch.sh — extract local-only changes as upstream-ready patches.
#
#   snippets-patch.sh [-m manifest] [-d outdir] [path ...]
#
# For each tracked file (default: all) whose content differs from its
# as-vendored checksum: verify the base at the pinned rev, then write
# <outdir>/<path>.patch as a unified diff base -> local, labelled with
# upstream-root-relative paths so it applies in the upstream repo:
#     git apply snippets-patches/demo.mk.patch
# DRYRUN=yes previews. Unchanged files produce no patch.
# Exit: 0 written or none needed, 1 fallback skips, 2 usage, 3 network.
set -u
# shellcheck disable=SC1007
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/snippets-lib.sh"

manifest="$here/snippets.sha256"; outdir=./snippets-patches
while getopts m:d: opt; do
    case $opt in m) manifest=$OPTARG ;; d) outdir=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
[ -f "$manifest" ] || sl_die "no manifest: $manifest"
# shellcheck disable=SC1007
mdir=$(CDPATH= cd -- "$(dirname -- "$manifest")" && pwd)
tree=$(sl_header "$manifest" tree)

tmp=$(mktemp -d) || sl_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

sl_entries "$manifest" > "$tmp/entries"
rc=0; wrote=0
tab=$(printf '\t')
# shellcheck disable=SC2034
while IFS="$tab" read -r path sha rev tag ven; do
    if [ $# -gt 0 ]; then
        case " $* " in *" $path "*) ;; *) continue ;; esac
    fi
    f="$mdir/$path"
    [ -f "$f" ] || { sl_warn "$path: missing locally - skipped"; rc=1; continue; }
    [ "$(sl_sha256 "$f")" != "$sha" ] || continue
    if [ "$rev" = "-" ] || [ "$rev" = "unknown" ]; then
        sl_warn "$path: no provenance - run snippets-pin first"; rc=1; continue
    fi
    if ! sh "$here/snippets-fetch.sh" -m "$manifest" file "$path" "$rev" "$tmp/base" 2>/dev/null; then
        sl_warn "$path: cannot fetch base at $rev - skipped"; rc=1; continue
    fi
    if [ "$(sl_sha256 "$tmp/base")" != "$sha" ]; then
        sl_warn "$path: base at $rev does not match the as-vendored checksum - skipped"
        rc=1; continue
    fi
    if sl_dryrun; then
        echo "DRYRUN: would write $outdir/$path.patch"
        continue
    fi
    mkdir -p "$outdir/$(dirname "$path")"
    diff -u -L "a/$tree$path" -L "b/$tree$path" "$tmp/base" "$f" \
        > "$outdir/$path.patch" || true
    echo "wrote $outdir/$path.patch"
    wrote=$((wrote + 1))
done < "$tmp/entries"
[ "$wrote" -gt 0 ] || sl_dryrun || echo "no local changes to extract"
exit "$rc"

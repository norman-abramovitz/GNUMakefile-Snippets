#!/bin/sh
# snippets-lib.sh — shared helpers for the snippet lifecycle scripts.
# Source it: . "$(dirname "$0")/snippets-lib.sh"  — never executed directly.
#
# Exit codes used across all lifecycle scripts:
#   0 clean/success   1 drift or conflicts   2 usage/environment   3 network
#
# Manifest grammar (snippets.sha256): header comments, then per file
#   # file: <path>  rev: <commit>  tag: <tag>  vendored: <date>
#   <sha256>  <path>
# Checksum lines stay `shasum -a 256 -c` compatible; paths are relative
# to the manifest's own directory.

sl_die()    { echo "ERROR: $*" >&2; exit 2; }
sl_warn()   { echo "WARNING: $*" >&2; }
sl_dryrun() { [ "${DRYRUN:-}" = "yes" ]; }
sl_today()  { date -u +%Y-%m-%d; }

sl_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum -- "$1"
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 -- "$1"
    else sl_die "need sha256sum or shasum on PATH"
    fi | awk '{print $1; exit}'
}

sl_header() {
    awk -v k="$2:" '$1 == "#" && $2 == k { print $3; exit }' "$1"
}

sl_entries() {
    awk '
        $1 == "#" && $2 == "file:" {
            rev = "-"; tag = "-"; ven = "-"
            for (i = 3; i < NF; i++) {
                if ($i == "rev:")           rev = $(i + 1)
                else if ($i == "tag:")      tag = $(i + 1)
                else if ($i == "vendored:") ven = $(i + 1)
            }
            next
        }
        /^#/   { next }
        NF == 0 { next }
        NF == 2 && length($1) == 64 && $1 ~ /^[0-9a-f]+$/ {
            printf "%s\t%s\t%s\t%s\t%s\n", $2, $1, rev, tag, ven
            rev = "-"; tag = "-"; ven = "-"
            next
        }
        { printf "WARNING: %s:%d: unparseable manifest line: %s\n", \
              FILENAME, FNR, $0 > "/dev/stderr" }
    ' "$1"
}

sl_entry() {
    sl_entries "$1" | awk -F'\t' -v p="$2" '$1 == p { print; exit }'
}

# shellcheck disable=SC2015
sl_update_entry() {
    _tmp=$(mktemp "$1.XXXXXX") || sl_die "mktemp failed beside $1"
    awk -v p="$2" -v sha="$3" -v rev="$4" -v tag="$5" -v ven="$6" '
        function emit() {
            printf "# file: %s  rev: %s  tag: %s  vendored: %s\n%s  %s\n", \
                p, rev, tag, ven, sha, p
        }
        $1 == "#" && $2 == "file:" && $3 == p { next }
        NF == 2 && $2 == p && length($1) == 64 {
            if (!done) { emit(); done = 1 }
            next
        }
        { print }
        END { if (!done) { printf "\n"; emit() } }
    ' "$1" > "$_tmp" && mv "$_tmp" "$1" \
        || { rm -f "$_tmp"; sl_die "manifest write failed: $1"; }
    # mktemp made this 0600; best-effort restore to a normal, readable
    # mode - a failure here doesn't undo the write.
    chmod 644 "$1" 2>/dev/null || true
}

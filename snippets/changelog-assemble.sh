#!/bin/sh
# changelog-assemble.sh — merge changelog.d fragments into release notes.
#
#   changelog-assemble.sh [-d dir] [-S 'Sec1|Sec2|...']   notes on stdout
#
# Sections publish in -S order; a fragment section outside that list, or
# content above the first [Section] header, is a hard error — a malformed
# fragment must not silently vanish from a release's notes. No fragments:
# empty output, success.
# Exit: 0, 1 malformed fragment, 2 usage.
set -eu
dir=changelog.d
sections='Breaking Changes|Features|BugFixes|Chores|Security Updates'
while getopts d:S: opt; do
    case $opt in d) dir=$OPTARG ;; S) sections=$OPTARG ;; *) exit 2 ;; esac
done
files=$(find "$dir" -maxdepth 1 -name '[0-9]*.md' 2>/dev/null | LC_ALL=C sort)
[ -n "$files" ] || exit 0
# shellcheck disable=SC2086  # word-split $files: newline-separated paths
awk -v order="$sections" '
BEGIN { norder = split(order, secs, "|"); for (i = 1; i <= norder; i++) valid[secs[i]] = 1 }
FNR == 1 { section = ""; delete pending }
/^\[[^]]+\][[:space:]]*$/ {
    s = $0; sub(/^\[/, "", s); sub(/\][[:space:]]*$/, "", s)
    if (!(s in valid)) {
        printf "ERROR: %s: unknown section [%s]\n", FILENAME, s > "/dev/stderr"
        err = 1; exit 1
    }
    section = s; delete pending; next
}
{
    if (section == "") {
        if ($0 ~ /^[[:space:]]*$/) next
        printf "ERROR: %s: content before any [Section] header\n", FILENAME > "/dev/stderr"
        err = 1; exit 1
    }
    if ($0 ~ /^[[:space:]]*$/) { pending[section] = pending[section] "\n"; next }
    buf[section] = buf[section] pending[section] $0 "\n"; delete pending[section]
}
END {
    if (err) exit 1
    for (i = 1; i <= norder; i++) {
        s = secs[i]; b = buf[s]
        sub(/^\n+/, "", b); sub(/\n+$/, "\n", b)
        if (b !~ /[^[:space:]]/) continue
        if (out) printf "\n"
        printf "[%s]\n%s", s, b; out = 1
    }
}
' $files

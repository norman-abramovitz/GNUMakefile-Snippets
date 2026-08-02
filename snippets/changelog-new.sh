#!/bin/sh
# changelog-new.sh — create the next changelog.d/NNNN-<slug>.md stub.
#
#   changelog-new.sh [-d dir] [-s slug]      prints the created path
#
# Slug defaults to the current git branch, sanitized to [a-z0-9-].
# Exit: 0 created, 2 empty slug or path collision.
set -eu
dir=changelog.d; slug=
while getopts d:s: opt; do
    case $opt in d) dir=$OPTARG ;; s) slug=$OPTARG ;; *) exit 2 ;; esac
done
[ -n "$slug" ] || slug=$(git branch --show-current 2>/dev/null || true)
slug=$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//; s/-*$//')
if [ -z "$slug" ]; then
    echo "ERROR: empty slug (detached HEAD?) - pass one: -s <slug>" >&2
    exit 2
fi
mkdir -p "$dir"
max=0
# shellcheck disable=SC2044  # fragment names are NNNN-slug.md, never spaced
for f in $(find "$dir" -maxdepth 1 -name '[0-9]*.md' 2>/dev/null | LC_ALL=C sort); do
    n=$(basename "$f"); n=${n%%-*}; n=$(printf '%s' "$n" | sed 's/^0*//')
    [ -n "$n" ] || n=0
    [ "$n" -gt "$max" ] && max=$n
done
file=$(printf '%s/%04d-%s.md' "$dir" $((max + 1)) "$slug")
if [ -e "$file" ]; then echo "ERROR: $file already exists" >&2; exit 2; fi
printf '[Features]\n- \n' > "$file"
echo "$file"

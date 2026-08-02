#!/bin/sh
# test-changelog.sh — extracted changelog scripts match the old behavior.
set -eu
. "$(dirname "$0")/helpers.sh"
mkdir "$FIX/work" && cd "$FIX/work"
git init -q . && git checkout -qb feature/my-branch

# new: numbered stub from branch slug, then increments
f=$(sh "$SNIP/changelog-new.sh")
[ "$f" = "changelog.d/0001-feature-my-branch.md" ] || fail "first fragment: $f"
grep -q '^\[Features\]$' "$f" || fail "stub section"
f=$(sh "$SNIP/changelog-new.sh" -s fix-two)
[ "$f" = "changelog.d/0002-fix-two.md" ] || fail "second fragment: $f"

# assemble: sections merge in canonical order across fragments
printf '[Features]\n- Added A.\n' > changelog.d/0001-feature-my-branch.md
printf '[BugFixes]\n- Fixed B.\n\n[Features]\n- Added C.\n' > changelog.d/0002-fix-two.md
sh "$SNIP/changelog-assemble.sh" > "$FIX/notes"
printf '[Features]\n- Added A.\n- Added C.\n\n[BugFixes]\n- Fixed B.\n' > "$FIX/want"
cmp -s "$FIX/notes" "$FIX/want" || { diff -u "$FIX/want" "$FIX/notes"; fail "assembly"; }

# unknown section is a hard error; empty dir is empty success
printf '[Bogus]\n- x\n' > changelog.d/0003-bad.md
rc=0; sh "$SNIP/changelog-assemble.sh" > /dev/null 2> "$FIX/err" || rc=$?
[ "$rc" -ne 0 ] || fail "unknown section accepted"
grep -q 'unknown section' "$FIX/err" || fail "unknown-section error"
rm -rf changelog.d
sh "$SNIP/changelog-assemble.sh" > "$FIX/notes" || fail "empty exit"
[ ! -s "$FIX/notes" ] || fail "empty dir should print nothing"

# unwritable target dir: set -e turns this into a real failure instead
# of the old false success (mkdir -p silently failed, a path still got
# printed, exit 0)
mkdir "$FIX/locked" && chmod 555 "$FIX/locked"
rc=0
out=$(sh "$SNIP/changelog-new.sh" -d "$FIX/locked/sub" 2>/dev/null) || rc=$?
chmod 755 "$FIX/locked"
[ "$rc" -ne 0 ] || fail "unwritable dir should fail, not exit 0"
[ -z "$out" ] || fail "unwritable dir printed a path: $out"

echo ok

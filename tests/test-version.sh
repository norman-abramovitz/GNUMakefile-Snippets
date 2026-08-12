#!/bin/sh
# test-version.sh — version.mk semver parsing, against the semver.org corpus.
set -eu
. "$(dirname "$0")/helpers.sh"

# A throwaway consumer that includes version.mk and prints the parsed parts.
# The heredoc is quoted so $(...) reaches make rather than the shell; the
# snippets dir arrives as a command-line variable, which make sets before it
# parses the include.
#
# '|' rather than tab as the field separator: tab is an IFS whitespace
# character, so a run of them collapses and empty fields silently shift.
mkdir -p "$FIX/v"
cat > "$FIX/v/Makefile" <<'EOF'
include $(SNIPPETS)/version.mk
t:
	@printf '%s|%s|%s|%s|%s|%s|%s\n' \
	  "$($(_HIDE)SEMVER_MAJOR)" "$($(_HIDE)SEMVER_MINOR)" "$($(_HIDE)SEMVER_PATCH)" \
	  "$($(_HIDE)SEMVER_PRERELEASE)" "$($(_HIDE)SEMVER_BUILDMETA)" \
	  "$($(_HIDE)SEMVER_VALID)" "$($(_HIDE)SEMVER_VERSION)"
EOF

parse() { (cd "$FIX/v" && make --no-print-directory -s t SNIPPETS="$SNIP" VERSION="$1"); }
f() { printf '%s' "$1" | cut -d'|' -f"$2"; }

# Every valid version from the semver.org corpus parses, and SEMVER_VERSION
# reassembles byte-identically — the round trip is what proves no component
# was dropped or mangled on the way through.
for v in \
    0.0.4 1.2.3 10.20.30 1.1.2-prerelease+meta 1.1.2+meta 1.1.2+meta-valid \
    1.0.0-alpha 1.0.0-beta 1.0.0-alpha.beta 1.0.0-alpha.beta.1 1.0.0-alpha.1 \
    1.0.0-alpha0.valid 1.0.0-alpha.0valid \
    1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay \
    1.0.0-rc.1+build.1 2.0.0-rc.1+build.123 1.2.3-beta 10.2.3-DEV-SNAPSHOT \
    1.2.3-SNAPSHOT-123 1.0.0 2.0.0 1.1.7 2.0.0+build.1848 2.0.1-alpha.1227 \
    1.0.0-alpha+beta 1.2.3----RC-SNAPSHOT.12.9.1--.12+788 \
    1.2.3----R-S.12.9.1--.12+meta 1.2.3----RC-SNAPSHOT.12.9.1--.12 \
    1.0.0+0.build.1-rc.10000aaa-kk-0.1 1.0.0-0A.is.legal \
    99999999999999999999999.999999999999999999.99999999999999999
do
    out=$(parse "$v")
    [ "$(f "$out" 6)" = "yes" ] || fail "$v: SEMVER_VALID empty"
    [ "$(f "$out" 7)" = "$v" ]  || fail "$v: round-trip gave '$(f "$out" 7)'"
done

# Component split, including a prerelease that itself contains hyphens and a
# buildmeta that contains dots — neither may bleed into the core.
out=$(parse 1.2.3----RC-SNAPSHOT.12.9.1--.12+788)
[ "$(f "$out" 1)" = "1" ]   || fail "core major"
[ "$(f "$out" 3)" = "3" ]   || fail "core patch"
[ "$(f "$out" 4)" = "---RC-SNAPSHOT.12.9.1--.12" ] || fail "prerelease: $(f "$out" 4)"
[ "$(f "$out" 5)" = "788" ] || fail "buildmeta: $(f "$out" 5)"

# Both tag prefixes parse, and the prefix is restored on reassembly. v- must
# be tested before v: 'v%' also matches a 'v-' input, so the wrong order
# leaves a leading '-' that later reads as a prerelease separator.
for p in v v-; do
    out=$(parse "${p}1.2.3-rc.1")
    [ "$(f "$out" 1)" = "1" ]       || fail "$p prefix: major"
    [ "$(f "$out" 4)" = "rc.1" ]    || fail "$p prefix: prerelease"
    [ "$(f "$out" 7)" = "${p}1.2.3-rc.1" ] || fail "$p prefix: round-trip"
done

# CalVer build metadata. Separators are unspecified by calver.org, and semver
# permits leading zeroes in build metadata (unlike prerelease), so zero-padded
# 0M/0D forms belong here and must survive intact.
for v in 1.2.3+2026.08.11 1.2.3+2026-08-11 1.2.3+20260811T002448Z 1.2.3+26.08 \
         1.2.3-rc.1+2026.08.11
do
    out=$(parse "$v")
    [ "$(f "$out" 6)" = "yes" ] || fail "$v: calver buildmeta rejected"
    [ "$(f "$out" 7)" = "$v" ]  || fail "$v: calver round-trip"
done
out=$(parse 1.2.3+2026.08.11)
[ "$(f "$out" 5)" = "2026.08.11" ] || fail "calver buildmeta: $(f "$out" 5)"

# SEMVER_VALID judges major.minor.patch and nothing else — deliberately. The
# prerelease and buildmeta segments are carried verbatim whatever they hold,
# so these stay valid even though the full semver grammar would reject them.
for v in 1.2.3-0123 1.0.0-alpha_beta 1.1.2+.123; do
    [ "$(f "$(parse "$v")" 6)" = "yes" ] || fail "$v: should stay valid"
done

# An absent major, minor or patch is the one thing that does invalidate.
for v in 1 1.2 alpha alpha.beta; do
    [ -z "$(f "$(parse "$v")" 6)" ] || fail "$v: should be invalid"
done

# The unresolvable-version sentinel soft-fails rather than erroring out.
out=$(parse 0.0.0-unknown)
[ -z "$(f "$out" 6)" ] || fail "0.0.0-unknown should be invalid"

echo ok

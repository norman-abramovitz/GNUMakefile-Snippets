[BugFixes]
- `go-release.mk`: `make tag` validated the tag against a hardcoded `v`
  glob, so with `TAG_PREFIX := v-` it refused every tag in the very
  scheme `TAG_PREFIX` exists to support. The pattern and its error
  message now derive from `TAG_PREFIX`.

[Features]
- `tests/test-version.sh`: `version.mk` parsing is now covered by the
  semver.org conformance corpus — every valid version round-trips
  byte-identically through `SEMVER_VERSION`, both tag prefixes restore
  correctly, and CalVer build metadata (including zero-padded `0M`/`0D`
  forms, which semver permits in build metadata but not in prerelease)
  survives intact. Also pins the deliberate leniency: `SEMVER_VALID`
  judges major.minor.patch only, carrying prerelease and build metadata
  verbatim whatever they hold.

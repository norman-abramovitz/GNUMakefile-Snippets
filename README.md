# GNUMakefile-Snippets

GNU make snippets for building and maintaining other repositories.
Each snippet is a single self-contained `.mk` file: copy it into a repo
(or add this repo as a submodule) and `include` it. The comment header
of each file is its reference documentation; this README is the tour.

All snippets require GNU make. They share two conventions:

- Internal variable and target names are prefixed through `$(_HIDE)`
  (default `_`) to keep them out of tab completion. Set `_HIDE :=`
  (empty) before the includes if you prefer plain names, or run
  `make _HIDE= <target>` to expose everything while debugging.
- `DRYRUN=yes` previews instead of acting, in every snippet that
  mutates anything.

## Snippets

### version.mk — semver resolution and build metadata

Resolves a version string into overridable `SEMVER_*` parts plus VCS
and date metadata, for stamping into binaries and build info files.

```make
include version.mk

build:
	go build -ldflags "-X main.version=$($(_HIDE)SEMVER_VERSION)"
```

The version source is the `VERSION_CMD` hook. The default resolves the
nearest git tag, strips a leading `v`, and increments the patch number
— "the next release". Repos with their own source override it:

```make
VERSION_CMD := node -p "require('./package.json').version"
include version.mk
```

`VERSION=x.y.z` on the command line overrides everything. Unresolvable
or malformed versions soft-fail to `0.0.0-unknown` and leave
`SEMVER_VALID` empty; a repo that wants a hard failure adds:

```make
check-version:
	$(if $($(_HIDE)SEMVER_VALID),,$(error VERSION is unusable))
```

Dates come in three forms: `BUILD_DATE` (UTC zulu), `BUILD_DATE_SEMVER`
(the same instant, colon-free, legal inside semver build metadata), and
`BUILD_DATE_TZ` (builder-local, or a forced zone via `BUILD_TZ`).
`dump.version` prints the lot; define `dump.version.extra` to append
your own lines.

### actions.mk — verb + modifier target engine

Turns `make build frontend backend` into a grammar: verbs collect the
recipes registered for whichever modifiers are on the command line.
See `docs/verb-object-makefiles.md` for the full guide and
`examples/verb-object/` for a working Makefile.

### bump.mk — version maintenance

`make bump major|minor|patch` advances the persisted current version
(prerelease stripped); `make bump dev` (or any label in `BUMP_LABELS`)
starts or increments a `dev.N` prerelease; `make bump final` strips the
prerelease. The current version comes from `BUMP_BASE_CMD` (default:
most recently created reachable git tag) and the result is persisted by
`VERSION_WRITE_CMD` (default: annotated `git tag`). File-versioned
repos point both at their file:

```make
BUMP_BASE_CMD     := cat VERSION
VERSION_WRITE_CMD := ./scripts/write-version
include bump.mk
```

Note the division of labor with version.mk: version.mk *reads* ("what
version is this build"), bump.mk *writes* ("mint the next version").
With both on git-tag defaults, `make bump patch` creates exactly the
tag that version.mk's next-patch resolution already names.

### security.mk — security scanners

`make security` runs govulncheck, trivy, gosec, and gitleaks. The Go
tools install themselves on demand; trivy and gitleaks print install
instructions instead of installing behind your back. Non-Go repos trim
the set:

```make
SECURITY_SCANS := trivy gitleaks
include security.mk
```

Knobs: `GOSEC_EXCLUDE` (rule ids), `TRIVY_SEVERITY`, `TRIVY_SCANNERS`.

### platform.mk — host/target platform detection

Lowercased, normalized `HOST_OS`/`HOST_ARCH`, a `PLATFORM=os/arch`
override parsed into `TARGET_OS`/`TARGET_ARCH`/`CURRENT_PLATFORM`, and
`GO_ENV` carrying `GOOS=`/`GOARCH=` only for the dimensions that differ
from the host:

```make
include platform.mk

build:
	$($(_HIDE)GO_ENV) go build -o bin/app ./cmd/app
```

### go-release.mk — cross-compiled Go release fan-out

One release target per `TARGETS` os/arch pair, artifacts named
`<PROJECT>-<version>+<os>.<arch>[.exe]` with sibling checksum files,
plus `release-all` / `ci-release` / `show-releases` / `release-clean`.
The ldflags are a template expanded per target, so per-platform symbols
work:

```make
include version.mk
GO_LDFLAGS      = -X 'main.Version=$($(_HIDE)SEMVER_VERSION)'
RELEASE_LDFLAGS = $(GO_LDFLAGS) -X 'main.GoOs=$(1)' -X 'main.GoArch=$(2)'
include go-release.mk
```

`ci-release` refuses to run unless `VERSION=` was given explicitly on
the command line — a version resolved by version.mk doesn't count.

### guards.mk — fail-fast recipe prerequisites

`require-%` as a prerequisite fails the build early when a variable is
missing: `deploy: require-TARGET_ENV`.

### help.mk — self-documenting help

`make help` lists every target annotated with a `## comment`, grouped
by `##@ Section` headers, scraped from all included makefiles. See
`examples/classical/` for the annotation style.

## Examples

- `examples/classical/` — one target per action, plain `make build`,
  in the style of a small CLI tool repo.
- `examples/verb-object/` — the verb + modifier grammar wired up end to
  end. Both run as-is from their directories.

## Used by

- [cloudfoundry/stratos](https://github.com/cloudfoundry/stratos) —
  version.mk ([#5656](https://github.com/cloudfoundry/stratos/pull/5656))

(Repos are added here as they adopt the snippets.)

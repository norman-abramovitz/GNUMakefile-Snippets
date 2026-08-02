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

## Vendoring and staying current

Every vendorable file lives under `snippets/`, described by
`snippets/snippets.sha256` — checksums verifiable with stock tools
(`shasum -a 256 -c snippets.sha256`) plus per-file provenance the
tooling maintains. The manifest, not the single file, is the unit of
integrity: vendor the tree, mount it anywhere (e.g. `mk/snippets/`).

Bootstrap:

    mkdir -p mk && cd mk
    curl -fsSL https://github.com/norman-abramovitz/GNUMakefile-Snippets/archive/refs/tags/v-1.0.0.tar.gz \
        | tar -xz --strip-components=1 '*/snippets'
    printf 'include mk/snippets/snippets.mk\n' >> ../Makefile   # or your layout
    cd .. && make snippets-pin SNIPPETS_TAG=v-1.0.0             # stamp provenance

Afterwards:

| Target | Question it answers |
|---|---|
| `make snippets-status` | Is anything stale, edited, or diverged? (CI-friendly: exit 1 on drift) |
| `make snippets-report` | What exactly changed, both sides, in prose? |
| `make snippets-merge` | Bring upstream's changes in (three-way; conflicts get markers) |
| `make snippets-patch` | Extract my local improvements for an upstream PR |
| `make snippets-pin` | Identify a copy of unknown origin |

`DRYRUN=yes` previews any mutation. `SNIPPETS_OFFLINE=yes` keeps status
off the network. If you use these snippets, consider adding your repo to
[CONSUMERS.md](CONSUMERS.md).

## Snippets

### version.mk — semver resolution and build metadata

Resolves a version string into overridable `SEMVER_*` parts plus VCS
and date metadata, for stamping into binaries and build info files.

```make
include snippets/version.mk

build:
	go build -ldflags "-X main.version=$($(_HIDE)SEMVER_VERSION)"
```

The version source is the `VERSION_CMD` hook. The default resolves the
nearest git tag, strips a leading `v`, and increments the patch number
— "the next release". Repos with their own source override it:

```make
VERSION_CMD := node -p "require('./package.json').version"
include snippets/version.mk
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
include snippets/bump.mk
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
include snippets/security.mk
```

Knobs: `GOSEC_EXCLUDE` (rule ids), `TRIVY_SEVERITY`, `TRIVY_SCANNERS`.

That "print instructions" default is right on a workstation and wrong in
CI, where a plain runner has neither tool and `make security` fails on a
missing scanner rather than on a finding. `make install-gitleaks` fetches
a pinned release and verifies it against the project's published
checksums, so a job can run `make install-gitleaks security` without
hand-rolling a download step:

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0        # gitleaks scans history; depth 1 scans one commit
- run: make install-gitleaks security
  env:
    PATH: ${{ github.workspace }}/bin:${{ env.PATH }}
```

Pin with `GITLEAKS_VERSION`, relocate with `TOOLS_BIN` (default `./bin`).

### changelog.mk — per-PR release-notes fragments

Each PR drops a fragment in `changelog.d/`; the fragments are assembled
in section order when a release is cut, then swept. This avoids the two
problems of a single shared changelog: it is a merge-conflict magnet,
and one file cannot be both a durable history and the payload for one
release — publishing it whole repeats every prior release in the new
release's notes.

```bash
make changelog-new                 # changelog.d/0007-my-branch.md
make changelog-check               # CI: reject stubs and malformed files
make changelog-assemble            # merged notes on stdout
make changelog-sweep               # after publishing
```

A fragment names its sections; one file can feed several:

```markdown
[Features]
- Added the frobnicator panel.

[BugFixes]
- Fixed the frobnicator crashing on empty input.
```

#### Dependency bumps

Dependabot and Renovate open PRs but never run `changelog-new`, so their
bumps reach a release only if someone writes them up by hand — and nothing
reports the omission until the notes come out thin. These read them out of
the commit log instead, keyed on the subject prefix the bot is configured
to use:

```bash
make changelog-deps-check          # how many have landed since the last tag
make changelog-deps                # draft the fragment from them
```

`changelog-deps-check` prints the count whether or not anything is missing,
so it also answers "has enough piled up to be worth a build yet?" between
releases. It warns and never fails, and is deliberately not wired into
`changelog-check`: a hard error would fire on pipeline fixes, docs-only
changes, reverts and the bumps themselves, and a gate with that
false-positive rate gets routed around rather than obeyed.

`changelog-deps` writes a draft to rewrite into prose — the prose is what
ships. A security bump usually wants moving to `[Security Updates]` by hand.

Pin the prefix in the bot's own config so the log grep keeps matching. For
Dependabot:

```yaml
    commit-message:
      prefix: "chore(deps)"
      prefix-development: "chore(deps-dev)"
```

Override `CHANGELOG_DEPS_GREP` if your bot uses something else, and
`CHANGELOG_DEPS_SINCE` when the window should not start at the last `v*`
tag. Both targets see only what has landed on the branch — a bump still in
an open PR is not counted.

Unknown section names and content above the first header are hard
errors — a malformed fragment must not silently vanish from a release.
Order and vocabulary come from `CHANGELOG_SECTIONS`.

Wired to go-release.mk, a release needs no hand-edited notes at all:

```make
TAG_NOTES_CMD := $(MAKE) --no-print-directory changelog-assemble
include snippets/go-release.mk
include snippets/changelog.mk
```

`make tag` puts the assembled notes in the annotated tag body and
`make publish` reads them back with `--notes-from-tag`. Tagging is
refused outright if there are no fragments, rather than publishing a
release with empty notes.

### platform.mk — host/target platform detection

Lowercased, normalized `HOST_OS`/`HOST_ARCH`, a `PLATFORM=os/arch`
override parsed into `TARGET_OS`/`TARGET_ARCH`/`CURRENT_PLATFORM`, and
`GO_ENV` carrying `GOOS=`/`GOARCH=` only for the dimensions that differ
from the host:

```make
include snippets/platform.mk

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
include snippets/version.mk
GO_LDFLAGS      = -X 'main.Version=$($(_HIDE)SEMVER_VERSION)'
RELEASE_LDFLAGS = $(GO_LDFLAGS) -X 'main.GoOs=$(1)' -X 'main.GoArch=$(2)'
include snippets/go-release.mk
```

`ci-release` refuses to run unless `VERSION=` was given explicitly on
the command line — a version resolved by version.mk doesn't count.

Release notes come from `NOTES` (a file) when set; otherwise from the
annotated tag body via `--notes-from-tag` when the tag has one; otherwise
gh generates them from the commit log. `TAG_NOTES_CMD` is what puts a
body on the tag — see changelog.mk above.

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

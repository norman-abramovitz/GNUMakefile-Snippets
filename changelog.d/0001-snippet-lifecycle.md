[Breaking Changes]
- All vendorable `.mk` files moved from the repo root into `snippets/`.
  Consumers including from a checkout or submodule must update their
  include paths (e.g. `include snippets/version.mk`).

[Features]
- Vendored-snippet lifecycle: `snippets/snippets.sha256` records checksums
  and per-file provenance (origin, commit, tag, vendored date) for the
  whole tree, verifiable with stock `shasum -a 256 -c`.
- New lifecycle verbs, each a POSIX shell component with a `snippets.mk`
  make wrapper: `snippets-status` (drift classification, CI-friendly),
  `snippets-report` (plain-language account of upstream and local
  changes), `snippets-merge` (three-way merge against the pinned base),
  `snippets-patch` (extract local improvements for upstream PRs), and
  `snippets-pin` (record provenance for copies of unknown origin).
- The vendored tree is relocatable: mount it anywhere (e.g.
  `mk/snippets/`); manifest paths are relative to the manifest itself.
- Release gate: `make bump` now refuses to tag when the shipped manifest
  or changelog fragments are stale (`make release-check`).
- `changelog-new` and `changelog-assemble` logic extracted into shell
  components usable outside make — the first lean-wrapper migration.
- `CONSUMERS.md`: opt-in registry of repos vendoring these snippets.

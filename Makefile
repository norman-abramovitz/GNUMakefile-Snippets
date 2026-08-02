# Makefile — this repo versions and tests itself with its own snippets.
_HIDE ?= _

include snippets/version.mk
include snippets/bump.mk
include snippets/changelog.mk
include snippets/guards.mk
include snippets/help.mk
include snippets/snippets.mk

.DEFAULT_GOAL := help

.PHONY: test lint

##@ Development

test: ## Run the shell test suite
	@tests/run-tests.sh

lint: ## shellcheck every shell component
	@files=$$(ls snippets/*.sh 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint: no scripts yet"; exit 0; fi; \
	shellcheck $$files && echo "lint: OK"

manifest: ## Regenerate snippets/snippets.sha256
	@sh snippets/snippets-manifest.sh

manifest-check: ## Fail if the shipped manifest is stale
	@sh snippets/snippets-manifest.sh -c

release-check: manifest-check changelog-check ## Gate: run before tagging

# bump.mk (vendored, not edited here) tags directly with no gate of its
# own. Wire the release gate in on this side so `make bump ...` refuses
# to mint a tag while the manifest or changelog is stale.
bump: release-check

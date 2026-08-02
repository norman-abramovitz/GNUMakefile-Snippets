# Classical Makefile built from the snippets: plain `make <target>`
# with one target per action, in the style of the cf CLI plugin repos.
#
# Try from this directory:
#   make                     (help is the default goal)
#   make version
#   make build
#   make build PLATFORM=linux/amd64
#   make bump patch DRYRUN=yes
#   make security            (scanners must be installed)

include ../../snippets/version.mk
include ../../snippets/platform.mk
include ../../snippets/bump.mk
include ../../snippets/security.mk
include ../../snippets/guards.mk
include ../../snippets/help.mk

PROJECT := example-app

# This repo versions from git tags; a repo with a version file would set
#   VERSION_CMD   := cat VERSION
#   BUMP_BASE_CMD := cat VERSION

.DEFAULT_GOAL := help

.PHONY: version build clean

##@ Build

build: ## Build for the current (or PLATFORM=os/arch) platform
	@echo "Building $(PROJECT) $($(_HIDE)SEMVER_VERSION) for $($(_HIDE)CURRENT_PLATFORM)..."
	@echo "  (replace with: $($(_HIDE)GO_ENV) go build ...)"

clean: ## Remove build output
	@echo "  (replace with the real clean command)"

##@ Introspection

version: ## Print resolved version variables
	$(dump.version)

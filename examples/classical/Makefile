# Classical Makefile built from the snippets: plain `make <target>`
# with one target per action, in the style of the cf CLI plugin repos.
#
# Try from this directory:
#   make version
#   make build
#   make bump patch DRYRUN=yes
#   make security          (scanners must be installed)

include ../../version.mk
include ../../bump.mk
include ../../security.mk

PROJECT := example-app

# This repo versions from git tags; a repo with a version file would set
#   VERSION_CMD   := cat VERSION
#   BUMP_BASE_CMD := cat VERSION

.DEFAULT_GOAL := help

.PHONY: help version build clean

help:
	@echo "$(PROJECT) $($(_HIDE)SEMVER_VERSION)"
	@echo ""
	@echo "  make version      Print resolved version variables"
	@echo "  make build        Build (placeholder)"
	@echo "  make bump <mod>   Bump version (major|minor|patch|final|dev|alpha|beta|rc)"
	@echo "  make security     Run security scanners"
	@echo "  make clean        Remove build output"

version:
	$(dump.version)

build:
	@echo "Building $(PROJECT) $($(_HIDE)SEMVER_VERSION) ($($(_HIDE)BUILD_VCS_ID))..."
	@echo "  (replace with the real build command)"

clean:
	@echo "  (replace with the real clean command)"

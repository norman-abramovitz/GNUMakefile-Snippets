# snippets.mk — vendored-snippet lifecycle targets (vendorable)
#
# Thin wrapper over the snippets-*.sh components beside it; all logic is
# in the scripts, so any orchestrator can drive them directly, e.g.:
#   sh mk/snippets/snippets-status.sh -m mk/snippets/snippets.sha256
#
#   make snippets-status   Classify drift per vendored file (exit 1 on any)
#   make snippets-report   Explain drift in prose, diffs as evidence
#   make snippets-merge    Three-way merge to SNIPPETS_TAG (or newest v-*)
#   make snippets-patch    Extract local deltas as upstream-ready patches
#   make snippets-pin      Record provenance (SNIPPETS_TAG = bootstrap stamp)
#
# Settings:
#   SNIPPETS_TAG       Target tag for merge/pin/status/report. Default: newest.
#   SNIPPETS_OFFLINE   yes = status from checksums only, no network.
#   DRYRUN=yes         Preview mutations without writing (merge, patch, pin).
#   SNIPPETS_REMOTE    Path to a local clone replacing the network entirely.
_HIDE ?= _

SNIPPETS_TAG     ?=
SNIPPETS_OFFLINE ?=

$(_HIDE)SNIPPETS_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
$(_HIDE)SNIPPETS_RUN  = sh '$($(_HIDE)SNIPPETS_DIR)/snippets-$(1).sh' \
	-m '$($(_HIDE)SNIPPETS_DIR)/snippets.sha256'
$(_HIDE)SNIPPETS_TAGOPT = $(if $(SNIPPETS_TAG),-t '$(SNIPPETS_TAG)')

.PHONY: snippets-status snippets-report snippets-merge snippets-patch snippets-pin

snippets-status: ## Classify vendored-snippet drift
	@$(call $(_HIDE)SNIPPETS_RUN,status) $($(_HIDE)SNIPPETS_TAGOPT) \
		$(if $(filter yes,$(SNIPPETS_OFFLINE)),-o)

snippets-report: ## Explain vendored-snippet drift in prose
	@$(call $(_HIDE)SNIPPETS_RUN,report) $($(_HIDE)SNIPPETS_TAGOPT)

snippets-merge: ## Three-way merge vendored snippets with upstream
	@$(call $(_HIDE)SNIPPETS_RUN,merge) $($(_HIDE)SNIPPETS_TAGOPT)

snippets-patch: ## Extract local snippet changes for upstream PRs
	@$(call $(_HIDE)SNIPPETS_RUN,patch)

snippets-pin: ## Record provenance for vendored copies
	@$(call $(_HIDE)SNIPPETS_RUN,pin) $($(_HIDE)SNIPPETS_TAGOPT)

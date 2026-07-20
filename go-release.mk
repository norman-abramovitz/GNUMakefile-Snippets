# go-release.mk — cross-compiled Go release fan-out (vendorable)
#
# Generates one release target per os/arch pair and the surrounding
# lifecycle:
#   make release-all         clean, build every TARGETS entry, list
#   make ci-release          release-all, but VERSION= must be given
#   make show-releases       list built artifacts
#   make release-clean       remove built artifacts
#
# Artifacts land in RELEASE_ROOT as
#   <PROJECT>-<version>+<os>.<arch>[.<meta>][.exe]
# each with a sibling checksum file (.sha1/.sha256/...).
#
# Settings:
#   PROJECT            Artifact base name. Default: directory name.
#   TARGETS            os/arch pairs. Default:
#                      linux/amd64 linux/arm64 darwin/amd64 darwin/arm64
#   RELEASE_ROOT       Output directory. Default: releases
#   RELEASE_VERSION    Version in artifact names. Default: version.mk's
#                      SEMVER_VERSION (include version.mk first, or set
#                      this explicitly).
#   RELEASE_META       Optional extra artifact-name suffix (typically
#                      build metadata). Default: empty.
#   RELEASE_PACKAGES   Package path(s) passed to go build. Default: .
#   RELEASE_LDFLAGS    ldflags template, expanded per target with
#                      $(1)=os and $(2)=arch — so per-platform symbols
#                      work:
#                        RELEASE_LDFLAGS = $(GO_LDFLAGS) \
#                          -X 'main.GoOs=$(1)' -X 'main.GoArch=$(2)'
#                      Default: $(GO_LDFLAGS) (yours to define).
#   RELEASE_CHECKSUM   Checksum flavor, shaN form. Default: sha256
#                      (one flavor; add a second checksum in the repo
#                      if a distribution channel demands it)
#   CGO_ENABLED        Default: 0 (static-friendly cross builds)
#
# Windows artifacts get .exe; the checksum file sits next to the
# artifact under the un-suffixed name.

_HIDE ?= _

PROJECT          ?= $(notdir $(CURDIR))
TARGETS          ?= linux/amd64 linux/arm64 darwin/amd64 darwin/arm64
RELEASE_ROOT     ?= releases
RELEASE_VERSION  ?= $($(_HIDE)SEMVER_VERSION)
RELEASE_META     ?=
RELEASE_PACKAGES ?= .
RELEASE_LDFLAGS  ?= $(GO_LDFLAGS)
RELEASE_CHECKSUM ?= sha256
CGO_ENABLED      ?= 0

$(_HIDE)RELEASES := $(foreach target,$(TARGETS),release-$(target)-$(PROJECT))

.PHONY: release-all ci-release show-releases release-clean $(_HIDE)release-mkdir

release-all: release-clean $(_HIDE)release-mkdir $($(_HIDE)RELEASES) show-releases

# Requires VERSION given explicitly on the command line — a VERSION
# resolved by version.mk doesn't count, releases must be deliberate.
ci-release:
	@if [ -z "$(filter command line environment,$(origin VERSION))" ]; then \
		echo "VERSION must be set explicitly: make ci-release VERSION=x.y.z" >&2; \
		exit 1; \
	fi
	@$(MAKE) release-all

show-releases:
	@ls -lA $(RELEASE_ROOT)

release-clean:
	@rm -f $(RELEASE_ROOT)/$(PROJECT)-* || true
	@[ ! -d $(RELEASE_ROOT) ] || rmdir -p $(RELEASE_ROOT) 2>/dev/null || true

$(_HIDE)release-mkdir:
	@mkdir -p $(RELEASE_ROOT)

# One target per os/arch pair. Target-specific variables stay lazy (=)
# so RELEASE_VERSION resolves at build time (bump/build chains).
define $(_HIDE)release_target_impl
.PHONY: release-$(1)/$(2)-$(PROJECT)
release-$(1)/$(2)-$(PROJECT): $(_HIDE)REL_LDFLAGS = $$(call RELEASE_LDFLAGS,$(1),$(2))
release-$(1)/$(2)-$(PROJECT): $(_HIDE)REL_BASE = $$(RELEASE_ROOT)/$$(PROJECT)-$$(RELEASE_VERSION)+$(1).$(2)$$(if $$(RELEASE_META),.$$(RELEASE_META))
release-$(1)/$(2)-$(PROJECT): $(_HIDE)REL_EXE = $$($(_HIDE)REL_BASE)$(if $(patsubst windows,,$(1)),,.exe)
release-$(1)/$(2)-$(PROJECT):
	@echo "Building $$(PROJECT) $$(RELEASE_VERSION) for $(1)/$(2)..."
	@CGO_ENABLED=$$(CGO_ENABLED) GOOS=$(1) GOARCH=$(2) go build -o "$$($(_HIDE)REL_EXE)" -ldflags "$$($(_HIDE)REL_LDFLAGS)" $$(RELEASE_PACKAGES)
	@shasum -a $$(patsubst sha%,%,$$(RELEASE_CHECKSUM)) "$$($(_HIDE)REL_EXE)" > "$$($(_HIDE)REL_BASE).$$(RELEASE_CHECKSUM)"
endef

$(foreach target,$(TARGETS),$(eval $(call $(_HIDE)release_target_impl,$(word 1,$(subst /, ,$(target))),$(word 2,$(subst /, ,$(target))))))

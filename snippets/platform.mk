# platform.mk — host/target platform detection (vendorable, standalone)
#
# Detects the host platform and parses a PLATFORM=os/arch override into
# target variables, with the Go environment prepared for cross builds.
#
#   make build                        target = host platform
#   make build PLATFORM=linux/amd64   cross target
#   make build PLATFORM=linux         os only; arch defaults to host
#
# Derived variables (prefixed with $(_HIDE)):
#   HOST_OS, HOST_ARCH        lowercased uname, x86_64/aarch64
#                             normalized to amd64/arm64
#   TARGET_OS, TARGET_ARCH    from PLATFORM, defaulting to host
#   CURRENT_PLATFORM          TARGET_OS/TARGET_ARCH
#   GO_ENV                    GOOS=/GOARCH= assignments, only for the
#                             dimensions that differ from the host —
#                             prefix onto go invocations:
#                               $($(_HIDE)GO_ENV) go build ...
#
# PLATFORM accepts os/arch, os-arch, or os_arch separators.

_HIDE ?= _

PLATFORM ?=
$(_HIDE)HOST_OS   := $(shell uname -s | tr '[:upper:]' '[:lower:]')
$(_HIDE)HOST_ARCH := $(patsubst x86_64,amd64,$(patsubst aarch64,arm64,$(shell uname -m)))

# Parse PLATFORM override or default to host
ifdef PLATFORM
  $(_HIDE)PLAT_WORDS := $(subst /, ,$(subst -, ,$(subst _, ,$(PLATFORM))))
  $(_HIDE)TARGET_OS   := $(word 1,$($(_HIDE)PLAT_WORDS))
  $(_HIDE)TARGET_ARCH := $(or $(word 2,$($(_HIDE)PLAT_WORDS)),$($(_HIDE)HOST_ARCH))
else
  $(_HIDE)TARGET_OS   := $($(_HIDE)HOST_OS)
  $(_HIDE)TARGET_ARCH := $($(_HIDE)HOST_ARCH)
endif

$(_HIDE)CURRENT_PLATFORM := $($(_HIDE)TARGET_OS)/$($(_HIDE)TARGET_ARCH)

# Cross-compilation: set GOOS/GOARCH only when target differs from host,
# so native builds keep the toolchain's own defaults.
$(_HIDE)GO_ENV :=
ifneq ($($(_HIDE)TARGET_OS),$($(_HIDE)HOST_OS))
  $(_HIDE)GO_ENV += GOOS=$($(_HIDE)TARGET_OS)
endif
ifneq ($($(_HIDE)TARGET_ARCH),$($(_HIDE)HOST_ARCH))
  $(_HIDE)GO_ENV += GOARCH=$($(_HIDE)TARGET_ARCH)
endif

# Verb-object Makefile built from the snippets: `make <verb> <modifier...>`.
# See docs/verb-object-makefiles.md for the full walkthrough of this file.
#
# Try from this directory:
#   make build             both modifiers (the declared default)
#   make build app         one modifier
#   make clean             default clean (everything)
#   make clean app         modifier-scoped clean
#   make dump version      version variables
#   make dump registry     what's wired to what
#   make build nonsense    unknown-modifier warning
#   make _HIDE= build      debug: expose hidden names

include ../../version.mk
include ../../actions.mk

# ── 1. Vocabulary ────────────────────────────────────────────
$(call modifier,app)
$(call modifier,docs)
$(call modifier,version)
$(call modifier,registry)

# ── 2. Recipes + registration ────────────────────────────────
define build.app
	@echo "Building app $($(_HIDE)SEMVER_VERSION)..."
endef
$(call register,build,app)

define build.docs
	@echo "Building docs..."
endef
$(call register,build,docs)

define clean.app
	@echo "Cleaning app output..."
endef
$(call register,clean,app)

define clean.docs
	@echo "Cleaning docs output..."
endef
$(call register,clean,docs)

# Custom-wired: everything-clean used as the bare `make clean` default.
define clean.all
	@echo "Cleaning everything..."
endef
$(call register_always,clean,all)

# dump.version comes from version.mk; dump.registry from actions.mk.
$(call register,dump,version)
$(call register,dump,registry)

# ── 3. Defaults ──────────────────────────────────────────────
# Bare `make build` means app + docs; any of the group suppresses it.
$(call verb_default_mods,build,app docs,app docs)

# ── 4. Verbs ─────────────────────────────────────────────────
$(call declare_verb,build)
$(call declare_verb_default,clean,$(_HIDE)clean.all)
$(call declare_verb,dump)

# actions.mk — verb + modifier target engine (vendorable)
#
# A verb-object Makefile reads as `make <verb> <modifier...>`:
#   make build            all default modifiers
#   make build frontend   one modifier
#   make clean backend dist
# Modifiers are ordinary goal words that act as flags; a verb runs the
# recipes registered for whichever of its modifiers are active.
#
# Usage — declare the vocabulary, define recipes, register, declare verbs:
#   include actions.mk
#   $(call modifier,frontend)
#   $(call modifier,backend)
#   define build.frontend
#   	@echo "building frontend..."
#   endef
#   $(call register,build,frontend)
#   $(call verb_default_mods,build,frontend backend,frontend backend)
#   $(call declare_verb,build)
#
# Public macros:
#   modifier(name)                Declare a modifier: flag + no-op goal.
#   verb_default_mods(verbs,defaults,group)
#                                 When any of <verbs> is on the command
#                                 line and no modifier of <group> is
#                                 active, activate <defaults>.
#   register(verb,modifier,[prereqs])
#                                 Attach recipe <verb>.<modifier> (a
#                                 define) to the verb, gated on the flag.
#   register_always(verb,modifier,[prereqs])
#                                 Like register, but the target always
#                                 exists and skips validation bookkeeping.
#                                 Use for custom wiring.
#   allow(verb,modifier)          Mark a modifier valid for a verb without
#                                 a recipe (variable-driven modifiers).
#   declare_verb(verb)            Wire the verb target to its active deps.
#   declare_verb_default(verb,default_dep)
#                                 Same, but run <default_dep> when no
#                                 flag-gated deps are active.
#
# The $(_HIDE) prefix hides generated names from tab completion; set
# `_HIDE :=` (empty) before the include for plain names, or run
# `make _HIDE= <target>` to expose everything for debugging.

_HIDE ?= _

# Known vocabulary — populated by modifier() and declare_verb(),
# checked for collisions in both directions.
$(_HIDE)KNOWN_MODS  :=
$(_HIDE)KNOWN_VERBS :=

# ── modifier(name) ───────────────────────────────────────────
# Sets FLAG_<name> when the word appears on the command line and
# creates the no-op goal so `make build frontend` doesn't error on
# 'frontend' as an unknown target.
define $(_HIDE)modifier_impl
$(_HIDE)FLAG_$1 := $$(if $$(filter $1,$$(MAKECMDGOALS)),yes,)
$(_HIDE)KNOWN_MODS += $1
.PHONY: $1
$1:
	@:
endef

modifier = $(if $(filter $(strip $1),$($(_HIDE)KNOWN_VERBS)),$(warning COLLISION: modifier '$(strip $1)' is also a declared verb — 'make $(strip $1)' is ambiguous))$(eval $(call $(_HIDE)modifier_impl,$(strip $1)))

# ── verb_default_mods(verbs,defaults,group) ──────────────────
# Bare-verb defaulting: if any word of <verbs> is a command-line goal
# and none of <group>'s flags are active, activate every flag in
# <defaults>. Call it after the involved modifiers are declared.
# <group> lists every modifier whose presence should suppress the
# default — usually the verb's whole modifier set, but it may include
# modifiers that suppress without being defaulted.
verb_default_mods = $(if $(filter $(strip $1),$(MAKECMDGOALS)),$(if $(strip $(foreach m,$(strip $3),$($(_HIDE)FLAG_$(m)))),,$(foreach m,$(strip $2),$(eval $(_HIDE)FLAG_$(m) := yes))))

# ── register(verb,modifier,[prereqs]) ───────────────────────
# Generates the hidden target <verb>.<modifier> running the define of
# the same name, and adds it to the verb's deps when the flag is active.
define $(_HIDE)register_impl
.PHONY: $(_HIDE)$1.$2
$(_HIDE)$1.$2: $3
	$$($1.$2)
$(_HIDE)DEPS_$1 += $$(if $$($(_HIDE)FLAG_$2),$(_HIDE)$1.$2)
$(_HIDE)VALID_MODS_$1 += $2
$(_HIDE)REGISTRY += $1.$2
endef

register = $(if $(filter $(strip $2),$($(_HIDE)KNOWN_VERBS)),$(warning COLLISION: modifier '$(strip $2)' in 'register($(strip $1),$(strip $2))' is also a declared verb — 'make $(strip $1) $(strip $2)' will run both))$(eval $(call $(_HIDE)register_impl,$(strip $1),$(strip $2),$(strip $3)))

# ── register_always(verb,modifier,[prereqs]) ─────────────────
# Like register, but the target is always created (no flag check)
# and the modifier is NOT added to VALID_MODS or REGISTRY.
# Use for targets with custom wiring. If the modifier is flag-gated,
# pair with allow() to suppress warnings.
define $(_HIDE)register_always_impl
.PHONY: $(_HIDE)$1.$2
$(_HIDE)$1.$2: $3
	$$($1.$2)
endef

register_always = $(eval $(call $(_HIDE)register_always_impl,$(strip $1),$(strip $2),$(strip $3)))

# ── allow(verb,modifier) ─────────────────────────────────────
# Mark a modifier as valid for a verb without creating a recipe.
# Use when the modifier affects behavior through variables rather
# than adding a distinct target.
allow = $(eval $(_HIDE)VALID_MODS_$(strip $1) += $(strip $2))

# ── Modifier validation ──────────────────────────────────────
# Called inside declare_verb and declare_verb_default. Emits a
# parse-time warning for each active modifier not registered or
# allowed for this verb.
$(_HIDE)check_mods = $(if $(filter $1,$(MAKECMDGOALS)),$(foreach mod,$($(_HIDE)KNOWN_MODS),$(if $(and $($(_HIDE)FLAG_$(mod)),$(if $(filter $(mod),$($(_HIDE)VALID_MODS_$1)),,x)),$(warning WARNING: 'make $1 $(mod)' — '$(mod)' is not a valid modifier for '$1' (ignored)))))

# ── declare_verb(verb) ──────────────────────────────────────
define $(_HIDE)declare_verb_impl
.PHONY: $1
$1: $$($(_HIDE)DEPS_$1)
endef

declare_verb = $(if $(filter $(strip $1),$($(_HIDE)KNOWN_MODS)),$(warning COLLISION: verb '$(strip $1)' in 'declare_verb($(strip $1))' is also a declared modifier — 'make <verb> $(strip $1)' will conflict))$(eval $(_HIDE)KNOWN_VERBS += $(strip $1))$(call $(_HIDE)check_mods,$(strip $1))$(eval $(call $(_HIDE)declare_verb_impl,$(strip $1)))

# ── declare_verb_default(verb,default_dep) ──────────────────
# Like declare_verb, but runs default_dep when no flag-gated deps
# are active. Use for verbs like clean where the bare invocation
# should have a sensible default action.
define $(_HIDE)declare_verb_default_impl
.PHONY: $1
$1: $$($(_HIDE)DEPS_$1) $$(if $$(strip $$($(_HIDE)DEPS_$1)),,$(strip $2))
endef

declare_verb_default = $(if $(filter $(strip $1),$($(_HIDE)KNOWN_MODS)),$(warning COLLISION: verb '$(strip $1)' in 'declare_verb_default($(strip $1))' is also a declared modifier — 'make <verb> $(strip $1)' will conflict))$(eval $(_HIDE)KNOWN_VERBS += $(strip $1))$(call $(_HIDE)check_mods,$(strip $1))$(eval $(call $(_HIDE)declare_verb_default_impl,$(strip $1),$(strip $2)))

# ── Dump action ──────────────────────────────────────────────
# Wire with: $(call modifier,registry) + $(call register,dump,registry)
# or invoke $(dump.registry) from any recipe.
define dump.registry
	@echo "Registered verb.modifier pairs:"
	@for r in $($(_HIDE)REGISTRY); do echo "  $$r"; done
	@echo "Declared verbs: $($(_HIDE)KNOWN_VERBS)"
	@echo "Known modifiers:$($(_HIDE)KNOWN_MODS)"
endef

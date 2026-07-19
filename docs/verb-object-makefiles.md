# Creating verb-object Makefiles

A verb-object Makefile reads as a small command grammar instead of a
flat target list:

```
make build                 # build everything this repo builds
make build frontend        # build one part
make clean backend dist    # clean two scopes at once
make dump version          # introspection is a verb too
```

The words after the verb are *modifiers*. They are ordinary make goals,
but they carry no work of their own — each one just flags itself as
"active", and the verb runs the recipes registered for whichever of its
modifiers are active. `actions.mk` is the engine; this document shows
how to assemble a Makefile on top of it. The finished result of every
step lives in `examples/verb-object/Makefile`, which runs as-is.

## How the trick works

Three mechanics, all standard GNU make:

1. A modifier word becomes a no-op target (so `make build frontend`
   doesn't fail on `frontend` as an unknown goal) plus a flag variable
   set by scanning `MAKECMDGOALS`.
2. `register(verb,modifier)` generates a hidden target
   `<verb>.<modifier>` whose recipe is the `define` block of the same
   name, and appends it to the verb's dependency list *conditionally on
   the flag*.
3. `declare_verb(verb)` finally creates the verb target depending on
   whatever ended up in that list.

Everything else — defaults, validation warnings, collision checks — is
bookkeeping around those three.

## Step by step

### 1. Declare the vocabulary

```make
include actions.mk

$(call modifier,frontend)
$(call modifier,backend)
```

Every modifier used anywhere in the file gets declared once, up front.
Declaring creates the flag and the no-op goal. Modifier words share one
global namespace with your real targets — pick words that aren't also
build artifacts or verbs.

### 2. Define recipes and register them

```make
define build.frontend
	@echo "Building frontend..."
	bun run build
endef
$(call register,build,frontend)

define build.backend
	go build -o bin/server ./cmd/server
endef
$(call register,build,backend)
```

The define name must be exactly `<verb>.<modifier>`. Recipes are
ordinary recipe blocks: tab-indented, one shell per line.
`register` takes an optional third argument of prerequisite targets:

```make
$(call register,build,frontend,$(_HIDE)stamp.frontend)
```

Two variants cover the non-standard cases:

- `register_always(verb,modifier)` creates the target unconditionally
  and skips the validation bookkeeping. Use it for custom wiring — for
  example a recipe that exists only to serve as a verb's bare default.
- `allow(verb,modifier)` marks a modifier valid for a verb without any
  recipe, for modifiers that change behavior purely through variables
  (a platform switch, say).

### 3. Choose bare-verb defaults

What should plain `make build` do? Declare it:

```make
$(call verb_default_mods,build,frontend backend,frontend backend)
```

Arguments: the verbs this applies to, the modifiers to activate, and
the *suppressor group* — if any modifier of the group is on the command
line, the default stays off. The group is usually the verb's whole
modifier set, but it can contain modifiers that suppress without being
part of the default (in stratos, `korifi` suppresses the build default
without being defaulted itself).

For verbs where the bare form should run one specific recipe instead of
a modifier set, use `declare_verb_default` in the next step.

### 4. Declare the verbs

```make
$(call declare_verb,build)
$(call declare_verb_default,clean,$(_HIDE)clean.all)
```

`declare_verb` wires the verb to its registered, flag-gated recipes.
`declare_verb_default` additionally runs the given target when no
flag-gated recipe is active — the right shape for `make clean` meaning
"clean the usual things" while `make clean docs` stays scoped.

Declaration order matters only in that verbs must be declared after all
their registrations; the conventional layout is vocabulary, recipes,
defaults, verbs — top to bottom.

## Validation and debugging

The engine warns (at parse time, without failing) about mistakes that
would otherwise silently no-op:

- `make build nonsense` — unknown word: make itself errors, since no
  no-op target exists.
- `make build docs` where `docs` is declared but not registered for
  `build` — a WARNING that the modifier is ignored for this verb.
- a word used both as verb and modifier — a COLLISION warning at parse
  time, before it bites.

For introspection, `make _HIDE= <verb>` exposes the hidden generated
names, and the `dump.registry` recipe (register it under your `dump`
verb, as the example does) prints every wired pair:

```
$ make dump registry
Registered verb.modifier pairs:
  build.frontend
  build.backend
  ...
```

## Composing with the other snippets

version.mk's `dump.version` slots straight in as a `dump` recipe:

```make
$(call modifier,version)
$(call register,dump,version)
```

bump.mk stays outside the verb grammar on purpose: `bump` has its own
modifier set (`major`, `patch`, `dev`, ...) that is filtered from
`MAKECMDGOALS` directly and would only collide with the registered
vocabulary. The same holds for any verb whose modifiers are values
rather than build scopes.

## Limits worth knowing

- One vocabulary per Makefile: modifiers are global words, not
  per-verb. `make build frontend clean` is one command line with two
  verbs and one modifier, and both verbs will see `frontend` active.
  Multi-verb invocations work but read badly; prefer one verb per
  invocation.
- Modifier flags are fixed at parse time from `MAKECMDGOALS`. Recipes
  cannot activate modifiers at run time.
- `make <modifier>` alone is a silent no-op (it's a no-op target).
  That's the cost of the grammar; `make help` should list the verbs.

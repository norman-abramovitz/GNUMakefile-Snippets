# guards.mk — recipe prerequisites that fail fast (vendorable, standalone)
#
#   require-%   Fail unless the named make/environment variable is set.
#               Use as a target prerequisite:
#                 ci-release: require-VERSION release-all
#               or invoke directly:
#                 make require-VERSION VERSION=1.2.3

.PHONY: require-%
require-%:
	@if [ -z "$($*)" ]; then \
		echo "Variable $* is not set" >&2; \
		exit 1; \
	fi

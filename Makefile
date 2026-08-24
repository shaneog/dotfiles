BATS ?= bats

.PHONY: test test-static test-unit test-integration test-vm lint audit brew-drift

test: test-static test-unit test-integration

test-static:
	$(BATS) test/static

test-unit:
	$(BATS) test/unit

test-integration:
	$(BATS) test/integration

# Deliberately not part of `test`: local only, needs Tart, and takes the better
# part of an hour. The one thing CI cannot cover -- a genuinely fresh macOS.
test-vm:
	test/vm/run

lint: test-static

# Upstream rot: renamed, deprecated or archived packages, plus tools the config
# invokes that no Brewfile installs. Runs weekly in CI; this is the same check.
audit:
	./script/audit

# What this machine has that the Brewfile does not, and the reverse. Advisory,
# and local only: on a machine provisioned by something else, most of the first
# list belongs to that something else.
brew-drift:
	./script/brew-drift

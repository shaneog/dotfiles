BATS ?= bats

.PHONY: test test-static test-unit test-integration test-cold test-vm lint audit brew-drift mutate

test: test-static test-unit test-integration

test-static:
	$(BATS) test/static

test-unit:
	$(BATS) test/unit

test-integration:
	$(BATS) test/integration

# Every plugin installed from nothing, which is when zinit's atclone hooks run.
# Not part of `test`: slow and network bound. Runs weekly in CI.
test-cold:
	DOTFILES_COLD_CACHE=1 $(BATS) test/integration/cold-cache.bats

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

# Breaks each thing in test/mutations.tsv and checks that the assertion named
# beside it notices. Needs a clean tree: it edits tracked files in place.
mutate:
	./script/mutate

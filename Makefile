BATS ?= bats

.PHONY: test test-static test-unit test-integration test-vm lint

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

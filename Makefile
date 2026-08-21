BATS ?= bats

.PHONY: test test-static test-unit test-integration lint

test: test-static test-unit test-integration

test-static:
	$(BATS) test/static

test-unit:
	$(BATS) test/unit

test-integration:
	$(BATS) test/integration

lint: test-static

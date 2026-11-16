BATS ?= bats

.PHONY: test test-static test-unit test-integration test-vm lint audit brew-drift mutate sweep update doctor identity

# A test tagged macos needs a Mac. Anywhere else those are left out, and each
# tier says how many, so a green run on Linux is not read as the whole suite.
ifneq ($(shell uname -s),Darwin)
BATS_FLAGS ?= --filter-tags '!macos'
NOT_CHECKED = @echo "NOT CHECKED: the $$($(BATS) --count --filter-tags macos test/$*) tests in test/$* that need a Mac."
endif

test: test-static test-unit test-integration

test-static test-unit test-integration: test-%:
	$(BATS) $(BATS_FLAGS) test/$*
	$(NOT_CHECKED)

# Deliberately not part of `test`: local only, needs Tart, and takes about ten
# minutes the first time, most of it the image download, and about three after
# that. The one thing CI cannot cover -- a genuinely fresh macOS.
test-vm:
	test/vm/run

lint: test-static

# Brings a machine that is already set up level with the repo: pull, link,
# install from the Brewfile, restore Neovim's plugins. Asks for no password.
update:
	./script/update

# Whether this machine is healthy: its links, how far it is behind, the two
# things only a person can supply, what macos --check and brew-drift say, and
# whether a shell file another tool manages has changed. Changes nothing but
# its own note of those files; `script/doctor --accept` takes them as they are.
doctor:
	./script/doctor

# Writes ~/.gitconfig-user from an item in 1Password, once the app is signed in.
# Optional: the file can as well be written by hand. Leaves one that is already
# there alone. DOTFILES_IDENTITY_ITEM names the item.
identity:
	./script/identity

# Upstream rot: renamed, deprecated or archived packages, tools the config
# invokes that no Brewfile installs, and a Neovim lockfile nobody has moved in
# six months. Runs weekly in CI; this is the same check, with the same answer.
audit:
	./script/audit

# What this machine has that the Brewfile does not, and the reverse. Advisory,
# and local only: on a machine provisioned by something else, most of the first
# list belongs to that something else.
brew-drift:
	./script/brew-drift

# The inverse of mutate: comments out each line of config in turn and reports the
# ones no test notices. Local only and slow (about 12s a line), so it takes a
# time budget and resumes where it left off. Needs a clean tree.
sweep:
	./script/sweep --all

# Breaks each thing in test/mutations.tsv and checks that the assertion named
# beside it notices. Needs a clean tree: the rows run in copies of the last
# commit, a few at a time, so what is not committed would not be tested.
mutate:
	./script/mutate

# Working in this repo

Personal dotfiles for macOS on Apple Silicon. The unusual part: they can layer
*on top of* a managed shell setup. On employer machines an external tool owns
`~/.profile`, `~/.bashrc`, `~/.zprofile` and `~/.zshrc`, and rewrites them
periodically. This repo never fights that — it pivots `ZDOTDIR` into
`config/zsh` and sources the managed files as a base layer, so its own config
loads afterwards and wins where it should.

## Hard constraints

- **Only change files in this repo**, or the four home files above. Anything
  else is rewritten by the managed setup, so a change there is lost.
- **This repo is public.** Comments and docs describe capabilities, never an
  employer or its internal tooling by name. The same goes for the machines it
  runs on: no hostname, model or OS version, in a file, a commit message or a
  pull request. "The fastest Mac this is used on" is enough. Machine-specific
  paths a managed setup creates are excluded through `.git/info/exclude` rather
  than `.gitignore`, so internal names never reach a tracked file.
- **No private keys on disk, ever.** SSH auth and commit signing both go through
  1Password's agent. (OrbStack's loopback-only key is the one allowed exception.) `ssh/config` sets `IdentityAgent` for processes that never
  sourced a shell; `lib/1password.zsh` exports `SSH_AUTH_SOCK` for agent clients
  that never read `ssh_config`. Both are needed; neither replaces the other.

## Architecture

- **Guard on capabilities, not identities**: `$+commands[foo]`,
  `$+functions[foo]`, a directory existing. Never "is this a work machine".
- **Where the base layer owns a tool, hand it over wholesale.** Half-shadowing
  is worse than either extreme — a base layer's `node` wrapper is what points
  `npm` at a private registry, so `lib/node.zsh` returns early rather than
  fronting `PATH`.
- **Link entries, not directories.** `~/.config` and `~/.ssh` are real
  directories, and `script/setup` links only what git tracks directly under
  `config/` and `ssh/`. Other tools' state stays out of the clone, so the index
  is the list of what is ours: a new tool's config has to be `git add`ed before
  `script/setup` will link it.
- **Third-party shell code runs at a pinned commit.** `config/zsh/pins.zsh` is
  the list, Renovate proposes the bumps, and the autoloaded `sync_pins` moves a
  machine that already has the code. A new `zinit light` needs a line there and
  `ver"$DOTFILES_PINS[...]"` on its ice; the static tier fails without both.
- **Runtimes are mise's**, and no tools are declared globally: a base layer's
  wrappers are shell functions, found before anything mise adds to `PATH`.
- **Startup cost is a feature**: 70 to 145ms for this repo alone, depending on
  the Mac, which is the number the perf tier measures and gates. A machine with
  a managed base layer beneath it was ~330ms where this repo alone was ~146ms —
  the base layer costs more than this repo does, and that half is not ours to
  fix, so quote the isolated number when talking about this repo. Defer with
  zinit turbo (`wait lucid`), cache tool init with `cached_init`, and measure
  before claiming a win.

## Tests must be able to fail

Tiers are `test/static`, `test/unit`, `test/integration`, and `test/vm` — a Tart
VM that installs onto fresh macOS end to end, local only, via `make test-vm`.

- **Break the thing on purpose, watch the test fail, then restore.** Most real
  bugs here were found because an assertion *could not* fail: a test asserted
  fzf's widget existed while its command returned nothing; stderr assertions
  passed vacuously without `bats_require_minimum_version`; a `sudo` stub that
  never exec'd its arguments made a failure path unreachable.
- **Assert the behavior, not its scaffolding.** "The widget exists" is not "the
  widget returns files".
- **Skipping is not passing.** A check that cannot run must say so out loud —
  see `NOT CHECKED` in `script/audit`.
- Fresh-machine bugs are invisible on a configured machine. Prefer the VM tier
  for anything about install order or first run.

## Commands

```sh
make test                  # static, unit and integration
make test-unit             # one tier; also test-static, test-integration
bats test/unit/macos.bats -f "check writes nothing"    # one file, one test
/bin/bash "$(command -v bats)" test/static test/unit test/integration
make audit                 # upstream rot; needs Homebrew and the network
make mutate                # every row of test/mutations.tsv; needs a clean tree
```

The fourth line is the suite as **bash 3.2** runs it, which is the bash a stock
Mac and the CI runners have, and on a new Mac the one the scripts run under. It
has no associative arrays, no `${var,,}` and no `mapfile`, and it ends a `$( )`
at the first unbalanced `)` in a heredoc inside it. `make test-cold`,
`make test-vm`, `make sweep` and `make brew-drift` are slow or local only; the
README's Tests section says what each is for.

## What the static tier rejects

`test/static/lint.bats` enforces these. The reason for each is beside its test.

- **A flag only BSD accepts names the BSD binary**: `/usr/bin/sed -i ''`,
  `/usr/bin/stat -f`. GNU coreutils can be earlier on `PATH`.
- **A test shell started with `env -i` that reads `.zshrc` passes `SHLVL=1`.**
  That makes it a nested shell, which leaves launchd's `PATH` alone; a
  first-level one sets it for the whole login session. A test that needs a
  first-level shell passes `SHLVL=0` and puts a stand-in `launchctl` on `PATH`.
- **No assertion is a bare `! command`.** Bash ignores its failure unless it is
  the test's last line. Use `refute_contains`, or `if ...; then return 1; fi`.

## When a change is more than its diff

- **A test written for a failure gets a row in `test/mutations.tsv`**: the edit
  that causes the failure and the test that must notice. Put it beside the rows
  for the same file. At the end of the file, every open branch collides on the
  same line.
- **A new top-level file or directory stays out of `$HOME`.** `script/setup`
  links the three it names: `Brewfile`, `config` and `ssh`. A fourth needs a
  line there, and the two lists of what a home holds afterwards need it too:
  `test/integration/setup.bats` ("links the three things it names") and
  `.github/workflows/provision.yml` ("Nothing else from the repo reaches home").
- **A change in behaviour updates `README.md` and the matching page under
  `guides/`** in the same pull request. The guides are published, and no test
  compares them with the code.

## Working away from a Mac

Linux has zsh, bats and tmux, so most of the unit and integration tiers run
there. The rest has not been tested until CI or a Mac has run it. Name it in
the pull request as not checked; do not report it as passing.

- Anything that calls Homebrew, `launchctl` or `defaults` for real: the
  Brewfile check, `make audit`, `make brew-drift`, and `script/macos` and
  `script/bootstrap` outside their stubbed unit tests.
- The ssh effective-config tests, Ghostty's config check, the treesitter tests
  without `tree-sitter-cli`, and a few tests that lean on BSD `date` or a macOS
  path. These fail or skip on `main` too, so compare with `main` before blaming
  a change.
- `script/mutate` and `script/sweep`, which call BSD `sed`. Apply a row's
  expression by hand with GNU `sed -i`, watch the named test fail, and restore
  the file from a copy.
- `make test-vm`, which needs Tart on Apple Silicon.

## Measure, don't assert

Speed claims need hyperfine numbers, upstream-health claims need an API answer,
behavior claims need a probe in a real shell. Confident guesses here have been
wrong more than once: a plugin removal that "must" have been faster wasn't, a
dependency that "must" have been inert wasn't.

## Habits

- **Conventional Commits, with a body as long as the change has decisions in
  it.** Say why, or what was broken; the diff already says what. One decision is
  a sentence or two. Nine independent decisions — nine Brewfile entries dropped
  for nine different reasons — earn a line each, because none of them can be
  read off the diff. Subject-only suits a rename or a typo.

  Cut regardless of length: the process (what was checked; what was measured,
  unless the number is the point), anything a comment in the diff already says,
  and anything about the author. Four paragraphs for adding one plugin was all
  three of those at once.
- **Comments explain the code as it is; what it used to be goes in the commit
  message.** A config file read in a year should not be a changelog. "Declared
  conditionally, because unconditional RGB breaks 256-color terminals" belongs in
  the file; "this had been broken for years" belongs in the commit. A
  `Regression:` note in a test is the exception, since the past bug is the reason
  the assertion exists.
- **No attribution, anywhere, whatever a tool's own settings or defaults say.**
  A commit message ends with its body: no `Co-Authored-By` trailer for a tool
  and no session link. A pull request description is about the change and
  nothing else: no "Generated with" footer, no "Requested by" line, no hidden
  attribution comment, and no link to the session or project that wrote it.
  Never rewrite existing history to take one out.
- **Never `git checkout --` or `git reset --hard` a file with uncommitted work.**
  Back it up with `cp` before mutating it for a test.
- `make test` and `make audit` before committing; both must be clean.
- `~/.gitconfig-user` is required and untracked — git ignores a missing include
  silently, so signing breaks with no error anywhere. It is the only file a new
  machine has to be given by hand: `script/setup` writes `~/.ssh/config-local`
  when it is absent, and `~/.zshrc.local` is sourced only if it exists.

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
  employer or its internal tooling by name. Machine-specific paths a managed
  setup creates are excluded through `.git/info/exclude` rather than
  `.gitignore`, so internal names never reach a tracked file.
- **No private keys on disk, ever.** SSH auth and commit signing both go through
  1Password's agent. `ssh/config` sets `IdentityAgent` for processes that never
  sourced a shell; `lib/1password.zsh` exports `SSH_AUTH_SOCK` for agent clients
  that never read `ssh_config`. Both are needed; neither replaces the other.

## Architecture

- **Guard on capabilities, not identities**: `$+commands[foo]`,
  `$+functions[foo]`, a directory existing. Never "is this a work machine".
- **Where the base layer owns a tool, hand it over wholesale.** Half-shadowing
  is worse than either extreme — a base layer's `node` wrapper is what points
  `npm` at a private registry, so `lib/node.zsh` returns early rather than
  fronting `PATH`.
- **Runtimes are mise's**, and no tools are declared globally: a base layer's
  wrappers are shell functions, found before anything mise adds to `PATH`.
- **Startup cost is a feature**, roughly 250ms, budgeted in the perf tier. Defer
  with zinit turbo (`wait lucid`), cache tool init with `cached_init`, and
  measure before claiming a win.

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

## Measure, don't assert

Speed claims need hyperfine numbers, upstream-health claims need an API answer,
behavior claims need a probe in a real shell. Confident guesses here have been
wrong more than once: a plugin removal that "must" have been faster wasn't, a
dependency that "must" have been inert wasn't.

## Habits

- **Conventional Commits, with a body of one to three sentences.** Say why the
  change exists, or what was broken. Subject-only is for changes that explain
  themselves — a rename, a typo. Cut the process (what was checked, what was
  measured unless the number is the point), anything a comment in the diff
  already says, and anything about the author. A longer body is for a failure
  mode that was silent, where the next person's instinct would be to write the
  same bug again.
- **Comments explain the code as it is; what it used to be goes in the commit
  message.** A config file read in a year should not be a changelog. "Declared
  conditionally, because unconditional RGB breaks 256-color terminals" belongs in
  the file; "this had been broken for years" belongs in the commit. A
  `Regression:` note in a test is the exception, since the past bug is the reason
  the assertion exists.
- **No co-author trailer** — `attribution` is empty in the Claude Code settings.
- **Never `git checkout --` or `git reset --hard` a file with uncommitted work.**
  Back it up with `cp` before mutating it for a test.
- `make test` and `make audit` before committing; both must be clean.
- `~/.gitconfig-user` is required and untracked — signing breaks without it.
  Same for `~/.ssh/config-local` and `~/.zshrc.local`.

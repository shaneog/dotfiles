# ShaneOG's Dotfiles

These are my dotfiles. There are many others like them, but these ones are mine. My dotfiles are my best friends. They are my life. I must master them as I must master my life. Without me, my dotfiles are useless. Without my dotfiles, I am useless.

## Installation

To install, run the following command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shaneog/dotfiles/HEAD/script/bootstrap)"
```

To install from somewhere other than the default branch -- a branch you are
still working on, a fork, a mirror, or a copy on a drive, which is handy on a
machine that has no GitHub credentials yet:

```sh
DOTFILES_URL=/Volumes/stick/dotfiles ./script/bootstrap
DOTFILES_REF=some-branch ./script/bootstrap
```

### Commit signing (required)

`.config/git/config` turns on SSH commit signing unconditionally, but the key
itself is machine-specific, so **`~/.gitconfig-user` has to exist before the
first commit on a new machine**. Without it git fails with *either
user.signingkey or gpg.ssh.defaultKeyCommand needs to be configured*.

```
[user]
	name = Your Name
	email = you@example.com
	signingkey = ssh-ed25519 AAAA...        # the public key, not a path
```

Signing goes through 1Password's `op-ssh-sign`, so 1Password needs to be
installed and its SSH agent enabled (Settings, Developer, Use the SSH agent).
`git log --show-signature` verifies against `.config/git/allowed_signers`.

As an alternative to naming a key, `gpg.ssh.defaultKeyCommand = ssh-add -L`
signs with whatever the agent lists first -- convenient, but it silently
follows the agent's ordering.

### Local Overrides

The following files allow for local overrides:

| File Path | Local Override File Path |
| ------------- | ------------- |
| .config/git/config  | .gitconfig-user |
| .ssh/config  | .ssh/config-local  |
| .zshrc  | .zshrc.local  |


To ignore local changes to already committed files such as `.ssh/config-local`, use `git update-index --skip-worktree <file>`.

### Environment Knobs

| Variable | Effect |
| ------------- | ------------- |
| `ZSH_NO_TMUX_AUTOSTART` | Don't attach a tmux session for this shell. Autostart only ever fires from Terminal.app, so editors, IDE terminals, ssh sessions and scripts are already left alone. |
| `ZSH_NO_ZCOMPILE` | Skip the background compile of the completion dump. |
| `DOTFILES_URL`, `DOTFILES_REF` | Where `script/bootstrap` installs from. |

### Screenshots

#### Gotham Theme
![Gotham](http://i.imgur.com/XzBeOlz.png)

#### Solarized Dark
![Solarized Dark](http://i.imgur.com/A5VCt8K.png)

---

## Tests

```sh
make test              # everything, about 35s
make test-static       # parsing, linting and a secret scan
make test-unit         # capability guards and autoloaded functions
make test-integration  # the real startup chain in a disposable $HOME
```

Layering is covered by a fixture that impersonates a managed shell setup owning
`~/.zprofile` and `~/.zshrc`, so the tests behave the same on a machine that has
no such setup, and both configurations are asserted.

Two suites are opt-in, being slow or noisy:

```sh
DOTFILES_COLD_CACHE=1 make test-integration   # install from an empty plugin cache
SKIP_PERF=1 make test-integration             # skip startup timing (CI skips it on push)
```

The suite has to pass under **bash 3.2**, which is what a stock Mac and the CI
runners provide, and which parses some things differently to a modern bash:

```sh
/bin/bash "$(command -v bats)" test/static test/unit test/integration
```

A fresh-machine test runs locally only, since CI runners are not fresh Macs --
Homebrew, the command line tools, pyenv and nvm are all preinstalled there:

```sh
make test-vm            # boot macOS 26 in Tart, install end to end, destroy
test/vm/run --keep      # leave the VM up to poke at
```

It needs [Tart](https://tart.run), which Homebrew now gates behind tap trust:

```sh
brew trust --formula openai/tools/softnet
brew install openai/tools/tart
```

The base image is tens of gigabytes on first use, but it is cached after that,
and a full run is quicker than you would think. Measured on macOS 26:

| | |
| ------------- | ------------- |
| Pulling the base image (once) | 546s |
| Boot, ssh, copy the tree in | ~20s |
| `script/bootstrap`, of which | 44s |
| &nbsp;&nbsp;Homebrew from scratch | 10s |
| &nbsp;&nbsp;`script/macos` | 1s |
| &nbsp;&nbsp;Brewfile, formulae only | 29s |
| &nbsp;&nbsp;`after-setup` | 30s |
| First login shell, installing every plugin | 24s |
| **Whole run, image cached** | **95s** |

So a bare machine reaches a working shell inside two minutes, plus whatever the
casks cost.

This test has earned its keep twice. `script/macos` used to take 121s of that,
all of it an AppleScript waiting on an AppleEvent that a headless machine can
never deliver. And `after-setup` could hang indefinitely on a "Press ENTER"
prompt -- intermittently, which is why it needed a real machine to catch: CI
passed it every time, because a runner hands every step /dev/null on stdin. `script/bootstrap` is pointed at a copy of the working tree via
`DOTFILES_URL`, so it installs the current branch rather than whatever is on the
default one.

Two workflows run it. `test` runs the suite on every push, against both the
system and Homebrew zsh. `provision` runs the scripts that set up a machine --
`bootstrap`, `setup`, `macos`, `remove` -- for real on disposable runners,
weekly and on demand, since they otherwise only ever run on a new machine.

---

## ZSH Performance

Currently **~146ms** for an interactive login shell in isolation, and ~330ms on
a machine that also has a managed shell setup layered underneath — that setup
costs more than this repo does, and none of it is this repo's to reclaim.

Measured with `hyperfine` and guarded by a budget in
`test/integration/perf.bats`, which prints what it measured on every run:

```sh
hyperfine --warmup 3 'zsh -lic exit'
```

Most of what remains is plugin loading. Two things dominated it historically and
are worth remembering: a completion dump that was never cached cost ~340ms per
shell, and compiling the zsh sources to `.zwc` saved nothing measurable.

The runs below are a historical log, kept for the shape of the curve rather than
as current figures.

Benchmark Details:
- macOS Monterey 12.2.1
- Terminal.app
- command: `for i in $(seq 1 10); do /usr/bin/time zsh -i -c exit; done`

References:
- https://htr3n.github.io/2018/07/faster-zsh/
- https://carlosbecker.com/posts/speeding-up-zsh/

### Factory Fresh Install

No dotfiles.

```
        0.02 real         0.00 user         0.00 sys
        0.01 real         0.00 user         0.00 sys
        0.01 real         0.00 user         0.00 sys
        0.01 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
        0.00 real         0.00 user         0.00 sys
```

## These dotfiles _(pre: 2022-03-06)_

```
        2.29 real         0.68 user         0.76 sys
        2.29 real         0.66 user         0.78 sys
        2.24 real         0.65 user         0.75 sys
        2.23 real         0.65 user         0.77 sys
        2.18 real         0.66 user         0.74 sys
        2.23 real         0.66 user         0.75 sys
        2.15 real         0.65 user         0.74 sys
        2.29 real         0.66 user         0.76 sys
        2.24 real         0.66 user         0.76 sys
        2.23 real         0.66 user         0.77 sys
```

## New Setup - 1:1 Copy of Old

Migrated from [`zplug`](https://github.com/zplug/zplug) to [`zinit`](https://github.com/zdharma-continuum/zinit).

Results:
- 10x slowdown from zero dotfiles
- **10x faster** than zplug configuration


```
        0.24 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.22 real         0.07 user         0.06 sys
        0.25 real         0.07 user         0.06 sys
        0.23 real         0.07 user         0.06 sys
        0.22 real         0.07 user         0.06 sys
```

## Refactored Setup

Migrated from [`Spaceship`](https://spaceship-prompt.sh/) to [`Starship`](https://starship.rs/).

Runtimes are [`mise`](https://mise.jdx.dev)'s, replacing `nodenv`, `pyenv`,
`pyenv-virtualenv` and `sdkman`. No tools are declared globally: on a machine
whose managed shell already owns a runtime -- `nvm` wrapping `node`, `sdkman`
wrapping `sdk` -- those wrappers are shell functions and are found before
anything `mise` puts on `PATH`, so they keep winning. Declare tools per project
in a `mise.toml`, or with `mise use -g` where nothing else claims them.

```
        0.69 real         0.34 user         0.15 sys
        0.66 real         0.33 user         0.14 sys
        0.66 real         0.33 user         0.14 sys
        0.64 real         0.33 user         0.15 sys
        0.65 real         0.33 user         0.15 sys
        0.70 real         0.33 user         0.14 sys
        0.66 real         0.34 user         0.15 sys
        0.68 real         0.34 user         0.15 sys
        0.67 real         0.34 user         0.15 sys
        0.69 real         0.34 user         0.15 sys
```

### Using `zinit light`

Removing any turbo mode, which was causing random `zsh` crashes.

```
        0.74 real         0.37 user         0.17 sys
        0.71 real         0.36 user         0.16 sys
        0.70 real         0.36 user         0.16 sys
        0.74 real         0.37 user         0.17 sys
        0.74 real         0.36 user         0.16 sys
        0.76 real         0.36 user         0.16 sys
        0.70 real         0.37 user         0.17 sys
        0.74 real         0.37 user         0.17 sys
        0.73 real         0.36 user         0.16 sys
        0.74 real         0.36 user         0.16 sys
```

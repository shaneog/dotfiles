<div align="center">

# ShaneOG's Dotfiles

[![test](https://github.com/shaneog/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/shaneog/dotfiles/actions/workflows/test.yml)
[![provision](https://github.com/shaneog/dotfiles/actions/workflows/provision.yml/badge.svg)](https://github.com/shaneog/dotfiles/actions/workflows/provision.yml)
[![audit](https://github.com/shaneog/dotfiles/actions/workflows/audit.yml/badge.svg)](https://github.com/shaneog/dotfiles/actions/workflows/audit.yml)
[![macOS on Apple Silicon](https://img.shields.io/badge/macOS-Apple%20Silicon-000000?logo=apple&logoColor=white)](#install)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE.md)

**[Illustrated guides](https://ogrady.ie/dotfiles/)** ·
[Install](#install) ·
[By hand](#what-a-machine-needs-by-hand) ·
[Update](#update) ·
[Uninstall](#uninstall) ·
[Read more](#read-more)

</div>

> These are my dotfiles. There are many others like them, but these ones are
> mine. My dotfiles are my best friends. They are my life. I must master them as
> I must master my life. Without me, my dotfiles are useless. Without my
> dotfiles, I am useless.

zsh, tmux, Neovim, git, Ghostty and Claude Code for macOS on Apple Silicon, with
the Homebrew packages around them. One command installs everything on a new Mac, and one
script takes it out again.

- **Layers over a managed shell.** On a machine where another tool owns
  `~/.zprofile` and `~/.zshrc`, those files are sourced as a base layer instead
  of being replaced, and this config loads on top.
- **No private keys on disk.** SSH authentication and commit signing both go
  through 1Password's agent.
- **Links entries, not directories.** `~/.config` and `~/.ssh` stay real
  directories. Only what git tracks is linked into them, so other tools' files
  never end up in the clone.
- **Plugins come from Homebrew.** The zsh plugins are formulae in the
  [`Brewfile`](Brewfile). There is no plugin manager, and a shell never
  downloads anything.
- **Startup time is tested.** An interactive login shell starts in well under a
  tenth of a second on the fastest Mac this is used on, and a test fails when
  it goes over budget.

This page says how to install, update and remove them. How they work is in the
[guides](#read-more), and the rules for changing them are in
[`AGENTS.md`](AGENTS.md).

## Install

On a new Mac, as your own user (an admin, not root):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shaneog/dotfiles/HEAD/script/bootstrap)"
```

It asks for your password once, for `sudo`. Then it installs Homebrew, clones
this repo to `~/.dotfiles`, links it into your home directory, applies the
macOS settings, installs everything in the [`Brewfile`](Brewfile), makes
Homebrew's zsh the login shell and installs Neovim's plugins. The first shell
you open afterwards has nothing left to fetch.

Running the same command again later is safe, and so is
`~/.dotfiles/script/bootstrap`. [Setting up a new Mac][install] goes through
each step, how long it takes, and how to install from a branch, a fork or a
copy on a drive.

## What a machine needs by hand

Two things are about who you are, so no script can supply them. Bootstrap ends
by naming whichever of the two is still missing.

**1. `~/.gitconfig-user`.** Every commit and tag is signed, and this file is
where git learns your name and which key to sign with. Without it a commit
fails with *either user.signingkey or gpg.ssh.defaultKeyCommand needs to be
configured*.

```
[user]
	name = Your Name
	email = you@example.com
	signingkey = ssh-ed25519 AAAA...        # the public key, not a path
```

Write it by hand, or keep the three values in 1Password and let it write the
file. That comes after bootstrap, because the 1Password app has to be signed in
first:

```sh
make identity
```

[Or have 1Password write it][identity] says what the item has to look like.

**2. 1Password's SSH agent.** In 1Password, open Settings, then Developer, and
switch on "Use the SSH agent". SSH and commit signing both go through it.
[Keys, 1Password and a fingerprint][keys] explains how.

The apps are a third step, and an optional one. Those that keep their settings
in 1Password get them back from there, and the same command then walks through
what each still needs from you, a permission or a licence:

```sh
make apps
```

[Give the apps their settings][apps] says which apps, and how the settings get
into 1Password in the first place.

Two more files are yours to fill in on a machine that needs them, and neither
is required: `~/.ssh/config-local` and `~/.zshrc.local`.
[Where the files live][local] says what each is for.

## Update

On a machine that is already set up, from `~/.dotfiles`:

```sh
make update    # pull, link, install from the Brewfile, restore Neovim's plugins
make doctor    # report on this machine, and change nothing
```

`make update` is the part of bootstrap that needs no password. `make doctor`
says whether the machine is healthy: its links, how far it is behind, the two
things above, and what has drifted. It exits non-zero only for something
broken. [Keeping a Mac up to date][update] has the detail of both.

## Uninstall

```sh
~/.dotfiles/script/remove                # the dotfiles
~/.dotfiles/script/remove --everything   # and Homebrew, its packages and the Command Line Tools
```

It asks before doing anything. Then it removes the links in `~`, `~/.config`,
`~/.ssh` and `~/.claude`, the clone at `~/.dotfiles`, and the caches the shell
config generates, and sets the login shell back to `/bin/zsh`.

It leaves alone your shell history, everything under `~/.config`, `~/.ssh` and
`~/.claude` that is not a link into the clone, and the macOS settings
`script/macos` wrote.
The Gotham profile has to be removed from Terminal.app by hand.
[Taking it all out again][remove] says how to put the macOS settings back.

## Read more

The guides are published at <https://ogrady.ie/dotfiles/>. Their source is in
[`guides/`](guides/), plain HTML with no build step, so the same pages open
from a clone with `open guides/index.html`.

| Guide | What it explains |
| --- | --- |
| [Start here](https://ogrady.ie/dotfiles/index.html) | What dotfiles are, the ideas behind this repo, and a map of it. |
| [New Mac](https://ogrady.ie/dotfiles/install.html) | Bootstrap step by step, updating, the doctor, and removal. |
| [Where files live](https://ogrady.ie/dotfiles/layout.html) | What gets linked where, what git ignores, the per-machine files, and Claude Code's folder. |
| [Opening a terminal](https://ogrady.ie/dotfiles/shell.html) | How a shell starts, layering over a managed setup, tmux, and startup time. |
| [Keys and 1Password](https://ogrady.ie/dotfiles/keys.html) | SSH, commit signing and Touch ID for `sudo`. |
| [Toolbox](https://ogrady.ie/dotfiles/tools.html) | The cheat sheet: what is installed, aliases, key bindings and switches. |
| [Staying healthy](https://ogrady.ie/dotfiles/tests.html) | The tests, the checks on upstream, and the CI workflows. |

[`AGENTS.md`](AGENTS.md) holds the rules for working in this repo, for people
and coding agents alike. A script's own flags are in the comment at the top of
the script.

## License

[MIT](LICENSE.md)

[install]: https://ogrady.ie/dotfiles/install.html
[identity]: https://ogrady.ie/dotfiles/install.html#identity
[apps]: https://ogrady.ie/dotfiles/install.html#apps
[update]: https://ogrady.ie/dotfiles/install.html#update
[remove]: https://ogrady.ie/dotfiles/install.html#remove
[keys]: https://ogrady.ie/dotfiles/keys.html
[local]: https://ogrady.ie/dotfiles/layout.html#local

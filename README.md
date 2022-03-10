# ShaneOG's Dotfiles

These are my dotfiles. There are many others like them, but these ones are mine. My dotfiles are my best friends. They are my life. I must master them as I must master my life. Without me, my dotfiles are useless. Without my dotfiles, I am useless.

## Installation

To install, run the following command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shaneog/dotfiles/HEAD/script/bootstrap)"
```

### Keybase/GPG

To import a PGP key from Keybase.io:

```sh
keybase pgp export --secret | gpg --allow-secret-key-import --import
```

### Local Overrides

The following files allow for local overrides:

| File Path | Local Override File Path |
| ------------- | ------------- |
| .config/git/config  | .gitconfig-user |
| .ssh/config  | .ssh/config-local  |
| .zshrc  | .zshrc.local  |


To ignore local changes to already committed files such as `.ssh/config-local`, use `git update-index --skip-worktree <file>`.

### Screenshots

#### Gotham Theme
![Gotham](http://i.imgur.com/XzBeOlz.png)

#### Solarized Dark
![Solarized Dark](http://i.imgur.com/A5VCt8K.png)

---

## ZSH Performance

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

Configured and enabled [`nodenv`](https://github.com/nodenv/nodenv) and [`pyenv`](https://github.com/pyenv/pyenv).

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

#!/usr/bin/env zsh

# Deferred: this is ~150 git aliases and a run-help function, none of which can
# matter before the first prompt. The utility module is deferred for the same
# reason. alias.zsh is fetched explicitly because the module sources it by path.
zinit ice wait lucid blockf \
  atclone"git clone -q --depth=1 https://github.com/sorin-ionescu/prezto.git external"
zinit snippet PZTM::git
zinit ice wait lucid
zinit snippet PZTM::git/alias.zsh

#!/usr/bin/env zsh

zinit ice blockf \
  atclone"git clone -q --depth=1 https://github.com/sorin-ionescu/prezto.git external"
zinit snippet PZTM::git
zinit snippet PZTM::git/alias.zsh

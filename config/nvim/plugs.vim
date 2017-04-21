
call plug#begin('~/.config/nvim/plugged')

  " ------------------------------------------------------------------------------
  " Editor necessities
  " ------------------------------------------------------------------------------

  " EditorConfig support (http://editorconfig.org)
  Plug 'editorconfig/editorconfig-vim'


  " ------------------------------------------------------------------------------
  " Language or Framework supporting plugins
  " ------------------------------------------------------------------------------

  " Most common languages support (syntax, indenting, etc. ) for ruby, js, etc.
  Plug 'sheerun/vim-polyglot'
  " Commenting support (gc)
  Plug 'tpope/vim-commentary', { 'on': '<Plug>Commentary' }
  " ALE - Asynchronous Lint Engine
  Plug 'w0rp/ale', { 'on': 'ALEEnable', 'for': ['go', 'ruby', 'sh'] }


  " -----------------------------------------------------
  " Go
  " -----------------------------------------------------
  Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }


  " -----------------------------------------------------
  " Ruby/Rails
  " -----------------------------------------------------

  " (:A, :R, :Rmigration, :Rextract)
  Plug 'tpope/vim-rails', { 'for': ['ruby', 'eruby', 'haml', 'slim'] }
  " (:Bundle)
  Plug 'tpope/vim-bundler'
  " Automatically inserts 'end' wisely
  Plug 'tpope/vim-endwise', { 'for': ['ruby', 'eruby'] }
  " Rails I18 support
  Plug 'stefanoverna/vim-i18n', { 'for': ['ruby', 'eruby'], 'on': 'I18nTranslateString'  }


  " -----------------------------------------------------
  " HTML/CSS
  " -----------------------------------------------------

  " HAML support
  Plug 'tpope/vim-haml', { 'for': ['haml'] }


  " ------------------------------------------------------------------------------
  " Files/code navigation/management plugins
  " ------------------------------------------------------------------------------

  " Files, Buffers, Commands, etc. fuzzy searcher
  Plug '$HOME/.zplug/repos/junegunn/fzf' | Plug 'junegunn/fzf.vim'
  " MRU list for fzf
  Plug 'tweekmonster/fzf-filemru'


  " ------------------------------------------------------------------------------
  " External tools integration plugins
  " ------------------------------------------------------------------------------

  " Git changes showed on line numbers
  Plug 'airblade/vim-gitgutter'


  " ------------------------------------------------------------------------------
  " Text insertion/manipulation
  " ------------------------------------------------------------------------------

  " Easy alignment
  Plug 'junegunn/vim-easy-align'
  " Surround (cs"')
  Plug 'tpope/vim-surround'


  " ------------------------------------------------------------------------------
  " Interface improving plugins
  " ------------------------------------------------------------------------------

  " Airline (improved status line)
  Plug 'vim-airline/vim-airline'


  " ------------------------------------------------------------------------------
  "  Colorschemes
  " ------------------------------------------------------------------------------

  " Solarized
  Plug 'altercation/vim-colors-solarized'
  " Gotham
  Plug 'whatyouhide/vim-gotham'



call plug#end()
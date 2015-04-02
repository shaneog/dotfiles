" Plugins
call plug#begin('~/.vim/bundle')


" ------------------------------------------------------------------------------
" Editor necessities
" ------------------------------------------------------------------------------

" Some sane defaults
Plug 'tpope/vim-sensible'
" Tags (ctags) management
Plug 'ludovicchabant/vim-gutentags'
" EditorConfig support (http://editorconfig.org)
Plug 'editorconfig/editorconfig-vim'


" ------------------------------------------------------------------------------
" Language or Framework supporting plugins
" ------------------------------------------------------------------------------

" Most common languages support (syntax, indenting, etc. ) for ruby, js, etc.
Plug 'sheerun/vim-polyglot'
" Needs linters to work properly (see https://github.com/scrooloose/syntastic/wiki/Syntax-Checkers)
Plug 'scrooloose/syntastic', { 'for': ['ruby', 'coffee', 'javascript', 'scss', 'html', 'haml'] }
" Commenting support (gc)
Plug 'tpope/vim-commentary'


" -----------------------------------------------------
" Ruby/Rails
" -----------------------------------------------------

" (:A, :R, :Rmigration, :Rextract)
Plug 'tpope/vim-rails', { 'for': ['ruby', 'eruby', 'haml', 'slim'] }
" Automatically inserts 'end' wisely
Plug 'tpope/vim-endwise', { 'for': ['ruby', 'eruby'] }
" Rails I18 support
Plug 'stefanoverna/vim-i18n', { 'for': ['ruby', 'eruby'], 'on': 'I18nTranslateString'  }
" Ruby best practices checker
Plug 'ngmy/vim-rubocop', { 'for': ['ruby', 'eruby'], 'on': 'RuboCop' }
" RSpec within vim (:RunNearestSpec, :RunCurrentSpecFile)
Plug 'thoughtbot/vim-rspec', { 'for': ['ruby'] }
" (:Bundle)
Plug 'tpope/vim-bundler'


" -----------------------------------------------------
" HTML/CSS
" -----------------------------------------------------

" CSS color highlighter
Plug 'gorodinskiy/vim-coloresque', { 'for': ['css', 'sass', 'scss', 'less'] }
" Sparkup, emmet alternative (<C-e> to expand expression)
Plug 'rstacruz/sparkup', { 'for': ['html', 'xhtml'] }
" Spacebars (handlebars/mustache)
Plug 'slava/vim-spacebars', { 'for': ['html', 'xhtml'] }
" HAML support
Plug 'tpope/vim-haml', { 'for': ['haml'] }
" HTML5 support
Plug 'othree/html5.vim', { 'for': ['html', 'xhtml'] }


" -----------------------------------------------------
" JavaScript / CoffeeScript
" -----------------------------------------------------

" Tern auto-completion engine
Plug 'marijnh/tern_for_vim', { 'do': 'npm install && npm install tern-coffee', 'for': ['javascript', 'coffee'] }
" Tern for CoffeeScript
Plug 'othree/tern_for_vim_coffee', { 'for': ['javascript', 'coffee']}
" JS libs syntax files, ember, angular, etc.
Plug 'othree/javascript-libraries-syntax.vim', { 'for': ['javascript', 'coffee'] }


" ------------------------------------------------------------------------------
" Files/code navigation/management plugins
" ------------------------------------------------------------------------------

" Extends :e, :new to create new directories in path
Plug 'duggiefresh/vim-easydir'
" Unite (Files, Buffers, Commands, etc. fuzzy searcher)
Plug 'Shougo/unite.vim'
" Unite outline plugin
Plug 'Shougo/unite-outline'
" vinegar enhances netrw
Plug 'tpope/vim-vinegar'


" ------------------------------------------------------------------------------
" External tools integration plugins
" ------------------------------------------------------------------------------

" Git wrapper
Plug 'tpope/vim-fugitive'
" Git changes showed on line numbers
Plug 'airblade/vim-gitgutter'
" Gitk for vim
Plug 'gregsexton/gitv', { 'on':  'Gitv' }

" ------------------------------------------------------------------------------
" Text insertion/manipulation
" ------------------------------------------------------------------------------

" Completion with tab
Plug 'ervandew/supertab'
" Multiple cursors
Plug 'terryma/vim-multiple-cursors'
" Surround (cs"')
Plug 'tpope/vim-surround'
" Easy alignment
Plug 'godlygeek/tabular', { 'on':  'Tabularize' }
" Match pairs of things
Plug 'tpope/vim-unimpaired'
" Emoji support :heart:
Plug 'junegunn/vim-emoji'


" ------------------------------------------------------------------------------
" Interface improving plugins
" ------------------------------------------------------------------------------

" Nerdtree file browser
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeFind', 'NERDTreeToggle'] }
" Airline (improved status line)
Plug 'bling/vim-airline'
" Tagbar tag browser
Plug 'majutsushi/tagbar'
" Automatic cursor toggle
Plug 'jszakmeister/vim-togglecursor'

" ------------------------------------------------------------------------------
"  Colorschemes
" ------------------------------------------------------------------------------

" Solarized
Plug 'altercation/vim-colors-solarized'
" Gotham
Plug 'whatyouhide/vim-gotham'
" Monokai
Plug 'modess/molokai'
" Seoul 256
Plug 'junegunn/seoul256.vim'


" ------------------------------------------------------------------------------
" Dependencies
" ------------------------------------------------------------------------------

" Async processing (for Unite)
Plug 'Shougo/vimproc.vim', { 'do': 'make' }
" Matchit enhances motions like %
Plug 'edsono/vim-matchit'
" Repeat adds repeat via . functionality for some plugins
Plug 'tpope/vim-repeat'


call plug#end()
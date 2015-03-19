" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
if has('vim_starting')
  if &compatible
    set nocompatible
  endif
endif

" enable syntax highlighting
syntax enable

" Turn off modelines
set modelines=0

" install plugins
if filereadable(expand("~/.vim/bundles.vim"))
  source ~/.vim/bundles.vim
endif

filetype plugin indent on

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed
" Enhance command-line completion
set wildmenu
set wildmode=list:longest,list:full
" Allow cursor keys in insert mode
set esckeys
" Allow backspace in insert mode
set backspace=indent,eol,start
" Optimize for fast terminal connections
set ttyfast
" Add the g flag to search/replace by default
set gdefault
" Use UTF-8 without BOM
set encoding=utf-8 nobomb
" Don’t add empty newlines at the end of files (by default)
set binary
set noeol

" Centralize backups, swapfiles and undo history
silent !mkdir ~/.vim/backups > /dev/null 2>&1
silent !mkdir ~/.vim/swaps > /dev/null 2>&1
silent !mkdir ~/.vim/undo > /dev/null 2>&1
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
  set undodir=~/.vim/undo
  set undofile
endif

"Store lots of :cmdline history
set history=1000

" Enable line numbers
set number
set numberwidth=5
" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif
" Highlight current line
set cursorline
" Highlight current column
set cursorcolumn
" Softtabs, 2 spaces
set tabstop=2
set shiftwidth=2
set smarttab
set expandtab

" Highlight searches
set hlsearch
" Ignore case of searches
set ignorecase
" Highlight dynamically as pattern is typed
set incsearch
"No sounds
set visualbell
" Don’t reset cursor to start of line when moving around.
set nostartofline
" Show the cursor position
set ruler
" Don’t show the intro message when starting Vim
set shortmess=atI
" Show the current mode
set showmode
" Show the filename in the window titlebar
set title
" Show the (partial) command as it’s being typed
set showcmd

" always set autoindenting on
set autoindent
set smartindent
" Display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" Use relative line numbers
if exists("&relativenumber")
  set relativenumber
  au BufReadPost * set relativenumber
endif
" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Use $ to show changes
set cpoptions+=$

" Automatic commands
if has("autocmd")
  " Enable file type detection
  filetype on
endif

" Folding
" fold based on indent
set foldmethod=indent
" deepest fold is 3 levels
set foldnestmax=3
" don't fold by default
set nofoldenable

" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd =

" Color scheme
colo seoul256
" set 256 color mode
set t_Co=256

" Switch wrap off for everything
set nowrap

" Make it obvious where 80 characters is
set textwidth=80
set colorcolumn=+1,110

if has('mouse')
  " Enable mouse in all modes
  set mouse=a
  "set selection=exclusive
  set selectmode=mouse,key
  set nomousehide
endif

" Open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" Always use vertical diffs
set diffopt+=vertical


" --------------------
" Custom key mappings
" --------------------

" <Space> is the leader character
let mapleader = " "
" Tab completion
" will insert tab at beginning of line,
" will use completion if not at beginning
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>
inoremap <S-Tab> <c-n>

" Switch between the last two files
nnoremap <leader><leader> <c-^>

" Get off my lawn
"nnoremap <Left> :echoe "Use h"<CR>
"nnoremap <Right> :echoe "Use l"<CR>
"nnoremap <Up> :echoe "Use k"<CR>
"nnoremap <Down> :echoe "Use j"<CR>

" Scroll the viewport faster
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" vim-rspec mappings
nnoremap <Leader>t :call RunCurrentSpecFile()<CR>
nnoremap <Leader>s :call RunNearestSpec()<CR>
nnoremap <Leader>l :call RunLastSpec()<CR>

" Run commands that require an interactive shell
nnoremap <Leader>r :RunInInteractiveShell<space>


" Index ctags from any project, including those outside Rails
map <Leader>ct :!ctags -R .<CR>

" --------------------
" Syntastic Settings
" --------------------
" configure syntastic syntax checking to check on open as well as save
let g:syntastic_check_on_open=1
let g:syntastic_html_tidy_ignore_errors=[" proprietary attribute \"ng-"]



" --------------------
" File Type Settings
" --------------------
" md is markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.md set spell
" extra rails.vim help
autocmd User Rails silent! Rnavcommand decorator      app/decorators            -glob=**/* -suffix=_decorator.rb
autocmd User Rails silent! Rnavcommand observer       app/observers             -glob=**/* -suffix=_observer.rb
autocmd User Rails silent! Rnavcommand feature        features                  -glob=**/* -suffix=.feature
autocmd User Rails silent! Rnavcommand job            app/jobs                  -glob=**/* -suffix=_job.rb
autocmd User Rails silent! Rnavcommand mediator       app/mediators             -glob=**/* -suffix=_mediator.rb
autocmd User Rails silent! Rnavcommand stepdefinition features/step_definitions -glob=**/* -suffix=_steps.rb

" Exclude Javascript files in :Rtags via rails.vim due to warnings when parsing
let g:Tlist_Ctags_Cmd="ctags --exclude='*.js'"

" Treat <li> and <p> tags like the block tags they are
let g:html_indent_tags = 'li\|p'

" Autoreload settings files
augroup reload_vimrc " {
    autocmd!
    autocmd BufWritePost vimrc source $MYVIMRC
    " Also auto reload our bundles file
    autocmd BufWritePost bundles.vim source $MYVIMRC 
    autocmd BufWritePost bundles.vim PlugInstall
augroup END " }

" ================ Custom Settings ========================
if filereadable(expand("~/.vim/settings.vim"))
  so ~/.vim/settings.vim
endif
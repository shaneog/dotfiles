map <Leader>b :CtrlPBuffer<cr>
let g:ctrlp_match_window_bottom   = 0
let g:ctrlp_match_window_reversed = 0

" Allow CtrlP to find/index dotfiles
let g:ctrlp_show_hidden = 1

" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
if executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor
  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

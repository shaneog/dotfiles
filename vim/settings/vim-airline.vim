" Use powerline symbols
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1
let g:airline#extensions#branch#empty_message = "No VCS"
let g:airline#extensions#whitespace#enabled = 1
let g:airline#extensions#syntastic#enabled = 1
" Display all buffers when there's only one tab open
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#tab_nr_type = 1
let g:airline#extensions#tabline#fnamecollapse = 1
let g:airline#extensions#hunks#non_zero_only = 1

" Use solarized theme
let g:airline_theme = "solarized"
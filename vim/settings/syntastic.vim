let g:syntastic_ruby_checkers = ['mri']
" mark syntax errors with :signs
let g:syntastic_enable_signs = 1
" automatically jump to the error when saving the file
let g:syntastic_auto_jump = 0
" show the error list automatically
let g:syntastic_auto_loc_list = 1
" check on open as well as save
let g:syntastic_check_on_open = 1
" Use custom error symbols
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '⚠'
let g:syntastic_style_error_symbol = '»'
let g:syntastic_style_warning_symbol = '»'
" Ignore certain errors
let g:syntastic_html_tidy_ignore_errors=[
  \ 'trimming empty <i>',
  \ 'trimming empty <span>',
  \ '<input> proprietary attribute \"autocomplete\"',
  \ 'proprietary attribute \"role\"',
  \ '<svg> is not recognized!',
  \ 'discarding unexpected <svg>',
  \ 'discarding unexpected </svg>'
  \ ]

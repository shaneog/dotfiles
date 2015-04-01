" Matcher settings
call unite#filters#matcher_default#use(['matcher_fuzzy'])
call unite#filters#sorter_default#use(['sorter_rank'])
call unite#custom#source('file_rec/async','sorters','sorter_rank')

" Track yank history
let g:unite_source_history_yank_enable=1

" Use ag if available
if executable('ag')
  let g:unite_source_grep_command='ag'
  let g:unite_source_grep_default_opts='--nocolor --line-numbers --nogroup -S -C0'
  let g:unite_source_grep_recursive_opt=''
  " Ignore vcs files
  let g:unite_source_rec_async_command='ag --nocolor --nogroup --ignore ".hg" --ignore ".svn" --ignore ".git" --ignore ".bzr" --ignore ".meteor"--hidden -g ""'
  let g:unite_source_file_async_command='ag --nocolor --nogroup --ignore ".hg" --ignore ".svn" --ignore ".git" --ignore ".bzr" --ignore ".meteor" --hidden -g ""'
endif

" Ignore wildignore files
call unite#custom#source('file_rec', 'ignore_globs', split(&wildignore, ','))

" Custom profile
call unite#custom#profile('default', 'context', {
      \   'prompt': '» ',
      \   'winheight': 15,
      \ })

" Add syntax highlighting
let g:unite_source_line_enable_highlight=1


" ============================================================================================================
" Mappings
" ============================================================================================================
" Custom mappings for the unite buffer
autocmd FileType unite call s:unite_settings()

function! s:unite_settings()
  " Play nice with supertab
  let b:SuperTabDisabled=1
  " Enable navigation with control-j and control-k in insert mode
  imap <silent> <buffer> <C-j> <Plug>(unite_select_next_line)
  imap <silent> <buffer> <C-k> <Plug>(unite_select_previous_line)
  " Runs 'splits' action by <C-s> and <C-v>
  imap <silent> <buffer> <expr> <C-s> unite#do_action('split')
  imap <silent> <buffer> <expr> <C-v> unite#do_action('vsplit')
  " Exit with escape
  nmap <silent> <buffer> <ESC> <Plug>(unite_exit)
  " Mark candidates
  vmap <silent> <buffer> m <Plug>(unite_toggle_mark_selected_candidates)
  nmap <silent> <buffer> m <Plug>(unite_toggle_mark_current_candidate)
endfunction

" [o]pen files recursively
nnoremap <silent> <leader>o :<C-u>Unite -no-split -buffer-name=project-files -start-insert file_rec/async:!<CR>
" search between open files - [b]uffer
nnoremap <silent> <leader>b :<C-u>Unite -no-split -buffer-name=buffers -start-insert buffer<CR>
" Search in current file tags
nnoremap <silent> <leader>t :<C-u>Unite -no-split -buffer-name=tags -start-insert outline<CR>
" Search for term in cwd file ([g]rep)
nnoremap <silent> <leader>g :<C-u>Unite -silent -auto-resize grep:.<CR>
" Search in edit [h]istory
nnoremap <silent> <leader>h :<C-u>Unite -buffer-name=edit-history -auto-resize change<CR>
" Search in [c]ommands
nnoremap <silent> <leader>c :<C-u>Unite -start-insert -auto-resize command<CR>
" Search in defined [m]appings
nnoremap <silent> <leader>m :<C-u>Unite -start-insert -auto-resize mapping<CR>
" Search in [l]ines on current buffer
nnoremap <silent> <leader>l :<C-u>Unite -no-split -buffer-name=line-search -start-insert line<CR>
" Search in [y]ank history
nnoremap <silent> <leader>y :<C-u>Unite -buffer-name=yank-history -auto-resize history/yank<CR>

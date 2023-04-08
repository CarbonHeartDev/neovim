if exists('g:loaded_hardcopy') | finish | endif

function! s:exportCurrentBufferToTempFile()
  TOhtml
  let l:tempBufferNr = bufnr("%")
  let l:exportTempFilePath = tempname()
  "https://stackoverflow.com/questions/23862961/vim-writing-to-filename-in-vimscript-variable
  execute "wq" fnameescape(l:exportTempFilePath)
  execute "bwipeout!" l:tempBufferNr
  call netrw#BrowseX(l:exportTempFilePath, 0)
endfunction
// Good job
let s:save_cpo = &cpo
set cpo&vim

command! Hardcopy call s:exportCurrentBufferToTempFile()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_hardcopy = 1

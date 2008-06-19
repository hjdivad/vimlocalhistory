function! Reload()
	if exists("g:loaded_vlh")
		unlet g:loaded_vlh
	endif
	source src/vimlocalhistory.vim
endfunction
command! Reload call Reload()

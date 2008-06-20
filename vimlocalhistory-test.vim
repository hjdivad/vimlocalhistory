function! Reload()
	if exists("g:loaded_vlh")
		unlet g:loaded_vlh
		ruby << EOS
			load 'vim_wrapper.rb'
			load 'repository.rb'
EOS
	endif
	source src/vimlocalhistory.vim
endfunction
command! Reload call Reload()

"set verbose=9
call Reload()

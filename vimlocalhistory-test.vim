function! Reload()
	if exists("g:loaded_vlh")
		unlet g:loaded_vlh
		ruby << EOS
			require 'config'
			load 'src/vlh/vim_wrapper.rb'
			load 'src/vlh/repository.rb'
EOS
	endif
	source src/vimlocalhistory.vim
endfunction
command! Reload call Reload()

"set verbose=9
call Reload()

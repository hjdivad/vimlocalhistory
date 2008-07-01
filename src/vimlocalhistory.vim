if exists('loaded_vlh')
  finish
endif
let loaded_vlh=1

ruby << EOF
	file_dir = Vim::evaluate('expand("<sfile>:h")')
	$: << file_dir unless $:.include? file_dir

	load 'vlh/vlh.rb'
EOF

if exists('loaded_vlh') || &cp
  finish
endif
let loaded_vlh=1

ruby << EOF
	load 'src/vlh.rb' if File.exists? 'src/vlh.rb'
	load 'vlh.rb' if File.exists? 'vlh.rb'
EOF

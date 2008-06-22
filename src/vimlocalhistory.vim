if exists('loaded_vlh') || &cp
  finish
endif
let loaded_vlh=1

ruby << EOF
	load 'src/vlh/vlh.rb' if File.exists? 'src/vlh/vlh.rb'
	load 'vlh/vlh.rb' if File.exists? 'vlh/vlh.rb'
EOF

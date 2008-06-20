require 'spec'
require 'rubygems'
require 'ruby-debug'

module VimLocalHistory end
module VimLocalHistory::SpecHelper

	def scp_path( path)
		host = `hostname -s`.chomp
		abs_path = File.expand_path( path)
		"scp://#{host}/#{abs_path}"
	end

	def git_rev_head( location)
		`cd #{location} && git rev-parse HEAD`
	end

	def git_revs( location, path)
		path = ".#{File.expand_path( path)}"
		`cd #{location} && git rev-list --all -- #{path}`.split("\n")
	end

	def change_file( path)
		File.open( path, 'a') do |file|
			file.puts "Another line added"
		end
	end

	# Adds stub methods to the mock Vim class so that spec doesn't complain
	# about any unexpected methods -- only appropriate for some specs
	def stub_mock_vim
		Vim.stub!(:command)
		Vim.stub!(:evaluate)
		Vim.stub!(:message)
	end
end

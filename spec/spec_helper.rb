require 'spec'

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
end

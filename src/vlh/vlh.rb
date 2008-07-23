pdir = File.dirname(__FILE__)
$: << pdir unless $:.include? pdir
$: << "#{pdir}/vlh" unless $:.include? "#{pdir}/vlh"

require 'time'

require 'vlh/vim_wrapper'
require 'vlh/repository'


module VimLocalHistory end
class VimLocalHistory::VimIntegration

	def initialize
		@repository = VimLocalHistory::Repository.new({
			:location => lambda {
				Vim::get_variable( 'g:vlh_repository_dir')
			},
			:exclude_files => lambda {
				Vim::get_variable( 'g:vlh_exclude_file_pattern')
			},
			:exclude_paths => lambda {
				Vim::get_variable( 'g:vlh_exclude_path_pattern')
			},
			:log => Vim::get_variable( 'g:vlh_log_dir')
		})

		setup_vim_event_hooks
		setup_vim_commands

	rescue => error
		report_error( error)
	end

	def setup_vim_event_hooks
		Vim::on(:BufWritePost, 'VimLocalHistory') do 
			begin
				if @repository.enabled?
					@repository.commit_file( Vim::Buffer.current.name)
				elsif not @repository.location.empty?
					# g:vlh_repository_dir was set, but we can't write to it
					print "VimLocalHisotry -- Unable to write to
						g:vlh_repository_dir (the repository location) --
						'#{@repository.location}'".compact!
				end
			rescue => e
				# UnimplementedFeatureError for scp://* files will generate a
				# message here, but won't actually be shown to the user because
				# netrw invokes doau BufWritePost silently
				print "#{e.class.name}: #{e.message}"
			end
		end
	end

	def setup_vim_commands
		options = {
			:arity => 1,
			:completion => lambda {
				@repository.revision_information(
					Vim::Buffer.current.name,
					%w(ad s)
				).map_with_index! do |entry, idx|
					# Create newline separated entries that look like
					#  1 # previous		    7 Jan 2008 imagine a log entry here
					#  ...
					# 17 # 17 versions ago 14 Jul 2007 more log entries
					"%2d # %-15.15s %11.11s %s" % [
						idx+1, 
						case idx
							when 0
								'previous'
							else
								"#{idx+1} versions ago"
							end,
						Time.parse( entry[:ad]).strftime( '%d %b %Y'),
						entry[ :s],
					]
				end.join("\n")
			},
		}

		Vim::create_command(:VLHDiff, options) do |arg|
			revision = arg.to_i
			path = @repository.checkout_file(Vim::Buffer.current.name, revision)
			Vim::diffsplit( path, :vertical => true)
			#TODO: these are probably not very generic -- i.e., they may not
			# work well in cases where the current tab already has more than one
			# window open
			Vim::command("wincmd R")
			Vim::command("wincmd h")
		end

		#FIXME: this leaks tempfiles
		#	it would be good to clean them up either on bufclose
		#	or on vim exit
		Vim::create_command(:VLHOpen, options) do |arg|
			revision = arg.to_i
			path = @repository.checkout_file(Vim::Buffer.current.name, revision)
			Vim::edit_file( path)
		end

		Vim::create_command(:VLHReplace, options) do |arg|
			revision = arg.to_i
			@repository.revert_file( Vim::Buffer.current.name, revision)
			Vim::set_option( 'nomodified')
			Vim::edit_file( Vim::Buffer.current.name)
		end
	end


	# Not a finalizer because we don't want to wait for the GC to call this
	def free_resources
		unset_vim_event_hooks
	end

	def unset_vim_event_hooks
		Vim::clear_event_handlers_by_group( 'VimLocalHistory')
	end

	def report_error( e)
		lines = ["#{e.class.name}: #{e.message}"] + e.backtrace
		lines.each{|line| Vim::message( line) }
	end

end

# Normally VLH should not already be defined, but it is during testing, and it's
# possible for the file to be manually re-sourced
VLH.free_resources if defined? VLH
VLH = VimLocalHistory::VimIntegration.new


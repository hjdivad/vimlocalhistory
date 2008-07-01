pdir = File.dirname(__FILE__)
$: << pdir unless $:.include? pdir
$: << "#{pdir}/vlh" unless $:.include? "#{pdir}/vlh"

require 'vlh/vim_wrapper'
require 'vlh/repository'



#TODO: expose command History -> VLH::show_history
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
		#TODO: impl
	end


	# Not a finalizer because we don't want to wait for the GC to call this
	def free_resources
		unset_vim_event_hooks
	end

	def unset_vim_event_hooks
		Vim::clear_event_handlers_by_group( 'VimLocalHistory')
	end

end

# Normally VLH should not already be defined, but it is during testing, and it's
# possible for the file to be manually re-sourced
VLH.free_resources if defined? VLH
VLH = VimLocalHistory::VimIntegration.new


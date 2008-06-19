pdir = File.dirname(__FILE__)
$: << pdir unless $:.include? pdir

require 'vim_wrapper'
require 'repository'



#TODO: on bufwrite VLH::commit_buffer
#expose command History -> VLH::show_history
module VimLocalHistory end
class VimLocalHistory::VimIntegration

	def initialize
		path = Vim::get_variable( 'g:vlh_repository_dir')
		@repository = VimLocalHistory::Repository.new( path)

		setup_vim_event_hooks
		setup_vim_commands
	end

	def setup_vim_event_hooks
		#TODO: impl
		#TODO: if g:vlh_repository_dir changes, update @repository
	end

	def setup_vim_commands
		#TODO: impl
	end
end

VLH = VimLocalHistory::VimIntegration.new


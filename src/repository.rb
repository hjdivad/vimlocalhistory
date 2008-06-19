require 'fileutils'

require 'errors'

module VimLocalHistory end
class VimLocalHistory::Repository

	attr_reader :location


	def initialize( location)
		@location = location
	end

	def enabled?
		@enabled = check_enabled if @enabled.nil?
		@enabled
	end

	def initialized?
		return false unless enabled?
		File.exists? "#{@location}/.git"
	end


	def commit_file( path)
		ensure_repository_initialized
		copy_file_to_repository( path)
		git_add_and_commit_all
	end


	private

	def check_enabled
		File.exists?( @location) and
			File.new( @location).stat.writable?
	end

	def ensure_repository_initialized
		raise CannotInitializeRepositoryError.new(
			"#{@location} does not exist or is not writable"
		) unless enabled?

		initialize_repository unless initialized?
	end

	def initialize_repository
		system "cd #{@location} && touch .gitignore && git-init > /dev/null "
		git_add_and_commit_all(
			"Initial commit from VimLocalHistory"
		)
	end

	def copy_file_to_repository( path)
		if path.starts_with? 'scp://'
			copy_scp_path_to_repository( path)
		else
			copy_local_file_to_repository(
				File.expand_path( path)
			)
		end
	end

	def copy_local_file_to_repository( path)
		repo_dir = File.dirname("#{@location}/#{path}")

		FileUtils.mkdir_p repo_dir
		FileUtils.cp path, repo_dir
	end

	def copy_scp_path_to_repository( path)
		raise UnimplementedFeatureError
	end


	def git_add_and_commit_all( msg="Commit from VimLocalHistory")
		#FIXME: quotesafe message
		#FIXME: error if msg nil or empty
		system "cd #{@location} && 
				git add * &&  
				git commit --all -m \"#{msg}\" \
					> /dev/null"
	end
end

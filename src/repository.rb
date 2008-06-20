require 'fileutils'

require 'lang_utils'
require 'errors'

module VimLocalHistory end
class VimLocalHistory::Repository


	def initialize( location=nil, &block)
		if block_given? and not location
			@location_proc = Proc.new &block
		elsif location
			@location_proc = Proc.new { location }
		else
			raise ArgumentError.new(
				"Either a location must be specified, or a block that returns
				the location must be given".compact!
			)
		end
	end

	def enabled?
		check_enabled
	end


	def commit_file( path)
		ensure_repository_initialized
		copy_file_to_repository( path)
		git_add_and_commit_all
	end



	def location
		loc = @location_proc.call
		if block_given?
			yield loc
		else
			loc
		end
	end


	private

	def initialized?
		return false unless enabled?
		File.exists? "#{location}/.git"
	end

	def check_enabled
		location do |loc|
			File.exists?( loc) and
				File.new( loc).stat.writable?
		end
	end

	def ensure_repository_initialized
		raise CannotInitializeRepositoryError.new(
			"#{location} does not exist or is not writable"
		) unless enabled?

		initialize_repository unless initialized?
	end

	def initialize_repository
		system "cd #{location} && touch .gitignore && git-init > /dev/null "
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
		repo_dir = File.dirname("#{location}/#{path}")

		FileUtils.mkdir_p repo_dir
		FileUtils.cp path, repo_dir
	end

	def copy_scp_path_to_repository( path)
		raise UnimplementedFeatureError
	end


	def git_add_and_commit_all( msg="Commit from VimLocalHistory")
		#FIXME: quotesafe message
		#FIXME: error if msg nil or empty
		system "cd #{location} && 
				git add * &&  
				git commit --all -m \"#{msg}\" \
					> /dev/null"
	end
end

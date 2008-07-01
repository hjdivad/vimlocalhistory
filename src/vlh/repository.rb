require 'fileutils'
require 'logger'

require 'vlh/lang_utils'
require 'vlh/errors'

module VimLocalHistory end
class VimLocalHistory::Repository


	def initialize( options={})
		options = { :location => options} if options.is_a? String
		options.assert_valid_keys(
			:location, :exclude_paths, :exclude_files, :log
		)


		initialize_log options[ :log]
		initialize_location options[ :location]
		initialize_exclusion_patterns(
			options[ :exclude_paths], 
			options[ :exclude_files]
		)
	end

	def initialize_location( location=nil)
		if location.is_a? String
			path = File.expand_path( location) if 
				location and location.strip.size > 0
			location = Proc.new { path }
		end
		@location_proc = location
	end

	def initialize_exclusion_patterns( exclude_paths, exclude_files)
		exclude_paths_proc = 
			case exclude_paths
			when String
				Proc.new { exclude_paths }
			when Proc
				exclude_paths
			else
				raise ArgumentError.new(
					"exclude_paths must be a String or Proc, not a
					#{exclude_paths.class.name}".compact!
				)
			end if exclude_paths

		exclude_files_proc =
			case exclude_files
			when String
				Proc.new { exclude_files }
			when Proc
				exclude_files
			else
				raise ArgumentError.new(
					"exclude_files must be a String or Proc, not a
					#{exclude_files.class.name}".compact!
				)
			end if exclude_files

		@user_exclude_paths_proc = Proc.new {
			string = exclude_paths_proc.call if exclude_paths_proc
			Regexp.new( string) if string and not string.empty?
		}
		@user_exclude_files_proc = Proc.new {
			string = exclude_files_proc.call if exclude_files_proc
			Regexp.new( string) if string and not string.empty?
		}
	end

	def initialize_log( path)
		if path
			FileUtils.mkdir_p path
			@log = Logger.new( "#{path}/vlh.log", 10, 1.megabyte)
		else
			class << (@log = Object.new)
				def debug(*args); end
			end
		end
	end


	def enabled?
		check_enabled
	end


	def commit_file( path)
		@log.debug "Asked to commit #{path}"
		if path_excluded? path
			@log.debug "Excluded path #{path}"
			return
		end

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
			loc and
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


	def path_excluded?( path)
		@@implicit_exclusion_pattern ||= (
			/^.git$/ |
			/^.git\// |

			/\/.git$/ |
			/\/.git\//
		)
		user_exclude_paths = @user_exclude_paths_proc.call
		user_exclude_files = @user_exclude_files_proc.call
		
		file = path.chomps("#{File.dirname(path)}/")

		path =~ @@implicit_exclusion_pattern or
			(user_exclude_paths and path =~ user_exclude_paths) or
			(user_exclude_files and file =~ user_exclude_files)
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

require 'fileutils'
require 'logger'
require 'tempfile'

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
		if path and not path.empty?
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

	def revision_information( path, options=[])
		return [] unless path

		path = repo_relative_path( path)
		return [] unless File.exists?(
			"#{location}/#{path}"
		)

		format = options.map{|o| "%#{o}"}.join('%n')
		output = `cd #{location} &&
			git rev-list -n 10 --pretty=format:"#{format}" HEAD #{path}`

		rv = []
		output.split("\n").each_n( options.size + 1) do |commit, *lines|
			rv << entry = {}
			# this line looks like
			# 	commit	abcd1234efgh5678
			entry[:commit] = commit.chomps('commit').strip
			lines.each_with_index do |line, idx|
				entry[ options[ idx]] = line
			end

			entry.symbolize_keys!
		end

		rv
	end

	def checkout_file( path, revision)
		with_path_and_revisions(path) do |path, revs|
			return nil unless (0..(revs.size)).include? revision

			temp_path = Tempfile.new('vlh-checkout').path
			run [
				cmd_cd,
				cmd_git_show( revs[revision], path, temp_path)
			]

			temp_path
		end
	end

	def revert_file( path, revision)
		return false if 0 == revision or not path

		with_path_and_revisions(path) do |repo_path, revs|
			raise ArgumentError.new("
				Unable to revert to revision #{revision} - only #{revs.size}
				revisions are available.
			".compact!) unless (1..(revs.size)).include? revision

			run [
				cmd_cd,
				cmd_git_checkout( revs[revision], repo_path),
				cmd_git_commit_all(
					"Reverted to #{revision.position} prior commit")
			]

			FileUtils.cp "#{location}/#{repo_path}", path
			true
		end or false
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

		# set the file owner equal to the owner of +location+ -- this way copies
		# of files sudo'd are owned by the user (so, e.g. `git gc` won't fail)
		stat = File.stat location
		file = path[File.dirname(path).size+1..-1]

		File.chown stat.uid, stat.gid, "#{repo_dir}/#{file}"

		# mkdir_p, above, may have created new directories while sudo'd, so we
		# need to chown those directories as well.  This may need to get changed
		# if it's too slow in the common case, but File.chmod_r may be too slow
		# for large pre-existing trees that already have files.
		path_array = path.chomps(File::SEPARATOR).split( File::SEPARATOR)
		while not path_array.empty?
			dir = "#{location}/#{File.join( path_array)}"
			File.chown stat.uid, stat.gid, dir
			File.chmod 0o700, dir
			path_array.pop
		end

		# Because we may have sudo vim'd a file, we'll want to chmod 600 the
		# copy, although this is really rather paranoid as the user shouldn't be
		# exposing their repo directory anyway.
		File.chmod 0o600, "#{repo_dir}/#{file}"
	end

	def copy_scp_path_to_repository( path)
		raise UnimplementedFeatureError
	end


	def run( cmds)
		cmdline = cmds.join(' && ')
		succ = system( cmdline)

		@log.debug("Error running commands:\n#{cmdline}") unless succ

		succ
	end

	def cmd_cd
		"cd #{location}"
	end

	def cmd_git_add_all
		"git add -f *"
	end

	def cmd_git_show( commit, path, send_to=nil)
		"git show #{commit}:#{path} #{"> #{send_to}" if send_to}"
	end

	def cmd_git_checkout( commit, path)
		"git checkout #{commit} -- #{path}"
	end

	def cmd_git_commit_all( msg)
		#FIXME: quotesafe message
		#FIXME: error if msg nil or empty
		"git commit --all -m \"#{msg}\" > /dev/null"
	end

	def git_add_and_commit_all( msg="Commit from VimLocalHistory")
		run [ 
			cmd_cd,
			cmd_git_add_all,
			cmd_git_commit_all( msg)
		]
	end


	def repo_relative_path( path)
		File.expand_path(path).chomps('/')
	end

	def with_path_and_revisions( path)
		return nil unless path

		path = repo_relative_path( path)
		return nil unless File.exists? "#{location}/#{path}"

		revs = `cd #{location} && git rev-list HEAD #{path}`.split("\n")
		yield path, revs
	end
end

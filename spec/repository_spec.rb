
require 'fileutils'
require 'tempfile'

require 'spec/spec_helper'

require 'vlh/repository'
require 'vlh/lang_utils'
require 'vlh/errors'


describe VimLocalHistory::Repository do
	include VimLocalHistory::SpecHelper


	before(:each) do
		FileUtils.rm_r ['./test/without-repo', './test/with-repo'], 
						:force => true
		FileUtils.mkdir_p ['./test/without-repo', './test/with-repo']
		
		system 'cd test/with-repo && touch .gitignore && 
				git-init > /dev/null && git add .gitignore && 
				git commit --all -m "Initial Commit" > /dev/null'
	end


	describe "(with g:vlh_repository_dir set to a relative path)" do
		before(:each) do
			@repo = VimLocalHistory::Repository.new 'test/with-repo'
		end


		it "should not consider the repository location changed after the pwd
		changes".compact! do
			pwd = FileUtils.pwd
			begin
				FileUtils.cd 'test'
				File.expand_path( @repo.location).should ==
					File.expand_path( './with-repo')
			ensure
				# revert back to previous path
				FileUtils.cd pwd
			end
		end
	end


	describe "(with g:vlh_repository_dir unset)" do
		before(:each) do
			@repo = VimLocalHistory::Repository.new ''
		end


		it "should not be enabled" do
			@repo.should_not be_enabled
		end
	end


	describe "
		(with g:vlh_repository_dir set to an illegal path or unwritable
		directory)
	".compact! do
		before(:each) do
			File.should_not be_exist('./notarealpath')
			@repo = VimLocalHistory::Repository.new './notarealpath'
		end


		it "should not be enabled" do
			@repo.should_not be_enabled
		end

		it "should raise an error when asked to commit a file" do
			lambda{ @repo.commit_file('./spec/assets/sample_file.txt') }.
				should raise_error(CannotInitializeRepositoryError)
		end
	end


	shared_examples_for "with a valid g:vlh_repository_dir" do
		before(:each) do
			@temp = Tempfile.new('vlh-spec').path
			FileUtils.cp './spec/assets/sample_file.txt', @temp
		end

		after(:each) do
			FileUtils.cp @temp, './spec/assets/sample_file.txt'
		end


		it "should be enabled" do
			@repo.should be_enabled
		end

		it "should have one commit entry for a new file, after being asked to
		commit that file".compact! do
			@repo.commit_file './spec/assets/sample_file.txt'

			git_revs( @repo.location, './spec/assets/sample_file.txt').
				should have_exactly(1).commits
		end

		it "should treat paths with . and .. as referring to the same file as if
		the path were realpath stripped".compact! do

			@repo.commit_file './spec/assets/sample_file.txt'
			change_file './spec/assets/sample_file.txt'
			@repo.commit_file './spec/assets/../../spec/assets/./sample_file.txt'

			git_revs( @repo.location, './spec/assets/sample_file.txt').
				should have_exactly(2).commits
		end

		it "should treat a path symlinked to some other path as separate 
		paths".compact! do
			@repo.commit_file './spec/assets/sample_file.txt'
			change_file './spec/assets/sample_file.txt'
			@repo.commit_file './spec/assets/sample_file_symlink'

			git_revs( @repo.location, './spec/assets/sample_file.txt').
				should have_exactly(1).commits
			git_revs( @repo.location, './spec/assets/sample_file_symlink').
				should have_exactly(1).commits
		end

		it "should commit symlinks as regular files" do
			@repo.commit_file './spec/assets/sample_file_symlink'

			path = File.expand_path('./spec/assets/sample_file_symlink')
			File.lstat("#{@repo.location}/#{path}").
				should_not be_symlink
		end

		it "should store absolute paths rooted at the repository location" do
			FileUtils.cp './spec/assets/sample_file.txt', '/tmp/sample_file.txt'
			@repo.commit_file '/tmp/sample_file.txt'
			
			git_revs( @repo.location, '/tmp/sample_file.txt').
				should have_exactly(1).commits
		end

		it "should store relative paths rooted at the repository location from
		their absolute path (i.e. saving ./foo should be the same as saving
		realpath ./foo)".compact! do
			@repo.commit_file './spec/assets/sample_file.txt'

			git_revs( 
				@repo.location, 
				File.expand_path('./spec/assets/sample_file.txt')
			).should have_exactly(1).commits
		end

		it "should raise Errno::ENOENT if asked to commit non-existant
		paths".compact! do
			File.should_not be_exist('/tmp/fakepath')
			lambda { 
				@repo.commit_file('/tmp/fakepath')
			}.should raise_error(Errno::ENOENT)
		end

		it "should ensure the saved copies of committed files have the same
		ownership as the repo location (sudo this spec to test)".compact! do
			# Make sure that the location isn't also owned by root, or the test
			# will be somewhat pointless
			stat_pwd = File.stat FileUtils.pwd
			File.chown stat_pwd.uid, stat_pwd.gid, @repo.location

			@repo.commit_file './spec/assets/sample_file.txt'

			stat_repo = File.stat @repo.location
			stat_file = File.stat(
				"#{@repo.location}/#{FileUtils.pwd}/spec/assets/sample_file.txt"
			)

			stat_file.uid.should == stat_repo.uid
			stat_file.gid.should == stat_repo.gid
		end

		it "should warn about an unimplemented feature if asked to commit an
		scp'd file".compact! do
			path = scp_path './spec/assets/sample_file.txt'

			lambda{ 
				@repo.commit_file path
			}.should raise_error( UnimplementedFeatureError)
		end


		########################################################################
		# Exclusion patterns
		describe "(in handling paths matching .git)" do
			before(:each) do
				# ensure the repository is actually initialized by comitting a dummy
				# file
				@repo.commit_file 'spec/assets/sample_file.txt'
				@starting_rev = git_rev_head( @repo.location)
				@starting_pwd = FileUtils.pwd


				FileUtils.mkdir_p 'spec/assets/.git'
				FileUtils.cp 'spec/assets/sample_file.txt', 'spec/assets/.git/'
			end

			after(:each) do
				FileUtils.cd @starting_pwd
				FileUtils.rm_r 'spec/assets/.git', :force => true
			end


			describe "(paths that should be silently ignored)" do
				before(:each) do
					class << @repo
						def git_add_and_commit_all
							raise "git commit should not have been called for a path
							matching .git".compact!
						end
					end
				end

				it "should silently exclude paths that match ^.git/  (i.e., nothing
				should happen after being asked to commit such a path)".compact! do

					FileUtils.cd 'spec/assets'

					@repo.commit_file '.git/sample_file.txt'

					git_rev_head( @repo.location).should == @starting_rev
				end

				it "should silently exclude paths that match /.git/  (i.e., nothing
				should happen after being asked to commit such a path)".compact! do

					@repo.commit_file 'spec/assets/.git/sample_file.txt'
					git_rev_head( @repo.location).should == @starting_rev
				end
			end


			it "should not silently ignore /foo.git/some_file" do
				@repo.commit_file 'spec/assets/foo.git/sample_file.txt'

				git_revs( 
					@repo.location, 
					'./spec/assets/foo.git/sample_file.txt'
				).should have_exactly(1).commits
			end
			
			it "should not silently ignore /.gitfoo/some_file" do
				@repo.commit_file 'spec/assets/.gitfoo/sample_file.txt'

				git_revs( 
					@repo.location, 
					'./spec/assets/.gitfoo/sample_file.txt'
				).should have_exactly(1).commits
			end

			it "should not silently ignore ^.gitfoo/some_file" do
				FileUtils.cd 'spec/assets'

				@repo.commit_file '.gitfoo/sample_file.txt'

				git_revs( 
					@repo.location, 
					'.gitfoo/sample_file.txt'
				).should have_exactly(1).commits
			end

			it "should not silently ignore /foo/bar even if there's a saved
			/foo/.gitignore with a pattern that matches bar".compact! do
				FileUtils.cp 'spec/assets/sample_file.txt', 'spec/assets/foo'

				@repo.commit_file 'spec/assets/foo/.gitignore'
				@repo.commit_file 'spec/assets/foo/sample_file.txt'

				git_revs( 
					@repo.location, 
					'spec/assets/foo/sample_file.txt'
				).should have_exactly(1).commits

				FileUtils.rm 'spec/assets/foo/sample_file.txt'
			end
		end

		########################################################################
	end

	########################################################################
	# Exclusion patterns
	shared_examples_for "a repository initialized with exclusion patterns" do
		describe "(when given a user-specified file exclusion pattern)" do
			before(:each) do
				@repo = VimLocalHistory::Repository.new({
					:location => './test/with-repo',
					:exclude_files => '.*\.ignore'
				})
				@starting_rev = git_rev_head( @repo.location)
			end


			it "should complain if the pattern is not a valid ruby regex string" do
				lambda {
					repo = VimLocalHistory::Repository.new({
						:location => './test/with-repo',
						:exclude_files => '(foo'
					})

					repo.commit_file 'spec/assets/sample_file.txt'
				}.should raise_error( RegexpError)
			end

			it "should not commit paths whose file part match the pattern" do
				@repo.commit_file 'spec/assets/sample_file.ignore'
				git_rev_head( @repo.location).should == @starting_rev
			end

			it "should commit paths that match the pattern, as long as their
			file part does not".compact! do
				path = 'spec/assets/dont.ignore/sample_file.txt'
				regexp = Regexp.new('.*\.ignore')
				path.should =~ regexp

				@repo.commit_file  path
				git_revs( 
					@repo.location, path
				).should have_exactly(1).commits
			end
		end


		describe "(when given a user-specified path exclusion pattern)" do
			before(:each) do
				@repo = VimLocalHistory::Repository.new({
					:location => './test/with-repo',
					:exclude_paths => '.ignore\/'
				})
				@starting_rev = git_rev_head( @repo.location)
			end


			it "should complain if the pattern is not a valid ruby regex
			string".compact! do
				lambda {
					repo = VimLocalHistory::Repository.new({
						:location => './test/with-repo',
						:exclude_paths => '(foo'
					})

					repo.commit_file 'spec/assets/sample_file.txt'
				}.should raise_error( RegexpError)
			end

			it "should not commit paths that match the pattern" do
				@repo.commit_file 'spec/asset/ignore/sample_file.txt'
				git_rev_head( @repo.location).should == @starting_rev
			end
		end
	end
	########################################################################



	describe "
		(with g:vlh_repository_dir set to a path with no initialized git
		repository)
	".compact! do
		before(:each) do
			File.should be_exist('./test/without-repo')
			File.should_not be_exist('./test/without-repo/.git')
			@repo = VimLocalHistory::Repository.new './test/without-repo'
		end


		it_should_behave_like "with a valid g:vlh_repository_dir"


		it "should initialize the git repository when first asked to commit a
		file".compact! do 
			@repo.commit_file('./spec/assets/sample_file.txt')
			File.should be_exist('./test/without-repo/.git')
		end
	end


	describe "
		(with g:vlh_repository_dir set to a path with and initialized git
		repository)
	".compact! do
		before(:each) do
			File.should be_exist('./test/with-repo')
			File.should be_exist('./test/with-repo/.git')
			@repo = VimLocalHistory::Repository.new './test/with-repo'
		end


		it_should_behave_like "with a valid g:vlh_repository_dir"

		it "should not change the repository when asked to commit an scp'd
		file".compact! do
			starting_rev = git_rev_head( @repo.location)
			path = scp_path './spec/assets/sample_file.txt'

			begin
				@repo.commit_file path
			rescue => error
				git_rev_head( @repo.location).should == starting_rev	
			end
		end
	end


	describe "
		(with path and file exclusion patterns)
	".compact! do

		it_should_behave_like "a repository initialized with exclusion patterns"


		it "should accept a constructor with only a path-exclusion pattern
		(string)".compact! do
			lambda {
				VimLocalHistory::Repository.new({
					:location => './test/with-repo',
					:exclude_paths => 'foo'
				})
			}.should_not raise_error
		end

		it "should accept a constructor with only a file-exclusion pattern
		(string and Regexp)".compact! do
			lambda {
				VimLocalHistory::Repository.new({
					:location => './test/with-repo',
					:exclude_files => 'foo'
				})
			}.should_not raise_error
		end

		it "should accept procs for path exclusion patterns" do
			lambda {
				VimLocalHistory::Repository.new({
					:exclude_files => lambda { 'hi' }
				})
			}.should_not raise_error
		end

		it "should ignore empty path exclusion patterns" do
			repo = VimLocalHistory::Repository.new({
				:location => './test/with-repo',
				:exclude_paths => ''
			})

			starting_rev = git_rev_head( repo.location)
			repo.commit_file 'spec/assets/sample_file.txt'
			git_rev_head( repo.location).should_not == starting_rev
		end

		it "should ignore empty file exclusion patterns" do
			repo = VimLocalHistory::Repository.new({
				:location => './test/with-repo',
				:exclude_files => ''
			})

			starting_rev = git_rev_head( repo.location)
			repo.commit_file 'spec/assets/sample_file.txt'
			git_rev_head( repo.location).should_not == starting_rev
		end
	end

	describe "(with path and file exclusion patterns)" do
		before(:each) do
			File.should be_exist('./test/without-repo')
			File.should_not be_exist('./test/without-repo/.git')
			@repo = VimLocalHistory::Repository.new({
				:location => './test/without-repo',
				:exclude_files => 'ignoreme',
				:exclude_paths => '\/ignoreme\/',
			})
		end

		it_should_behave_like "with a valid g:vlh_repository_dir"
	end


	describe "(logging)" do
		it "should create the directory path if it does not already exist" do
			FileUtils.rm_r './test/log', :force => true if
				File.exists? './test/log'
			VimLocalHistory::Repository.new({
				:location => './test/with-repo',
				:log => './test/log',
			})
			
			File.should be_exist( './test/log/vlh.log')
		end
	end
	describe "(when passed a log option)" do
		before(:each) do
			FileUtils.rm './test/log/vlh.log', :force => true
			@repo = VimLocalHistory::Repository.new({
				:location => './test/with-repo',
				:exclude_files => '\.*\.ignore$',
				:log => './test/log',
			})
		end

		it "should log calls to commit" do
			@repo.commit_file 'spec/assets/sample_file.txt'
			File.read('./test/log/vlh.log').should =~
				/Asked to commit spec\/assets\/sample_file.txt/i
		end

		it "should log when paths are excluded by patterns" do
			@repo.commit_file 'spec/assets/sample_file.ignore'
			File.read('./test/log/vlh.log').should =~
				/Excluded path spec\/assets\/sample_file\.ignore/i
		end
	end


	describe "(accessing the repository)" do
		before(:each) do
			@repo = VimLocalHistory::Repository.new({
				:location => './test/with-repo',
				:log => './test/log',
			})
			@temp = Tempfile.new('vlh-spec').path
			FileUtils.cp './spec/assets/sample_file.txt', @temp

			# Revisions are written in reverse -- we're thinking of revision
			# here as relative to the current file, with rev 0 being the current
			# version, rev 1 being the prior version, etc.
			(0..3).to_a.reverse.each do |rev|
				File.open('spec/assets/sample_file.txt','w') do |f|
					f.write("revision #{rev}")
				end
				@repo.commit_file 'spec/assets/sample_file.txt'
			end
		end

		after(:each) do
			FileUtils.cp @temp, './spec/assets/sample_file.txt'
		end


		describe "checkout_file" do
			it "should checkout the expected revision to a temp file (for
			revision 1)".compact! do
				path = @repo.checkout_file('spec/assets/sample_file.txt', 1)

				File.should be_exist( path)
				File.read(path).should == 'revision 1'
			end

			it "should checkout the expected revision to a temp file (for
			revision 3)".compact! do
				path = @repo.checkout_file('spec/assets/sample_file.txt', 3)

				File.should be_exist( path)
				File.read(path).should == 'revision 3'
			end

			it "should return nil for revisions < 0" do
				path = @repo.checkout_file('spec/assets/sample_file.txt', -1)

				path.should be_equal(nil)
			end

			it "should return nil for revisions > the maximum number of
			revisions for the file".compact! do
				path = @repo.checkout_file('spec/assets/sample_file.txt', 7)

				path.should be_equal(nil)
			end

			it "should return nil for nil paths" do
				path = @repo.checkout_file(nil, 7)

				path.should be_equal(nil)
			end

			it "should return nil for paths never committed" do
				path = @repo.checkout_file('not/a/real/path', 0)

				path.should be_equal(nil)
			end
		end

		describe "revert_file" do
			it "should revert the file so that it matches its state at the
			expected revision, and commit these changes (for revision
			1) and return true".compact! do
				rv = @repo.revert_file( 'spec/assets/sample_file.txt', 1)

				rv.should be_equal(true)
				File.read('spec/assets/sample_file.txt').should == 'revision 1'
				
				git_revs( @repo.location, './spec/assets/sample_file.txt').
					should have_exactly(5).commits
			end

			it "should revert the file so that it matches its state at the
			expected revision, and commit these changes (for revision
			3) and return true".compact! do
				rv = @repo.revert_file( 'spec/assets/sample_file.txt', 3)

				rv.should be_equal(true)
				File.read('spec/assets/sample_file.txt').should == 'revision 3'

				git_revs( @repo.location, './spec/assets/sample_file.txt').
					should have_exactly(5).commits
			end

			it "should do nothing for revision = 0, but raise no error (and
			return false)".compact! do
				rv = @repo.revert_file( 'spec/assets/sample_file.txt', 0)

				rv.should be_equal(false)
				File.read('spec/assets/sample_file.txt').should == 'revision 0'

				git_revs( @repo.location, './spec/assets/sample_file.txt').
					should have_exactly(4).commits
			end

			it "should do nothing for nil paths, but raise no error (and return
			false)".compact! do
				rv = @repo.revert_file( nil, 3)

				rv.should be_equal(false)
				File.read('spec/assets/sample_file.txt').should == 'revision 0'

				git_revs( @repo.location, './spec/assets/sample_file.txt').
					should have_exactly(4).commits
			end

			it "should do nothing for paths never committed, but raise no error
			(and return false)".compact! do
				rv = @repo.revert_file( 'not/a/real/path', 1)

				rv.should be_equal(false)
				File.read('spec/assets/sample_file.txt').should == 'revision 0'

				git_revs( @repo.location, './spec/assets/sample_file.txt').
					should have_exactly(4).commits
			end

			it "should raise an ArgumentError for revisions < 0" do
				lambda {
					@repo.revert_file('spec/assets/sample_file.txt', -1)
				}.should raise_error( ArgumentError)
			end

			it "should raise an error for revisions > the maximum number of
			revisions for this file".compact! do
				lambda {
					@repo.revert_file('spec/assets/sample_file.txt', 7)
				}.should raise_error( ArgumentError)
			end
		end

		describe "revisions_information" do
			it "should consider each option a format placeholder for git
			rev-list, and return the information as a hash, along with the
			implied key :commit".compact! do
				rev_info = @repo.revision_information( 
					'spec/assets/sample_file.txt', 
					%w(s)
				)
			
				rev_info.size.should == 4

				rev_info.each do |entry|
					entry.should have_keys(:commit, :s)
					entry[:commit].should =~ /[a-z0-9]{40}/i
					entry[:s].should == 'Commit from VimLocalHistory'
				end
			end
			
			it "should return an empty array for nil paths" do
				@repo.revision_information(nil, %w(s)).should == []
			end

			it "should return an empty array for paths that were never
			committed".compact! do
				@repo.revision_information('not/real/path', %w(s)).should == []
			end
		end
	end


	describe "(options hash)" do
		it "should accept keys :location, :exclude_paths, :exclude_files and
		:log".compact! do
			lambda {
				VimLocalHistory::Repository.new({
					:location => 'foo',
					:exclude_paths => 'foo',
					:exclude_files => 'foo',

					:log => 'test/log',
				})
			}.should_not raise_error
		end

		it "should not accept illegal keys (e.g., :test, :foo)" do
			lambda {
				VimLocalHistory::Repository.new({
					:location => 'foo',
					:exclude_paths => 'foo',

					:foo => 'foo',
					:test => 'foo'
				})
			}.should raise_error(ArgumentError)
		end
	end
end

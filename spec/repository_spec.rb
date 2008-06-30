
require 'fileutils'

require 'spec/spec_helper'

require 'repository'
require 'lang_utils'
require 'errors'


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
		end


		#TODO: user-supplied exclusion patterns (file & path)

		########################################################################
	end

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
end

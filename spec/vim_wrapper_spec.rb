require 'spec/spec_helper'

require 'vlh/lang_utils'


describe 'Vim Wrapper' do
	include VimLocalHistory::SpecHelper

	before(:all) do
		Vim = mock("VIM")

		# We create a no-op method command so that initialization is expected,
		# and we immediately destroy it after loading vlh/vim_wrapper.rb so that
		# calls to command will still be caught by rspec for use with
		# expectations.
		#
		# vim_wrapper is loaded this way (as opposed to with require at the top
		# of the file) to ensure that the constant Vim is created as a mock
		# object.
		class << Vim
			def command(*args); end
		end
		load 'vlh/vim_wrapper.rb'

		class << Vim
			remove_method :command

			# We define callbacks here to ensure that method invocations are
			# expected
			alias_method :real_event_callbacks, :event_callbacks
			def event_callbacks
				real_event_callbacks
			end

			alias_method :real_command_callbacks, :command_callbacks
			def command_callbacks
				real_command_callbacks
			end
		end
	end

	before(:each) do
		Vim::event_callbacks.clear
		Vim::command_callbacks.clear
	end


	describe 'Event Handling' do
		it "should have a proc entry in the event_callbacks table for an
		event,group pair, after on is called with that pair and a block.
		Furthermore, :command should have been called (in setting up the event
		handlers)".compact! do
			Vim::should_receive(:command).
				with( an_instance_of(String)).
				at_least(:once)

			Vim::on(:BufWrite, 'MyGroup'){}

			callbacks = Vim::event_callbacks
			callbacks.should have_key(:BufWrite)
			callbacks[:BufWrite].should have_key(:MyGroup)
			callbacks[:BufWrite][:MyGroup].should_not be_empty
			callbacks[:BufWrite][:MyGroup].first.should be_an_instance_of(Proc)
		end

		it "should invoke the block passed into Vim::on when the callback is
		called with the same event and group, and the proc_id passed to
		:command".  compact! do
			proc_id = nil
			@block_called = false

			Vim::should_receive(:command) { |string|
				proc_id = $1 if string =~ /(\d{4,})/
			}.with( an_instance_of(String)).at_least(:once)

			Vim::on(:BufWrite, 'MyGroup'){ @block_called = true}
			proc_id.should_not be_nil

			Vim::event_callback( :BufWrite, 'MyGroup', proc_id)
			@block_called.should == true
		end

		it "should not invoke blocks with the wrong proc_id on callback, even if
		the callback event,group pair matches the one used to add the block".
		compact! do
			stub_mock_vim
			proc_id = nil
			@b1_called, @b2_called = [false, false]

			Vim::should_receive(:command) { |string|
				proc_id ||= $1 if string =~ /(\d{4,})/
			}.with( an_instance_of(String)).at_least(:once)


			Vim::on(:BufWrite, 'MyGroup'){@b1_called = true}
			proc_id.should_not be_nil

			Vim::on(:BufWrite, 'MyGroup'){@b2_called = true}

			Vim::event_callback( :BufWrite, 'MyGroup', proc_id)
			@b2_called.should == false
		end


		describe 'clear_by_group' do
			it "should be invoking Vim::command and not Vim::evaluate" do
				Vim::should_receive(:command)
				Vim::should_not_receive(:evaluate)
				Vim::clear_event_handlers_by_group 'MyGroup'
			end

			it "should clear all the event_callbacks for the group in all
			events".compact! do
				stub_mock_vim

				Vim::on(:BufWrite, 'MyGroup'){}
				Vim::on(:BufWrite, 'MyGroup'){}
				Vim::on(:BufRead, 'MyGroup'){}
				Vim::on(:FileRead, 'MyGroup'){}

				proc_table = Vim::event_callbacks.
								values.map{|h| h.values}.flatten
				proc_table.should have(4).procs

				Vim::clear_event_handlers_by_group 'MyGroup'

				proc_table = Vim::event_callbacks.
								values.map{|h| h.values}.flatten
				proc_table.should be_empty
			end

			it "should not clear any event_callbacks for other groups in any
			events".compact! do
				stub_mock_vim

				Vim::on(:BufWrite, 'MyGroup'){}
				Vim::on(:BufWrite, 'MyOtherGroup'){}
				Vim::on(:BufRead, 'MyGroup'){}
				Vim::on(:FileRead, 'MyOtherGroup'){}

				proc_table = Vim::event_callbacks.
								values.map{|h| h.values}.flatten
				proc_table.should have(4).procs

				Vim::clear_event_handlers_by_group 'MyGroup'

				proc_table = Vim::event_callbacks.
								values.map{|h| h.values}.flatten
				proc_table.should have(2).procs
			end

			it "should raise an ArgumentError when passed a nil group name" do
				stub_mock_vim
				lambda {
					Vim::clear_event_handlers_by_group nil
				}.should raise_error(ArgumentError)
			end

			it "should raise an ArgumentError when passed an empty string" do
				stub_mock_vim
				lambda {
					Vim::clear_event_handlers_by_group ''
				}.should raise_error(ArgumentError)
			end

			it "should raise an ArgumentError when passed a string with only
			whitespace".compact! do
				stub_mock_vim
				lambda {
					Vim::clear_event_handlers_by_group "    \t  "
				}.should raise_error(ArgumentError)
			end
		end
	end

	describe 'Command Creation' do
		it "should create an entry in user_commands hash" do
			Vim::should_receive( :command).exactly( :once)
			Vim::should_receive( :evaluate).at_least( :once)
			
			Vim::create_command( :MyCommand){}
			Vim::command_callbacks.should have_key( :MyCommand)
		end

		describe "command creation failure" do
			before(:all) do
				class << Vim
					alias_method :real_get_variable, :get_variable
					def get_variable( vname)
						return 1 if :'vw_failed' == vname.to_sym
						real_get_variable( vname)
					end
				end
			end

			after(:all) do
				class << Vim
					alias_method :get_variable, :real_get_variable
				end
			end

			it "should not create an entry in user_commands if command creation
			failed".compact! do
				Vim::should_receive( :command).exactly( :once)

				Vim::create_command( :MyCommand){} rescue nil
				Vim::command_callbacks.should_not have_key( :MyCommand)
			end
			
			it "should raise CommandCreationFailedError if command creation
			failed".compact! do
				Vim::should_receive( :command).exactly( :once)

				lambda {
					Vim::create_command( :MyCommand){} 
				}.should raise_error( CommandCreationFailedError)
			end
		end

		it "should allow legal options (:arity, :force, :completion)" do
			Vim::should_receive( :command).exactly( :once)
			Vim::should_receive( :evaluate).at_least( :once)
			lambda {
				Vim::create_command( 
					:MyCommand, 
					:arity => 2, 
					:completion => lambda{}, 
					:force => true
				){}
			}.should_not raise_error
		end

		it "should not allow illegal options (e.g. :foo)" do
			lambda {
				Vim::create_command( :MyCommand, :foo => 1){}
			}.should raise_error( ArgumentError)
		end

		it "should raise an ArgumentError if the first arg. is not a string or
		symbol".compact! do
			lambda {
				Vim::create_command( 7){}
			}.should raise_error( ArgumentError)
		end

		it "should raise an ArgumentError if :arity is passed and is not an
		Integer".compact! do
			lambda {
				Vim::create_command( :MyCommand, :arity => 'foo'){}
			}.should raise_error( ArgumentError)
		end

		it "should raise an ArgumentError if :completion is passed and is not a
		Proc".compact! do
			lambda {
				Vim::create_command( :MyCommand, :completion => 'foo'){}
			}.should raise_error( ArgumentError)
		end

		it "should raise an ArgumentError if no block is given" do
			lambda {
				Vim::create_command( :MyCommand)
			}.should raise_error( ArgumentError)
		end


		describe 'with :force => true' do
			it "should call Vim::Command with a string containing command!" do
				Vim::should_receive( :command).
					with( /command!/).
					exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				Vim::create_command( :MyCommand, :force => true){}
			end
		end

		describe 'with :force => false' do
			it "should call Vim::Command with a string containing command[^!]" do
				Vim::should_receive( :command).
					with( /command[^!]/).
					exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				Vim::create_command( :MyCommand, :force => true){}
			end
		end

		describe 'with :arity => 2' do
			it "should call Vim::Command passing in -nargs 2" do
				Vim::should_receive( :command).
					with( /command \s*-nargs=2/).
					exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				Vim::create_command( :MyCommand, :arity => 2){}
			end
		end


		#TODO: specs for callback & completion callback
		describe 'callbacks' do
			it "should call the passed block when command_callback is called
			with the command name (when the command name given was a
			symbol)".compact! do
				Vim::should_receive( :command).exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				block_called = false
				Vim::create_command( :MyCommand){ block_called = true}
				Vim::command_callback( :MyCommand, "")
				
				block_called.should == true
			end

			it "should call the passed block when command_callback is called
			with the command name (when the command name given was a
			string)".compact! do
				Vim::should_receive( :command).exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				block_called = false
				Vim::create_command( :MyCommand){ block_called = true}
				Vim::command_callback( 'MyCommand', "")

				block_called.should == true
			end

			it "should not call the passed block when a different user command
			is called".compact! do
				Vim::should_receive( :command).at_least( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				block_called = false
				Vim::create_command( :MyCommand){ block_called = true}
				Vim::create_command( :MyOtherCommand){}
				Vim::command_callback( :MyOtherCommand, "")
				
				block_called.should == false
			end
		end

		describe 'completion' do
			it "should call the completion Proc when invoke_completion is called
			with a command line that starts with the command name".compact! do
				Vim::should_receive( :command).exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				block_called = false
				Vim::create_command( 
					:MyCommand,
					:completion => lambda{ block_called = true; ''}
				){}

				Vim::command_completion('arg', 'MyCommand arg', 13)
				block_called.should == true
			end

			it "should not call the completion Proc when invoke_completion is
			called with a command line that includes (but does not start with)
			the command name".compact! do
				Vim::should_receive( :command).exactly( :once)
				Vim::should_receive( :evaluate).at_least( :once)

				block_called = false
				Vim::create_command(
					:MyCommand,
					:completion => lambda{ block_called = true; ''} 
				){}

				lambda {
					Vim::command_completion('arg', 'Not MyCommand arg', 17)
				}.should raise_error(UnexpectedCompletionError)
				block_called.should == false
			end
		end
	end
end

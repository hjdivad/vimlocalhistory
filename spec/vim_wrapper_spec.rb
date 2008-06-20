require 'spec/spec_helper'

require 'lang_utils'


describe 'Vim Wrapper' do
	include VimLocalHistory::SpecHelper

	before(:all) do
		Vim = mock("VIM")
		load 'vim_wrapper.rb'
		class << Vim
			alias_method :real_callbacks, :callbacks
			def callbacks
				real_callbacks
			end
		end
	end


	it "should have a proc entry in the callbacks table for an event,group pair,
	after on is called with that pair and a block.  Furthermore, :command should
	have been called (in setting up the event handlers)".compact! do

		Vim::should_receive(:command).
			with( an_instance_of(String)).
			at_least(:once)

		Vim::on(:BufWrite, 'MyGroup'){}

		callbacks = Vim::callbacks
		callbacks.should have_key(:BufWrite)
		callbacks[:BufWrite].should have_key(:MyGroup)
		callbacks[:BufWrite][:MyGroup].should_not be_empty
		callbacks[:BufWrite][:MyGroup].first.should be_an_instance_of(Proc)
	end

	it "should invoke the block passed into Vim::on when the callback is called
	with the same event and group, and the proc_id passed to :command".
	compact! do
		proc_id = nil
		@block_called = false

		Vim::should_receive(:command) { |string|
			proc_id = $1 if string =~ /(\d{4,})/
		}.with( an_instance_of(String)).at_least(:once)

		Vim::on(:BufWrite, 'MyGroup'){ @block_called = true}
		proc_id.should_not be_nil

		Vim::callback( :BufWrite, 'MyGroup', proc_id)
		@block_called.should == true
	end

	it "should not invoke blocks with the wrong proc_id on callback, even if the
	callback event,group pair matches the one used to add the block".
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
		
		Vim::callback( :BufWrite, 'MyGroup', proc_id)
		@b2_called.should == false
	end


	describe 'clear_by_group' do
		it "should be invoking Vim::command and not Vim::evaluate" do
			Vim::should_receive(:command)
			Vim::should_not_receive(:evaluate)
			Vim::clear_event_handlers_by_group 'MyGroup'
		end

		it "should clear all the callbacks for the group in all events" do
			stub_mock_vim

			Vim::on(:BufWrite, 'MyGroup'){}
			Vim::on(:BufWrite, 'MyGroup'){}
			Vim::on(:BufRead, 'MyGroup'){}
			Vim::on(:FileRead, 'MyGroup'){}

			proc_table = Vim::callbacks.values.map{|h| h.values}.flatten
			proc_table.should have(4).procs

			Vim::clear_event_handlers_by_group 'MyGroup'

			proc_table = Vim::callbacks.values.map{|h| h.values}.flatten
			proc_table.should be_empty
		end

		it "should not clear any callbacks for other groups in any events" do
			stub_mock_vim

			Vim::on(:BufWrite, 'MyGroup'){}
			Vim::on(:BufWrite, 'MyOtherGroup'){}
			Vim::on(:BufRead, 'MyGroup'){}
			Vim::on(:FileRead, 'MyOtherGroup'){}

			proc_table = Vim::callbacks.values.map{|h| h.values}.flatten
			proc_table.should have(4).procs

			Vim::clear_event_handlers_by_group 'MyGroup'

			proc_table = Vim::callbacks.values.map{|h| h.values}.flatten
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

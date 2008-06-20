require 'lang_utils'

class << Vim

	def get_variable( var_name)
		Vim::evaluate( "exists(\"#{var_name}\") ? #{var_name} : \"\"")
	end


	# handle events
	def on( event_name, group_name = nil, pattern='*', &block)
		raise BlockRequiredError unless block_given?
		raise ArgumentError.new("event_name cannot be null") unless event_name

		#TODO: gen group name
		group_name = :gen1 unless group_name
		the_proc = Proc.new &block

		setup_event_callback( event_name, group_name, the_proc)

		[	"augroup #{group_name}",
				"au!",
				"autocmd #{event_name} #{pattern} " +
				"ruby Vim::callback(" +
					"'#{event_name.to_s}', " +
					"'#{group_name.to_s}', " +
					"#{the_proc.object_id}" +
				")",
			"augroup END",
		].each{ |cmd| Vim::command cmd }
	end

	def clear_event_handlers_by_group( group_name)
		raise ArgumentError.new(
			"Group name must be specified to clear_all_by_group"
		) unless group_name and group_name.strip.length > 0

		Vim::command( "au! #{group_name}")

		group_name = group_name.to_sym
		callbacks.values.each do |group_to_procs|
			group_to_procs[ group_name].clear if
				group_to_procs.has_key? group_name
		end
	end

	def callback( event_name, group_name, proc_id)
		the_proc = get_event_handlers( event_name, group_name).find do |a_proc|
			a_proc.object_id == proc_id.to_i
		end
		
		unless the_proc
			Vim::message(
				"No such event handler found!  Probably a bug in
				VimLocalHistory.  Was looking for event #{event_name}, group
				#{group_name}, proc_id #{proc_id}".compact!
			)
		else
			the_proc.call
		end
	end


	# ancillary
	private

	def callbacks
		(@callbacks ||= Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = []}})
	end

	def setup_event_callback( event_name, group_name, the_proc)
		get_event_handlers( event_name, group_name) << the_proc
	end

	def get_event_handlers( event_name, group_name)
		# @callbacks => event => group => [procs]
		callbacks[ event_name.to_sym][ group_name.to_sym]
	end
end



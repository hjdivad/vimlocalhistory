require 'vlh/lang_utils'

class << Vim

	########################################################################
	# Initialize vim (e.g., create expected vim functions)
	
	# VWRubyEscape is meant to take an arbitrary vim variable and turn it into a
	# string, which will eval into the appropriate ruby constant.  The return
	# value should thus be suitable for use in calls to ruby (see :he
	# ruby-commands)
	Vim::command("
		function VWRubyEscape( myvar)
			if type(a:myvar) == 0 \"integer 
				 return a:myvar . ''
			elseif type(a:myvar) == 1 \"string
				 return '\"' . substitute(a:myvar, '\"', '\\\\\"', 0) . '\"'
			endif
		endfun
	")

	# VWUserCommandCompletion is meant to have the correct signature for a vim
	# command completion function (see :he command-completion-custom) and to
	# have its return value determined by the function Vim::command_completion
	Vim::command("
		function VWUserCommandCompletion(arglead, cmdline, cursorpos)
			let rubycmd = \"Vim::set_variable('rv', Vim::command_completion(\" . VWRubyEscape(a:arglead) . ',' . VWRubyEscape(a:cmdline) . ',' . VWRubyEscape(a:cursorpos) . \"))\"
			exec 'ruby ' . rubycmd
			return rv
		endfun
	")

	########################################################################


	def get_variable( var_name)
		var = Vim::evaluate(
			"exists(\"#{var_name}\") ? #{var_name} : \"__NIL__\""
		)

		var == '__NIL__' ? nil : var
	end

	def set_variable( name, value)
		q_value = 
			case value
			when String
				"\"#{value}\""	
			else
				value
			end
		Vim::command("let #{name} = #{q_value}")
	end

	def edit_file( path)
		Vim::command("edit #{path}")
	end

	def diffsplit( path, options={})
		vert = "vertical" if options[:vertical]
		Vim::command("#{vert} diffsplit #{path}")
	end


	########################################################################
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
				"ruby Vim::event_callback(" +
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
		event_callbacks.values.each do |group_to_procs|
			group_to_procs[ group_name].clear if
				group_to_procs.has_key? group_name
		end
	end

	def event_callback( event_name, group_name, proc_id)
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

	def command_callback( cmd_name, args)
		cmd_proc = command_callbacks[ cmd_name.to_sym]
		raise CommandNotDefinedError.new(
			"Unable to find user-defined command #{cmd_name}"
		) unless cmd_proc

		cmd_proc.call *args
	end


	########################################################################
	# handle user-defined-commands
	
	# Arguments given by vim (see :he command-completion-custom)
	#
	# arg_lead		the leading portion of the argument currently being
	#				completed on
	# cmd_line		the entire command line
	# cursor_pos	the cursor position in it (byte index)
	def command_completion( arg_lead, cmd_line, cursor_pos)
		cmd_name = (cmd_line =~ /^((?:\w|\d)+)/; $1)
		raise UnexpectedCompletionError.new(
			"Unable to determine command to complete for cmd_line #{cmd_line}"
		) unless cmd_name

		completion = command_completions[ cmd_name.to_sym]
		raise UnexpectedCompletionError.new("
			Unable to find completion proc for #{cmd_name}, but apparently it was expected.
		".compact!) unless completion


		completion.call arg_lead, cmd_line, cursor_pos
	end

	# Command creation is provided via the method
	# +Vim::create_command(command_name, command_options, &command_block)
	#
	# +command_name+ is the name of the ex command to create and must start with
	# an uppercase character, per vim restrictions.
	#
	# +command_options+ is optional, and may include the following keys:
	# 	+:force+
	# 		Will cause the command to be created with `command!` instead of
	# 		`command` - i.e., this will cause an existing command with the same
	# 		name to be overwritten.
	#
	# 	+:arity+
	# 		Will be passed into -nargs (see :he command-nargs).  This will make
	# 		vim help the user by giving useful errors if the wrong number of
	# 		arguments are passed to the command.  If +:arity+ is unspecified, it
	# 		defaults to '*' (i.e., any number of arguments).
	#
	# 	+:completion+
	# 		If specified, must be a +lambda+ that must return a string with each
	# 		completion option separated by newlines (see :he
	# 		command-completion-custom)
	#
	# a block must be passed to this method (failure to do so will result in an
	# +ArgumentError+).  It is this block that will be invoked when the user
	# executes the command.
	#
	#TODO: examples
	def create_command( name, options={}, &block)
		options.assert_valid_keys :arity, :completion, :force
		
		raise ArgumentError.new(
			"Command name must be a string or symbol"
		) unless name.is_a? String or name.is_a? Symbol

		raise ArgumentError.new("
			name may not contain single or double quotes (other restrictions may
			apply -- see :he command)
		".compact!) if name =~ /'|"/

		raise ArgumentError.new(
			":arity option must be an Integer"
		) if options.has_key?(:arity) and not options[:arity].is_a? Integer

		raise ArgumentError.new("
			:completion must be a Proc that, when invoked, returns a string that
			delimits legal completions with newlines
		".compact!) if options.has_key?(:completion) and 
			not options[:completion].is_a? Proc

		raise ArgumentError.new("A block must be given") unless block_given?


		nargs, complete, force = [	
			(" -nargs=#{options[:arity]}" if options[:arity]), 
			('-complete=custom,VWUserCommandCompletion' if 
			 	options.has_key? :completion), 
			('!' if options[:force])
		]
		command = "command#{force} #{nargs} #{complete} #{name} ruby " +
					"args = [<f-args>];Vim::command_callback( \"#{name.to_s.gsub(/"/,'\"')}\", args)"

		Vim::command("
			try 
				let vw_failed = 0
				exe '#{command}'
			catch
				let vw_failed = 1
			endtry
		".strip)

		raise CommandCreationFailedError.new("
			Unable to create command (vim error) -- see v:exception for details
		".compact!) if 1 == Vim::get_variable('vw_failed')


		command_callbacks[ name.to_sym] = Proc.new &block
		command_completions[ name.to_sym] = options[:completion] if 
			options.has_key? :completion
	end


	########################################################################
	# ancillary
	private

	def event_callbacks
		# hash -> hash -> [Procs]
		(@event_callbacks ||= 
		 	Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = []}})
	end

	def setup_event_callback( event_name, group_name, the_proc)
		get_event_handlers( event_name, group_name) << the_proc
	end

	def get_event_handlers( event_name, group_name)
		# @event_callbacks => event => group => [procs]
		event_callbacks[ event_name.to_sym][ group_name.to_sym]
	end


	def command_callbacks
		@command_callbacks ||= Hash.new
	end

	def command_completions
		@command_completions ||= Hash.new
	end
end



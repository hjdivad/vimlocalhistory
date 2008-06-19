class << Vim
	def get_variable( var_name)
		Vim::evaluate( "exists(\"#{var_name}\") ? #{var_name} : \"\"")
	end
end

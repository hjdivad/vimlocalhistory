require 'errors'


class String

	# Does the same as String#chomp, except removes characters from the start of
	# the string, rather than the end, and the argument is required.
	def chomps( separator)
		self.gsub Regexp.new("^#{separator}"), ''
	end

	def starts_with?( prefix)
		self[ 0...(prefix.size)] == prefix
	end

	def ends_with?( suffix)
		self[ -(suffix.size)..-1] == suffix
	end

	def compact!
		self.strip!
		self.gsub! /^\s+/, ' '
		self.gsub! /\n/, ''
		self
	end
end


class Regexp
	def |( other_regex)
		raise UnmatchedOptionsError.new("
			/#{self.source}/ had options #{self.options}, but
			/#{other_regex.source}/ had options #{other_regex.options}
		".compact!) unless self.options == other_regex.options

		Regexp.new(
			"(?:#{self.source})|(?:#{other_regex.source})",
			self.options
		)
	end
end



#!/usr/bin/ruby

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



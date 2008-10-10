# coding: utf-8
require 'vlh/errors'


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

	# Strips newlines, leading whitespace in newlines, and trailing and leading
	# whitespace.  Convenient for writing long single-line strings across
	# multiple lines of source.
	#
	# Examples:
	#	  >> "
	#	  	here is a single line string,
	#	  	specified over two lines
	#	  ".compact!
	#	  => "here is a single line string,specified over two lines"
	# 	
	def compact!
		self.strip!
		self.gsub! /^\s+/, ' '
		self.gsub! /\n/, ''
		self
	end
end


class Regexp
	# Combines this Regexp with +other_regex+ with a logical OR.  An
	# +UnmatchedOptionsError+ is raised if +other_regex+ doesn't have the same
	# flags as this Regexp.
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

	# Combines this Regexp with +other_regex+ with a logical AND.  An
	# +UnmatchedOptionsError+ is raised if +other_regex+ doesn't have the same
	# flags as this Regexp.
	def +( other_regex)
		raise("
			/#{self.source}/ had options #{self.options}, but
			/#{other_regex.source}/ had options #{other_regex.options}
		".compact!) unless self.options == other_regex.options

		Regexp.new(
			"(?:#{self.source})(?:#{other_regex.source})",
			self.options
		)
	end
end

########################################################################
# Pulled from activesupport -- if I use any more of this, I should probably
# just package the gem into vlh/lib or somesuch

class Fixnum
	def kilobytes
	  self * 1024
	end
	alias :kilobyte :kilobytes

	def megabytes
	  self * 1024.kilobytes
	end
	alias :megabyte :megabytes
	
	def position
		mod_100 = self.abs % 100
		mod_10 = self.abs % 10

		return "#{self}th" if (11..13).include? mod_100

		case mod_10
			when 1
				"#{self}st"
			when 2
				"#{self}nd"
			when 3
				"#{self}rd"
			else
				"#{self}th"
		end
	end
end

class Hash
	def assert_valid_keys(*valid_keys)
		unknown_keys = keys - [valid_keys].flatten
		raise(
			ArgumentError, 
			"Unknown key(s): #{unknown_keys.join(", ")}"
		) unless unknown_keys.empty?
	end

	# Return a new hash with all keys converted to symbols.
	def symbolize_keys
		inject({}) do |options, (key, value)|
			options[key.to_sym || key] = value
			options
		end
	end

	# Destructively convert all keys to symbols.
	def symbolize_keys!
		self.replace(self.symbolize_keys)
	end

	def has_keys?( *keys)
		not keys.find{|k| return false unless self.has_key?(k)}
	end
end

module Enumerable
	# as #each but look through items +n+ at a time
	# if +partial+ is a true value then yield to the block with the remaining
	# itmes if +__self__.size+ % +n+ != 0
	def each_n( n, partial=false)
		raise ArgumentError("Step must be >= 1") if n < 1

		buf = []
		self.each_with_index do |item, idx|
			buf << item
			if 0 == (idx+1) % n
				yield *buf
				buf.clear
			end
		end

		yield *buf if partial and not buf.empty?
	end

	def map_with_index
		rv = Array.new(self.size)
		self.each_with_index do |item, idx|
			rv[idx] = yield item, idx
		end
		rv
	end

	def map_with_index!
		self.each_with_index do |item, idx|
			self[ idx] = yield item, idx
		end
	end
end

########################################################################


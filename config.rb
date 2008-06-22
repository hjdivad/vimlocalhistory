pdir = File.dirname(__FILE__)
$: << "#{pdir}/src" unless $:.include? "#{pdir}/src"
$: << "#{pdir}/src/vlh" unless $:.include? "#{pdir}/src/vlh"

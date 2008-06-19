#!/usr/bin/ruby

require 'config'
require 'rubygems'
require 'fileutils'
require 'spec'
require 'spec/rake/spectask'

require 'lang_utils'


install_source = Dir.glob('./src/*')
install_target = ENV['INSTALL_TARGET'] || "#{ENV['HOME']}/.vim/plugin"
installed_names = install_source.map do |path|
	rel_path = path.chomps( File.dirname(path)).chomps('/')
	"#{install_target}/#{rel_path}"
end


desc <<-EOS
	Install The plugin to ~/.vim/plugin
EOS
task :install do
	FileUtils.cp_r install_source, install_target
end

desc <<-EOS
	Removes the plugin from ~/.vim/plugin
EOS
task :uninstall do
	FileUtils.rm_r installed_names, :force => true
end

desc <<-EOS
	Launch a testing instance of vim
EOS
task :test do
	system 'vim +"so vimlocalhistory-test.vim"'
end

task :clean do
	FileUtils.rm_r ['./test', './report', './tags'], :force => true
end


Spec::Rake::SpecTask.new do |t|
	t.ruby_opts = ['-rconfig']
	t.spec_opts = ['--color --format specdoc']
end

namespace :spec do
	desc <<-EOS
		Runs specs and produces an html report in report/report.html
	EOS
	Spec::Rake::SpecTask.new(:html) do |t|
		directory 'report'

		t.ruby_opts = ['-rconfig']
		t.spec_opts = ['--color --format html:report/report.html --format specdoc']
	end

	desc <<-EOS
		Runs specs with backtraces shown
	EOS
	Spec::Rake::SpecTask.new(:trace) do |t|
		t.ruby_opts = ['-rconfig']
		t.spec_opts = ['--color --backtrace --format specdoc']
	end

	desc <<-EOS
		Runs specs with backtraces shown through rdebug
	EOS
	task :debug do |t|
		system "rdebug rake -- spec:trace"
	end
end

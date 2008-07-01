#!/usr/bin/ruby

fp = File.dirname(__FILE__) + '/src'
$: << fp unless $:.include? fp

require 'rubygems'
require 'fileutils'
require 'spec'
require 'spec/rake/spectask'

require 'vlh/lang_utils'


VLH_VERSION='0.1'


install_source = Dir.glob('./src/*')
install_target = ENV['INSTALL_TARGET'] || "#{ENV['HOME']}/.vim/plugin"
installed_names = install_source.map do |path|
	rel_path = path.chomps( File.dirname(path)).chomps('/')
	"#{install_target}/#{rel_path}"
end


########################################################################
# Installation and packaging tasks
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
	Reinstalls the plugin (equivalent to running rake uninstall install)
EOS
task :reinstall => [:uninstall, :install]


desc <<-EOS
	Creates a tarball for distribution via, e.g. vim.org scripts
EOS
task :tarball do
	FileUtils.rm "vimlocalhistory-#{VLH_VERSION}.tar.gz", :force => true

	system "tar cf vimlocalhistory-#{VLH_VERSION}.tar
		--transform='s,^src/(.*),plugin/\\1,x' src/*".compact!

	system "tar rf vimlocalhistory-#{VLH_VERSION}.tar INSTALL"
	system "gzip vimlocalhistory-#{VLH_VERSION}.tar"
end

desc <<-EOS
	Cleans up the working directory, removing most generated files
EOS
task :clean do
	FileUtils.rm_r [
		'./test', './report',
		"./vimlocalhistory-#{VLH_VERSION}.tar.gz"
	], :force => true
end


########################################################################
# Testing (incl. spec) tasks

desc <<-EOS
	Launch a testing instance of vim
EOS

task :test do
	FileUtils.mkdir_p 'test/repo'
	pwd = Dir.pwd
	repo_path = File.expand_path('./test/repo')
	test_vim = File.expand_path('src/vimlocalhistory.vim')

	system 'cd /tmp/ && vim -u NONE ' +
			'+"let g:vlh_repository_dir=\'' + repo_path + '\'" ' +
			'+"let g:vlh_exclude_file_pattern=\'.*\.ignore\'" ' +
			'+"let g:vlh_exclude_path_pattern=\'\/ignore\/\'" ' +
			'+"so ' + test_vim + '" && cd ' + pwd
end
Spec::Rake::SpecTask.new do |t|
	t.ruby_opts = ['-Isrc']
	t.spec_opts = ['--color --format specdoc']
end

namespace :spec do
	desc <<-EOS
		Runs specs and produces an html report in report/report.html
	EOS
	Spec::Rake::SpecTask.new(:html) do |t|
		FileUtils.mkdir_p 'report'

		t.ruby_opts = ['-Isrc']
		t.spec_opts = ['--color --format html:report/report.html --format specdoc']
	end

	desc <<-EOS
		Runs specs with backtraces shown
	EOS
	Spec::Rake::SpecTask.new(:trace) do |t|
		t.ruby_opts = ['-Isrc']
		t.spec_opts = ['--color --backtrace --format specdoc']
	end

	desc <<-EOS
		Runs specs with backtraces shown through rdebug
	EOS
	task :debug do |t|
		system "rdebug rake -- spec:trace"
	end
end
########################################################################

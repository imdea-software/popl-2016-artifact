#!/usr/bin/env ruby

require 'yaml'

BRANCH_NAME = 'experiments'

abort "Expected clean working directory." unless `git status` =~ /working directory clean/
abort "Should be on #{BRANCH_NAME} branch." unless `git status` =~ /On branch #{BRANCH_NAME}/
abort "Unable to caffeinate." unless system("caffeinate -w #{Process.pid} &")

name = File.basename(__FILE__,'.rb')
config = YAML.load_file(File.join('config',"#{name}.yaml"))

reporter = File.join('bin', 'report.rb')
log = File.join('data', 'report', Time.now.strftime('report-%h-%d-%Y-%Hh%M.txt'))
File.open(log, 'a') {|f| f.puts "# #{log}" }

config['experiments'].each do |e|
  data = File.join('data', name, e['data_file'])
  options = begin
    e['sources'].map{|s| "-s \"#{s}\""} +
    e['algorithms'].map{|a| "-a \"#{a}\""} +
    e['timeouts'].map{|t| "-t #{t}"}
  end * ' '
  system("#{reporter} -f #{data} #{options}", out: [log,'a'], err: :out)
end

abort "Unable to add report."     unless system("git add #{log}")
abort "Unable to commit report."  unless system("git commit -a -m \"Auto-generated #{log}.\"")
abort "Unable to push report."    unless system("git push")

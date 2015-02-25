#!/usr/bin/env ruby

BRANCH_NAME = 'experiments'
report_file = Time.now.strftime("data/reports/report-%h-%d-%Y-%Hh%M.txt")

abort "Expected clean working directory." unless `git status` =~ /working directory clean/
abort "Should be on #{BRANCH_NAME} branch." unless `git status` =~ /On branch #{BRANCH_NAME}/
abort "Unable to caffeinate." unless system("caffeinate -w #{Process.pid} &")

File.open(report_file, 'a') {|f| f.puts "# #{report_file}" }

system(%w{
./bin/report.rb
  -s "data/histories/generated/small/**/*.log"
  -a "enumerate -c"
  -a "counting -b 4" -a "counting -b 4 -r"
  -a "counting -b 2" -a "counting -b 2 -r"
  -a "counting -b 0" -a "counting -b 0 -r"
  -a "symbolic" -a "symbolic -r"
  -a "saturate" -a "saturate -r"
  -t 10
  -f data/experiments/violations-covered.tsv
} * ' ', out: [report_file,'a'], err: :out)

system(%w{
./bin/report.rb
  -s "data/histories/generated/big/**/*.log"
  -a "enumerate -c"
  -a "counting -b 4" -a "counting -b 4 -r"
  -a "symbolic" -a "symbolic -r"
  -a "saturate" -a "saturate -r"
  -t 5 -t 25 -t 50 -t 75 -t 100
  -f data/experiments/avg-steps-until-timeout.tsv
} * ' ', out: [report_file,'a'], err: :out)

abort "Unable to add report."     unless system("git add #{report_file}")
abort "Unable to commit report."  unless system("git commit -a -m \"Auto-generated #{report_file}.\"")
abort "Unable to push report."    unless system("git push")

#!/usr/bin/env ruby

BRANCH_NAME = 'master'
report_file = Time.now.strftime("data/report-%h-%d-%Y-%Hh%M.txt")

# abort "Expected clean working directory." unless `git status` =~ /working directory clean/
abort "Should be on #{BRANCH_NAME} branch." unless `git status` =~ /On branch #{BRANCH_NAME}/
abort "Unable to caffeinate." unless system("caffeinate -w #{Process.pid} &")

File.open(report_file, 'a') {|f| f.puts "# #{report_file}" }

system(%w{
./bin/report.rb
  -s "examples/generated/ScalObject-msq-big/*.log"
  -a "enumerate -c"
  -a "counting -b 4" -a "counting -b 4 -r"
  -a "symbolic" -a "symbolic -r"
  -a "saturate" -a "saturate -r"
  -t 5 -t 25 -t 50 -t 75 -t 100
  -d steps-until-timeout,data/avg-steps-until-timeout.csv

} * ' ', out: [report_file,'a'], err: :out)

system("gnuplot plots/avg-steps-until-timeout.plot", out: [report_file,'a'], err: :out)

# TODO create better benchmarks
# Scalobject-bkq-small is too hard, and contains too few errors
# bkq-almost-sequential is too obviously errorneous -- even counting-0 gets it

# TODO add more objects...
# -s "examples/generated/ScalObject-xxx-small/*.log"
# -s "examples/generated/ScalObject-yyy-small/*.log"

system(%w{
./bin/report.rb
  -s "examples/generated/ScalObject-bkq-small/*.log"
  -a "enumerate -c"
  -a "counting -b 4" -a "counting -b 4 -r"
  -a "counting -b 2" -a "counting -b 2 -r"
  -a "counting -b 0" -a "counting -b 0 -r"
  -a "symbolic" -a "symbolic -r"
  -a "saturate" -a "saturate -r"
  -t 10
  -d violations-covered,data/violations-covered.csv
} * ' ', out: [report_file,'a'], err: :out)

system("gnuplot plots/violations-covered.plot", out: [report_file,'a'], err: out)


system(%w{
./bin/report.rb
  -s "examples/generated/ScalObject-msq-big/*.log"
  -a "enumerate -c"
  -a "counting -b 4" -a "counting -b 4 -r"
  -a "counting -b 2" -a "counting -b 2 -r"
  -a "counting -b 0" -a "counting -b 0 -r"
  -a "symbolic" -a "symbolic -r"
  -a "saturate" -a "saturate -r"
  -t 20
  -d steps-until-timeout,data/avg-steps-until-fixed-timeout.csv
} * ' ', out: [report_file,'a'], err: :out)

system("gnuplot plots/avg-steps-until-fixed-timeout.plot", out: [report_file,'a'], err: out)

abort "Unable to add report."     unless system("git add #{report_file}")
abort "Unable to commit report."  unless system("git commit -a")
abort "Unable to push report."    unless system("git push")

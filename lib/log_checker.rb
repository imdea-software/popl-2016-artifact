#!/usr/bin/env ruby

require 'optparse'
require 'logger'
require 'os'

module Kernel
  def log
    @@logger ||= (
      l = Logger.new(STDOUT,'daily')
      l.formatter = proc do |severity, datetime, progname, msg|
        "[#{progname || severity}] #{msg}\n"
      end
      l
    )
  end
end

require_relative 'history'
require_relative 'execution_log_parser'
require_relative 'history_checker'
require_relative 'lineup_checker'
require_relative 'satisfaction_checker'
require_relative 'saturation_checker'

log.level = Logger::WARN

@frequency = 1
@checker = nil
@incremental = false
@remove_obsolete = false

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE"

  opts.separator ""

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end

  opts.on('-q', "--quiet", "") do |q|
    log.level = Logger::ERROR
  end

  opts.on("-v", "--verbose", "") do |v|
    log.level = Logger::INFO
  end

  opts.on("-d", "--debug", "Show debugging info?") do |d|
    log.level = Logger::DEBUG
  end

  opts.on("--checker NAME", [:lineup, :smt, :saturation],
    "from [lineup, smt, saturation]") do |c|
    @checker = c
  end

  opts.on("--frequency N", Integer,
    "Check every N steps (default #{@frequency})") do |n|
    @frequency = n
  end

  opts.on("--[no-]incremental",
    "Incremental checking? (default #{@incremental}).") do | i|
    @incremental = i
  end

  opts.on("--[no-]remove-obsolete",
    "Remove operations? (default #{@remove_obsolete}).") do |r|
    @remove_obsolete = r
  end
end.parse!

begin
  execution_log = ARGV.first
  unless execution_log && File.exists?(execution_log)
    log.fatal "Invalid or missing execution-log file '#{execution_log}'."
    exit
  end

  log_parser = ExecutionLogParser.new(execution_log)

  @checker =
    case @checker
    when :lineup;     LineUpChecker
    when :smt;        SatisfactionChecker
    when :saturation; SaturationChecker
    else              HistoryChecker
    end.new(log_parser.object, @incremental)

  num_steps = 0
  num_checks = 0
  max_rss = 0
  violation = nil

  # measure memory usage in a separate thread, since a relatively expensive
  # system call is used
  rss_thread = Thread.new do
    rss = OS.rss_bytes
    max_rss = rss if rss > max_rss
    sleep 1
  end

  start_time = Time.now

  log_parser.parse! do |h|
    next unless (num_steps += 1) % @frequency == 0
    violation = num_steps unless @checker.nil? || @checker.check(h) || violation
    num_checks += 1
    break if violation # TODO keep going?
  end

  end_time = Time.now

  puts "OBJECT:     #{log_parser.object || "?"}"
  puts "STEPS:      #{num_steps}"
  puts "CHECKER:    #{@checker}"
  puts "CHECKS:     #{@checker.num_checks}"
  puts "MEMORY:     #{max_rss / 1024.0}KB"
  puts "TIME:       #{end_time - start_time}s"
  puts "VIOLATION:  #{violation || "none"}"
  puts "TIME/CHECK: #{(end_time - start_time)/num_checks}s"
ensure
  log.close
end

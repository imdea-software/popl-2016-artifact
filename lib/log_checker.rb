#!/usr/bin/env ruby

require 'optparse'
require 'logger'

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
require_relative 'lineup_checker'
require_relative 'satisfaction_checker'

log.level = Logger::WARN

@frequency = 1
@lineup_checker = nil
@smt_checker = nil
@saturation_checker = nil

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

  opts.on("--frequency N", Integer, "Check every N steps (default #{@frequency})") do |n|
    @frequency = n
  end

  opts.on("--line-up", "Use LineUp checker.") do |c|
    @lineup_checker = LineUpChecker.new
  end

  opts.on("--smt-solver", "Use SAT-based checker.") do |c|
    @smt_checker = SatisfactionChecker.new
  end

  opts.on("--saturation", "Use custom saturation checker.") do |c|
  end

  opts.on("--remove-obsolete", "Remove obsolete operations.") do |c|
  end
end.parse!

begin
  execution_log = ARGV.first
  unless execution_log && File.exists?(execution_log)
    log.fatal "Invalid or missing execution-log file '#{execution_log}'."
    exit
  end

  step = 0
  History.from_execution_log(File.readlines(execution_log)) do |h|
    next unless (step += 1) % @frequency == 0
    @lineup_checker.check(h) if @lineup_checker
    @smt_checker.check(h) if @smt_checker
  end
ensure
  log.close
end

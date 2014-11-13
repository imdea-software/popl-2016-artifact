#!/usr/bin/env ruby

require 'logger'
require 'optparse'
require 'os'
require 'timeout'

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

log.level = Logger::WARN

@checker = nil
@completion = false
@incremental = false
@obsolete_removal = false
@checkers = [:enumerate, :symbolic, :saturate]
@step_limit = nil
@time_limit = nil
@frequency = nil

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE"

  opts.separator ""

  opts.on("-h", "--help", "Show this message.") do
    puts opts
    exit
  end

  opts.on('-q', "--quiet", "Display only error messages.") do |q|
    log.level = Logger::ERROR
  end

  opts.on("-v", "--verbose", "Display informative messages too.") do |v|
    log.level = Logger::INFO
  end

  opts.on("-d", "--debug", "Display debugging messages too.") do |d|
    log.level = Logger::DEBUG
  end

  opts.separator ""
  opts.separator "Specify which algorithm to use, from {#{@checkers * ", "}}"

  opts.on("-a", "--algorithm NAME", @checkers, "(default: none)") do |c|
    @checker = c
  end

  opts.separator ""
  opts.separator "Plus any combination of these flags:"

  opts.on("-c", "--[no-]completion",
    "History completion? (default #{@completion}).") do |c|
    @completion = c
  end

  opts.on("-i", "--[no-]incremental",
    "Incremental checking? (default #{@incremental}).") do |i|
    @incremental = i
  end

  opts.on("-r", "--[no-]remove-obsolete",
    "Remove operations? (default #{@obsolete_removal}).") do |r|
    @obsolete_removal = r
  end

  opts.separator ""
  opts.separator "And possibly some limits:"

  opts.on("-s", "--steps N", Integer, "Limit to N execution-log steps.") do |n|
    @step_limit = n
  end

  opts.on("-t", "--time N", Integer, "Limit to N seconds.") do |n|
    @time_limit = n
  end

  opts.on("-f", "--frequency N", Integer, "Only check once every N times.") do |n|
    @frequency = n
  end
end.parse!

class StepLimitReached < Exception; end
class ViolationFound < Exception; end

begin
  execution_log = ARGV.first
  unless execution_log && File.exists?(execution_log)
    log.fatal "Invalid or missing execution-log file '#{execution_log}'."
    exit
  end

  require_relative 'history'
  require_relative 'log_reader_writer'
  require_relative 'matching'
  require_relative 'history_checker'
  require_relative 'lineup_checker'
  require_relative 'satisfaction_checker'
  require_relative 'saturation_checker'
  require_relative 'obsolete_remover'

  logrw = LogReaderWriter.new(execution_log)
  history = History.new
  matcher = Matcher.get(logrw.object, history)
  @checker =
    case @checker
    when :enumerate;  LineUpChecker
    when :symbolic;   SatisfactionChecker
    when :saturate;   SaturationChecker
    else              HistoryChecker
    end.new(logrw.object, matcher, history, @completion, @incremental)

  # NOTE be careful, order is important here...
  # should check the histories before removing obsolete operations
  history.add_observer(matcher)
  history.add_observer(@checker)
  history.add_observer(ObsoleteRemover.new(history,matcher)) if @obsolete_removal

  num_steps = 0
  max_size = 0
  cum_size = 0
  max_rss = 0

  # measure memory usage in a separate thread, since a relatively expensive
  # system call is used
  rss_thread = Thread.new do
    rss = OS.rss_bytes
    max_rss = rss if rss > max_rss
    sleep 1
  end

  start_time = Time.now

  begin
    Timeout.timeout(@time_limit) do
      logrw.read do |act, method_or_id, *values|
        raise ViolationFound if @checker.violation?
        raise StepLimitReached if @step_limit && @step_limit <= num_steps

        size = history.count
        max_size = size if size > max_size
        cum_size += size
        num_steps += 1

        case act
        when :call
          log.debug('log-parser') {"[#{history.instance_variable_get(:@unique_id)+1}] call #{method_or_id}(#{values * ", "})"}
          next history.start!(method_or_id, *values)
        when :return
          log.debug('log-parser') {"[#{method_or_id}] return #{values * ", "}"}
          next history.complete!(method_or_id, *values)
        else
          fail "Unexpected action."
        end
      end
    end
  rescue Timeout::Error
    log.warn('log-parser') {"time limit reached"}
    timeout = "*"
  rescue StepLimitReached
    log.warn('log-parser') {"step limit reached"}
    stepout = "†"
  rescue ViolationFound
    log.warn('log-parser') {"violation discovered"}
  end

  end_time = Time.now

  puts "OBJECT:     #{logrw.object || "?"}"
  puts "CHECKER:    #{@checker}"
  puts "REMOVAL:    #{@obsolete_removal}"
  puts "VIOLATION:  #{@checker.violation?}"
  puts "STEPS:      #{num_steps}#{timeout}#{stepout}"
  puts "AVG SIZE:   #{(cum_size * 1.0 / num_steps).round(4)}"
  puts "MAX SIZE:   #{max_size}"
  puts "CHECKS:     #{@checker.num_checks}"
  puts "MEMORY:     #{(max_rss / 1024.0).round(4)}KB"
  puts "TIME:       #{(end_time - start_time).round(4)}s#{timeout}#{stepout}"
  puts "TIME/CHECK: #{((end_time - start_time)/@checker.num_checks).round(4)}s"
ensure
  log.close
end

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

module Enumerable
  def mean
    inject(&:+) / length.to_f
  end
  def sample_variance
    m = mean
    inject(0){|sum,i| sum + (i-m)**2} / (length-1).to_f
  end
  def standard_deviation
    Math.sqrt(sample_variance)
  end
end

log.level = Logger::WARN

@checker = nil
@checkers = [:enumerate, :symbolic, :saturate, :counting]

@options = {}
@options[:completion] = false
@options[:incremental] = false
@options[:removal] = false
@options[:step_limit] = nil
@options[:time_limit] = nil
@options[:frequency] = nil
@options[:bound] = 0

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
    "History completion? (default #{@options[:completion]}).") do |c|
    @options[:completion] = c
  end

  opts.on("-i", "--[no-]incremental",
    "Incremental checking? (default #{@options[:incremental]}).") do |i|
    @options[:incremental] = i
  end

  opts.on("-r", "--[no-]remove-obsolete",
    "Remove operations? (default #{@options[:removal]}).") do |r|
    @options[:removal] = r
  end

  opts.separator ""
  opts.separator "Flags for the counting checker:"

  opts.on("-b", "--interval-bound N", Integer, "") do |n|
    @options[:bound] = n
  end

  opts.separator ""
  opts.separator "And possibly some limits:"

  opts.on("-s", "--steps N", Integer, "Limit to N execution-log steps.") do |n|
    @options[:step_limit] = n
  end

  opts.on("-t", "--time N", Integer, "Limit to N seconds.") do |n|
    @options[:time_limit] = n
  end

  opts.on("-f", "--frequency N", Integer, "Only check once every N times.") do |n|
    @options[:frequency] = n
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
  require_relative 'enumerate_checker'
  require_relative 'symbolic_checker'
  require_relative 'saturate_checker'
  require_relative 'counting_checker'
  require_relative 'obsolete_remover'

  object = LogReaderWriter.object(execution_log)
  @options[:history] = history = History.new
  @options[:object] = object

  @checker =
    case @checker
    when :enumerate;  EnumerateChecker
    when :symbolic;   SymbolicChecker
    when :saturate;   SaturateChecker
    when :counting;   CountingChecker
    else              HistoryChecker
    end.new(@options)

  # NOTE be careful, order is important here...
  # should check the histories before removing obsolete operations
  history.add_observer(@checker)
  history.add_observer(ObsoleteRemover.new(history)) if @options[:removal]

  size = []
  concurrency = []
  num_steps = 0
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
    Timeout.timeout(@options[:time_limit]) do
      LogReaderWriter.read(execution_log) do |act, method_or_id, *values|
        raise ViolationFound if @checker.violation?
        raise StepLimitReached if @options[:step_limit] && @options[:step_limit] <= num_steps

        size << history.count
        concurrency << history.pending.count + (act == :call ? 1 : 0)
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

  puts "HISTORY:      #{execution_log}"
  puts "OBJECT:       #{@options[:object] || "?"}"
  puts "ALGORITHM:    #{@checker}"
  puts "REMOVAL:      #{@options[:removal]}"
  puts "VIOLATION:    #{@checker.violation?}"
  puts "STEPS:        #{num_steps}#{timeout}#{stepout}"
  puts "CONCURRENCY:  #{concurrency.mean.round(1)} ± #{concurrency.standard_deviation.round(1)}"
  puts "SIZE:         #{size.mean.round(1)} (avg), #{size.max} (max)"
  puts "CHECKS:       #{@checker.num_checks}"
  puts "MEMORY:       #{(max_rss / 1024.0).round(4)}KB"
  puts "TIME:         #{(end_time - start_time).round(4)}s#{timeout}#{stepout}"
  puts "TIME/CHECK:   #{((end_time - start_time)/@checker.num_checks).round(4)}s"
ensure
  log.close
end

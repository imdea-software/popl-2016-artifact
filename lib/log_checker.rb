#!/usr/bin/env ruby

require 'os'
require 'timeout'
require_relative 'prelude'

def parse_options
  options = OpenStruct.new

  checkers = [:enumerate, :symbolic, :saturate, :counting]

  options.checker = nil
  options.completion = false
  options.incremental = false
  options.removal = false
  options.step_limit = nil
  options.time_limit = nil
  options.frequency = nil
  options.bound = 0

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
    opts.separator "Specify which algorithm to use, from {#{checkers * ", "}}"

    opts.on("-a", "--algorithm NAME", checkers, "(default: none)") do |c|
      options.checker = c
    end

    opts.separator ""
    opts.separator "Plus any combination of these flags:"

    opts.on("-c", "--[no-]completion",
      "History completion? (default #{options.completion}).") do |c|
      options.completion = c
    end

    opts.on("-i", "--[no-]incremental",
      "Incremental checking? (default #{options.incremental}).") do |i|
      options.incremental = i
    end

    opts.on("-r", "--[no-]remove-obsolete",
      "Remove operations? (default #{options.removal}).") do |r|
      options.removal = r
    end

    opts.separator ""
    opts.separator "Flags for the counting checker:"

    opts.on("-b", "--interval-bound N", Integer, "") do |n|
      options.bound = n
    end

    opts.separator ""
    opts.separator "And possibly some limits:"

    opts.on("-s", "--steps N", Integer, "Limit to N execution-log steps.") do |n|
      options.step_limit = n
    end

    opts.on("-t", "--time N", Integer, "Limit to N seconds.") do |n|
      options.time_limit = n
    end

    opts.on("-f", "--frequency N", Integer, "Only check once every N times.") do |n|
      options.frequency = n
    end
  end.parse!
  options
end

class StepLimitReached < Exception; end
class ViolationFound < Exception; end

begin
  options = parse_options
  execution_log = ARGV.first
  unless execution_log && File.exists?(execution_log)
    log.fatal "Invalid or missing execution-log file '#{execution_log}'."
    exit
  end

  require_relative 'schemes'
  require_relative 'history'
  require_relative 'log_reader_writer'
  require_relative 'history_checker'
  require_relative 'obsolete_remover'

  scheme = Schemes.get(LogReaderWriter.object(execution_log)).new
  options.adt = scheme.name
  options.history = history = History.new(scheme)

  checker = HistoryChecker.get(options.to_h)

  # NOTE be careful, order is important here...
  # should check the histories before removing obsolete operations
  history.add_observer(checker)
  history.add_observer(ObsoleteRemover.new(history)) if options.removal

  data = {
    history: File.basename(execution_log),
    object: options.adt || "?",
    algorithm: checker.name,
    removal: options.removal,
    violation: false,
    timeout: false,
    stepout: false,
    steps: 0,
    checks: 0,
    size: [],
    width: [],
    weight: [],
    memory: OS.rss_bytes,
    time: 0,
  }

  # measure memory usage in a separate thread, since a relatively expensive
  # system call is used
  rss_thread = Thread.new do
    rss = OS.rss_bytes
    data[:memory] = rss if rss > data[:memory]
    sleep 1
  end

  data[:time] = Time.now

  begin
    Timeout.timeout(options.time_limit) do
      LogReaderWriter.read(execution_log) do |act, method_or_id, *values|
        raise ViolationFound if checker.violation?
        raise StepLimitReached if options.step_limit && options.step_limit <= num_steps

        data[:size] << history.count
        data[:width] << history.pending.count + (act == :call ? 1 : 0)
        data[:weight] << history.num_matches
        data[:steps] += 1

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
    data[:timeout] = true
  rescue StepLimitReached
    log.warn('log-parser') {"step limit reached"}
    data[:stepout] = true
  rescue ViolationFound
    log.warn('log-parser') {"violation discovered"}
  end

  data[:time] = Time.now - data[:time]
  data[:checks] = checker.num_checks
  data[:violation] = checker.violation?
  [:size, :width, :weight].each {|key| data[key] = data[key].stats}

  puts data.stringify.to_yaml

rescue SystemExit, Interrupt

ensure
  log.close
end

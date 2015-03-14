#!/usr/bin/env ruby

require 'set'

require_relative 'prelude'

require_relative 'schemes'
require_relative 'adt_implementation'

require_relative 'history'
require_relative 'theories'
require_relative 'z3'
require_relative 'enumerate_checker'
require_relative 'implementations'

def parse_options
  options = {}
  options[:destination] = "examples/patterns/"
  options[:generalize] = false
  options[:num_executions] = 10
  options[:num_threads] = 1
  options[:operation_limit] = 4

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename $0} [options] OBJECT"

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

    opts.on("-g", "--generalize", "Generalize patterns? (default #{options[:generalize]}).") do |g|
      options[:generalize] = g
    end

    opts.separator ""
    opts.separator "Some useful limits:"

    opts.on("-e", "--executions N", Integer, "Limit to N executions (default #{options[:num_executions]}).") do |n|
      options[:num_executions] = n
    end

    opts.on("-o", "--operations N", Integer, "Limit to N operations (default #{options[:operation_limit]}).") do |n|
      options[:operation_limit] = n
    end

  end.parse!
  options
end

def negative_examples(impl, op_limit)
  Enumerator.new do |y|
    length = 0
    sequences = [[]]

    until sequences.empty? do
      object = impl.call()
      seq = sequences.shift

      if seq.length > length
        puts if length > 0 if log.level > Logger::INFO
        puts "Length #{length = seq.length} sequences…" if log.level > Logger::INFO
      end

      log.debug('pattern-finder') {"Testing sequence: #{seq * "; "}"}

      result = []
      seq.each do |method_name|
        possible_args = object.adt_scheme.generate_arguments(method_name)
        args = possible_args.first # FIXME
        rets = object.method(method_name).call(*args)
        rets = [] if rets.nil?
        rets = [rets] unless rets.is_a?(Array)
        result << [method_name, args, rets]
        log.debug('pattern-finder') {"  #{method_name}(#{args * ", "})#{rets.empty? ? "" : " => #{rets * ", "}"}"}
      end

      excluded = [[]]

      result.each do |m,args,rets|
        if rets.empty?
          excluded.each {|e| e << [m,args,rets]}
        else
          possible_returns = object.adt_scheme.generate_returns(m)
          excluded = excluded.map {|e| possible_returns.map {|rs| e + [[m,args,rs]]}}.flatten(1)
        end
      end

      excluded.reject{|seq| seq == result}.each do |seq|
        y << History.from_enum(seq, object.adt_scheme)
      end

      if seq.length < op_limit then
        object.adt_scheme.adt_methods.each do |m|
          sequences << (seq + [m])
        end
      end
    end
  end
end

def ordered?(h1,h2)
  @solver.reset
  @theories.ordered(h1,h2).each(&@solver.method(:assert))
  @solver.check
end

begin
  log_filter(/pattern/)
  options = parse_options
  options[:impl] = Implementations.get(ARGV.first, num_threads: options[:num_threads])

  puts "Generating negative patterns…"
  patterns = []
  checker = EnumerateChecker.new(reference_impl: options[:impl], completion: true)
  context = Z3.context
  @solver = context.solver
  @theories = Theories.new(context)

  negative_examples(*options[:impl], options[:operation_limit]).each do |h|

    if patterns.any? {|p| ordered?(p,h)}
      log.info('pattern-finder') {"redundant pattern\n#{h}"}
      print "." if log.level > Logger::INFO
      next
    end

    h = h.weaken {|w| !checker.linearizable?(w)} if options[:generalize]

    # if p = patterns.find {|p| ordered?(p,w)}
    #   fail "Original example\n#{h}\nshould have been related to\n#{p}\nsince\n#{w}\nis."
    # end

    if idx = patterns.find_index {|p| ordered?(h,p)}
      log.info('pattern-finder') {"better pattern\n#{h}"}
      print "+" if log.level > Logger::INFO
      patterns[idx] = h
      next
    end

    log.info('pattern-finder') {"new pattern\n#{h}"}
    print "#" if log.level > Logger::INFO
    patterns << h

  end
rescue SystemExit, Interrupt

ensure
  puts if log.level > Logger::INFO
  if patterns
    log.warn('pattern-finder') {"found #{patterns.count} patterns\n#{patterns * "\n--\n"}"}
  end
end

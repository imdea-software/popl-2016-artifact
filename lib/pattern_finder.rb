#!/usr/bin/env ruby

require 'set'

require_relative 'prelude'

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
    object = impl.call()
    methods = object.methods.reject do |m|
      next true if Object.instance_methods.include? m
      next true if FFI::AutoPointer.instance_methods.include? m
      next true if object.methods.include?("#{m.to_s.chomp('=')}=".to_sym)
      false
    end

    length = 0
    sequences = [[]]
    until sequences.empty? do
      object = impl.call()
      unique_val = 0
      used_values = Set.new
      seq = sequences.shift

      if seq.length > length
        puts if length > 0 if log.level > Logger::INFO
        puts "Length #{length = seq.length} sequences…" if log.level > Logger::INFO
      end

      log.debug('pattern-finder') {"Testing sequence: #{seq * "; "}"}

      result = []

      log.debug('pattern-finder') {"Actual returns:"}
      seq.each do |method_name|
        m = object.method(method_name)
        possible_args = Matching.good_argument_values(method_name, used_values.to_a)
        args = possible_args.first
        used_values.merge(args)
        # args = m.arity.times.map{unique_val += 1}
        rets = m.call(*args)
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
          possible_returns = Matching.possible_return_values(m,args,used_values.to_a)
          excluded = excluded.map {|e| possible_returns.map {|v| e + [[m,args,[v]]]}}.flatten(1)
        end
      end
      excluded.reject! {|seq| seq == result}

      excluded.each do |seq|
        next if seq == result
        y << History.from_enum(seq)
      end

      if seq.length < op_limit then
        methods.each do |m|
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
  
  object = options[:impl].call().class.spec

  checker = EnumerateChecker.new(reference_impl: options[:impl], object: object, completion: true)
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

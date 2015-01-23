#!/usr/bin/env ruby

require 'set'

require_relative 'prelude'

require_relative 'history'
require_relative 'theories'
require_relative 'z3'
require_relative 'enumerate_checker'

require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'
require_relative 'impls/scal_object'

def get_object(options, object)
  (puts "Must specify an object."; exit) unless object
  case object
  when /\A(bkq|dq|dtsq|lbq|msq|fcq|ks|rdq|sl|ts|tsd|tsq|tss|ukq|wfq11|wfq12)\z/
    ScalObject.initialize(options.num_threads)
    [ScalObject, object]
  else
    puts "Unknown object: #{object}"
    exit
  end
end

def parse_options
  options = OpenStruct.new
  options.destination = "examples/patterns/"
  options.num_executions = 10
  options.num_threads = 1
  options.operation_limit = 4

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

    opts.separator ""
    opts.separator "Some useful limits:"

    opts.on("-e", "--executions N", Integer, "Limit to N executions (default #{options.num_executions}).") do |n|
      options.num_executions = n
    end

    opts.on("-o", "--operations N", Integer, "Limit to N operations (default #{options.operation_limit}).") do |n|
      options.operation_limit = n
    end

  end.parse!
  options
end

def negative_examples(obj_class, *obj_args, op_limit)
  Enumerator.new do |y|
    object = obj_class.new(*obj_args)
    methods = object.methods.reject do |m|
      next true if Object.instance_methods.include? m
      next true if object.methods.include?("#{m.to_s.chomp('=')}=".to_sym)
      false
    end

    sequences = [[]]
    until sequences.empty? do
      object = obj_class.new(*obj_args)
      unique_val = 0
      seq = sequences.shift

      log.debug('pattern-finder') {"Testing sequence: #{seq * "; "}"}

      result = []

      seq.each do |method_name|
        m = object.method(method_name)
        args = m.arity.times.map{unique_val += 1}
        rets = m.call(*args) || []
        # TODO make the method interface more uniform
        rets = [rets] unless rets.is_a?(Array)

        result << [method_name, args, rets]

        log.debug('pattern-finder') {"#{method_name}(#{args * ", "})#{rets.empty? ? "" : " => #{rets * ", "}"}"}
      end

      values = Set.new result.map{|_,args,rets| args + rets}.flatten
      values << :empty
      values << 0

      excluded = [[]]
      result.each do |m,args,rets|
        if rets.empty?
          excluded.each {|e| e << [m,args,rets]}
        else
          excluded = excluded.map {|e| values.map {|v| e + [[m,args,[v]]]}}.flatten(1)
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

def more_matches?(h1,h2)
  @solver.reset
  @theories.more_matches(h1,h2).each(&@solver.method(:assert))
  @solver.check
end

def weaker_than?(h1,h2)
  @solver.reset
  @theories.weaker_than(h1,h2).each(&@solver.method(:assert))
  @solver.check
end

begin
  options = parse_options
  options.impl = get_object(options,ARGV.first)

  puts "Generating negative patterns..."
  patterns = []
  
  obj_class, obj_args = options.impl
  object = obj_class.new(*obj_args).class.spec

  checker = EnumerateChecker.new(reference_impl: options.impl, object: object, completion: true)
  context = Z3.context
  @solver = context.solver
  @theories = Theories.new(context)

  negative_examples(*options.impl, options.operation_limit).each do |h|
    w = h.weaken {|w| !checker.linearizable?(w)}

    if patterns.any? {|p| more_matches?(w,p) }
      log.warn('pattern-finder') {"redundant pattern\n#{w}"}

    elsif idx = patterns.find_index {|p| more_matches?(p,w)}
      log.warn('pattern-finder') {"better pattern\n#{w}"}
      patterns[idx] = w

    else
      log.warn('pattern-finder') {"new pattern\n#{w}"}
      patterns << w

    end
  end
  
  log.warn('pattern-finder') {"found #{patterns.count} patterns\n#{patterns * "\n--\n"}"}
end

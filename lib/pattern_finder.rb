#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'set'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'
require_relative 'impls/scal_object'

def get_object(object)
  (puts "Must specify an object."; exit) unless object
  case object
  when /\A(bkq|dq|dtsq|lbq|msq|fcq|ks|rdq|sl|ts|tsd|tsq|tss|ukq|wfq11|wfq12)\z/
    ScalObject.initialize(@options.num_threads)
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

    opts.on("-d", "--destination DIR", "Where to put the files.") do |d|
      options.destination = d
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

def negative_examples(obj_class, *obj_args)

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

    # puts "Testing sequence: #{seq * "; "}"

    result = []

    seq.each do |method_name|
      m = object.method(method_name)
      args = m.arity.times.map{unique_val += 1}
      rets = m.call(*args) || []
      # TODO make the method interface more uniform
      rets = [rets] unless rets.is_a?(Array)

      result << [method_name, args, rets]

      # puts "#{method_name}(#{args * ", "})#{rets.empty? ? "" : " => #{rets * ", "}"}"
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
      yield seq if block_given?
    end

    if seq.length < @options.operation_limit then
      methods.each do |m|
        sequences << (seq + [m])
      end
    end
  end

end

begin
  @options = parse_options
  @options.object = get_object(ARGV.first)

  puts "Generating negative patterns..."

  negative_examples(*@options.object) do |e|
    puts "EXCLUDED : #{e.map{|m,args,rets| "#{m}(#{args * ", "})#{rets.empty? ? "" : " => #{rets * ", "}"}"} * "; "}"
  end


end

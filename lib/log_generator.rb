#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'
require_relative 'impls/scal_object'

DEST = "examples/generated/"

def get_object(object)
  (puts "Must specify an object."; exit) unless object
  case object
  when /msq/; [ScalObject, 'msq']
  when /bkq/; [ScalObject, 'bkq']
  else
    puts "Unknown object: #{object}"
    exit
  end
end

def parse_options
  options = OpenStruct.new
  options.objects = []
  options.num_executions = 10
  options.num_threads = 7
  options.time_limit = nil
  options.operation_limit = 1000

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename $0} [options] OBJECT"

    opts.separator ""

    opts.on("-h", "--help", "Show this message.") do
      puts opts
      exit
    end

    opts.separator ""
    opts.separator "Some useful limits:"

    opts.on("-e", "--executions N", Integer, "Limit to N executions (default #{options.num_executions}).") do |n|
      options.num_executions = n
    end

    opts.on("-n", "--threads N", Integer, "Limit to N threads (default #{options.num_threads}).") do |n|
      options.num_threads = n
    end

    opts.on("-t", "--time N", Float, "Limit to N seconds (default #{options.time_limit || "-"}).") do |n|
      options.time_limit = n
    end

    opts.on("-o", "--operations N", Integer, "Limit to N operations (default #{options.operation_limit}).") do |n|
      options.operation_limit = n
    end

  end.parse!
  options
end


begin
  @options = parse_options
  @options.object = get_object(ARGV.first)

  obj_class, *args = @options.object
  tester = RandomizedTester.new

  print "Generating random #{@options.num_threads}-thread (max) executions for #{obj_class}(#{args * ", "}) "
  print "[#{"." * @options.num_executions}]"
  print "\033[<#{@options.num_executions+1}>D"

  dest_dir = File.join(DEST,"#{@options.object * "-"}")
  Dir.mkdir(dest_dir) unless Dir.exists?(dest_dir)
  idx_width = (@options.num_executions - 1).to_s.length

  @options.num_executions.times do |i|
    object = obj_class.new(*args)
    log_file = File.join(dest_dir, "#{@options.object * "-"}.#{i.to_s.rjust(idx_width,'0')}.log")

    tester.run(
      MonitoredObject.new(object, LogReaderWriter.new(log_file, object: object.class.spec)),
      @options.num_threads,
      operation_limit: @options.operation_limit,
      time_limit: @options.time_limit
    )

    print "#"
  end
  puts "]"

end

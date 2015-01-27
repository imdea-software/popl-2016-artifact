#!/usr/bin/env ruby

require_relative 'prelude'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
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
  options.destination = "examples/generated/"
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

    opts.on("-d", "--destination DIR", "Where to put the files.") do |d|
      options.destination = d
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
  options = parse_options
  options.object = get_object(ARGV.first)

  obj_class, *args = options.object
  tester = RandomizedTester.new

  puts "Generating random #{options.num_threads}-thread (max) executions for #{obj_class}(#{args * ", "}) "
  print "[#{"." * options.num_executions}]"
  print "\033[<#{options.num_executions+1}>D"

  dest_dir = File.join(options.destination, "#{options.object * "-"}")
  Dir.mkdir(dest_dir) unless Dir.exists?(dest_dir)
  idx_width = (options.num_executions - 1).to_s.length

  options.num_executions.times do |i|
    object = obj_class.create(*args)
    log_file = File.join(dest_dir, "#{options.object * "-"}.#{i.to_s.rjust(idx_width,'0')}.log")

    LogReaderWriter.new(log_file, object.class.spec) do |logger|
      tester.run(
        MonitoredObject.new(object, logger),
        options.num_threads,
        operation_limit: options.operation_limit,
        time_limit: options.time_limit
      )
    end
    print "#"
  end
  puts "]"

end

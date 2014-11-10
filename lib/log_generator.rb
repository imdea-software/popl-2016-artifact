#!/usr/bin/env ruby

require 'optparse'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'

OBJECTS = [MySyncStack, MyUnsafeStack]
DEST = "examples/generated/"

def generate(obj, file, num_threads, time_limit: nil)
  RandomizedTester.new.run(
    MonitoredObject.new(obj, LogReaderWriter.new(file, object: obj.class.spec)),
    num_threads,
    time_limit: time_limit
  )
end

@num_executions = 10
@num_threads = 7
@time_limit = 10

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE"

  opts.separator ""

  opts.on("-h", "--help", "Show this message.") do
    puts opts
    exit
  end

  opts.separator ""
  opts.separator "Some useful limits:"

  opts.on("-e", "--executions N", Integer, "Limit to N executions (default #{@num_executions}).") do |n|
    @num_executions = n
  end

  opts.on("-n", "--threads N", Integer, "Limit to N threads (default #{@num_threads}).") do |n|
    @num_threads = n
  end

  opts.on("-t", "--time N", Integer, "Limit to N seconds (default #{@time_limit}).") do |n|
    @time_limit = n
  end

end.parse!

begin
  OBJECTS.each do |obj_class|
    print "Generating random #{@num_threads}-thread executions for #{obj_class} "
    print "[#{"." * @num_executions}]"
    print "\033[<#{@num_executions+1}>D" 
    @num_executions.times do |i|
      generate(
        obj = obj_class.new,
        File.join(DEST, "#{obj}.#{i}.log"),
        @num_threads,
        time_limit: @time_limit
      )
      print "#"
    end
    puts "]"
  end
end

#!/usr/bin/env ruby

require 'optparse'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'
require_relative 'impls/scal_object'

OBJECTS = []
DEST = "examples/generated/"

# OBJECTS << MySyncStack
# OBJECTS << MyUnsafeStack
OBJECTS << [ScalObject,"msq"]
# OBJECTS << [ScalObject,"bkq"]

def generate(tester, obj, file, num_threads, time_limit: nil)
  tester.run(
    MonitoredObject.new(obj, LogReaderWriter.new(file, object: obj.class.spec)),
    num_threads,
    time_limit: time_limit
  )
end

@num_executions = 10
@num_threads = 7
@time_limit = 1

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
  @tester = RandomizedTester.new
  OBJECTS.each do |obj|
    obj_class, *args = obj
    print "Generating random #{@num_threads}-thread executions for #{obj_class}(#{args * ", "}) "
    print "[#{"." * @num_executions}]"
    print "\033[<#{@num_executions+1}>D" 
    @num_executions.times do |i|
      dest = File.join(DEST,"#{obj * "-"}")
      Dir.mkdir(dest) unless Dir.exists?(dest)
      generate(
        @tester,
        object = obj_class.new(*args),
        File.join(dest, "#{obj * "-"}.#{i}.log"),
        @num_threads,
        time_limit: @time_limit
      )
      print "#"
    end
    puts "]"
  end
end

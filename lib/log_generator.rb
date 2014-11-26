#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

require_relative 'monitored_object'
require_relative 'randomized_tester'
require_relative 'log_reader_writer'
require_relative 'impls/my_unsafe_stack'
require_relative 'impls/my_sync_stack'
require_relative 'impls/scal_object'

OBJECTS = []
DEST = "examples/generated/"

# OBJECTS << [MySyncStack]
# OBJECTS << [MyUnsafeStack]
OBJECTS << [ScalObject,"msq"]
OBJECTS << [ScalObject,"bkq"]

def generate(tester, obj, file, num_threads, time_limit: nil)
  tester.run(
    MonitoredObject.new(obj, LogReaderWriter.new(file, object: obj.class.spec)),
    num_threads,
    time_limit: time_limit
  )
end

@options = OpenStruct.new
@options.num_executions = 10
@options.num_threads = 7
@options.time_limit = 0.1

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE"

  opts.separator ""

  opts.on("-h", "--help", "Show this message.") do
    puts opts
    exit
  end

  opts.separator ""
  opts.separator "Some useful limits:"

  opts.on("-e", "--executions N", Integer, "Limit to N executions (default #{@options.num_executions}).") do |n|
    @options.num_executions = n
  end

  opts.on("-n", "--threads N", Integer, "Limit to N threads (default #{@options.num_threads}).") do |n|
    @options.num_threads = n
  end

  opts.on("-t", "--time N", Float, "Limit to N seconds (default #{@options.time_limit}).") do |n|
    @options.time_limit = n
  end

end.parse!

begin
  tester = RandomizedTester.new
  OBJECTS.each do |obj|
    obj_class, *args = obj
    print "Generating random #{@options.num_threads}-thread executions for #{obj_class}(#{args * ", "}) "
    print "[#{"." * @options.num_executions}]"
    print "\033[<#{@options.num_executions+1}>D" 
    @options.num_executions.times do |i|
      dest = File.join(DEST,"#{obj * "-"}")
      Dir.mkdir(dest) unless Dir.exists?(dest)
      generate(
        tester,
        obj_class.new(*args),
        File.join(dest, "#{obj * "-"}.#{i}.log"),
        @options.num_threads,
        time_limit: @options.time_limit
      )
      print "#"
    end
    puts "]"
  end
end

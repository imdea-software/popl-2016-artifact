require_relative 'atomic_stack'
require_relative 'my_stack'
require_relative 'synchronized_stack'
require_relative 'randomized_tester'

def generate_history(obj, log_file, num_threads: 7, time_limit: nil)
  puts "Generating random history for #{obj} with #{num_threads} threads in #{log_file}..."
  puts "(time limit set to #{time_limit}s)" if time_limit
  RandomizedTester.new.run obj,
    ConcurrentObject::LogWritingMonitor.new(log_file),
    num_threads, time_limit
  puts "Done."
end

def generate_histories(obj, n, t)
  n.times do |i|
    generate_history(obj, "example_histories/#{obj}.log.#{i}.txt", time_limit: t)
  end
end

def monitor_log(monitor, log_file)
  puts "Monitoring history from #{log_file} with #{monitor}"
  ConcurrentObject::LogReader.new(monitor).read(log_file)
end


if __FILE__ == $0

  # RandomizedTester.new.run MyStack.new, AtomicStack::Monitor.new, 7
  # generate_log(SynchronizedStack.new, 'log.txt', time_limit: 10)

  # generate_histories(SynchronizedStack.new, 10, 10)
  # generate_histories(MyStack.new, 10, 10)

  Dir.glob("example_histories/*.txt").each do |log|
    monitor_log(AtomicStack::Monitor.new, log)
  end

end

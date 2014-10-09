require_relative 'atomic_stack'
require_relative 'my_stack'
require_relative 'randomized_tester'

if __FILE__ == $0
  # RandomizedTester.new.run MyStack.new, AtomicStack::Monitor.new, 7
  # RandomizedTester.new.run MyStack.new, ConcurrentObject::LogWritingMonitor.new('log.txt'), 7
  ConcurrentObject::LogReader.new(AtomicStack::Monitor.new).read('log.txt')
end

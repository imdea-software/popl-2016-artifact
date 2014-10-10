class RandomizedTester
  MAX_DELAY = 0.1
  attr_accessor :unique_val

  def initialize
    @unique_val = 0
    @end_time = nil
  end


  def randomized_thread(obj)
    methods = obj.methods.
      reject{|m| Object.instance_methods.include? m}.
      reject{|m| obj.methods.include?("#{m.to_s.chomp('=')}=".to_sym)}

    gen = Random.new
    Thread.new do
      loop do
        break if @end_time && Time.now > @end_time
        sleep gen.rand(MAX_DELAY)
        m = obj.method(methods[gen.rand(methods.count)])
        fail "Unexpected number of arguments for method #{m.name}" if m.arity < 0
        args = m.arity.times.map { @unique_val += 1 }
        m.call(*args)
      end
    end
  end

  def run(obj, mon, num_threads, time_limit = nil)
    mon_obj = ConcurrentObject::MonitoredObject.new(obj, mon)
    @end_time = Time.now + time_limit if time_limit
    num_threads.times.map{ randomized_thread(mon_obj) }.each(&:join)
  end
end

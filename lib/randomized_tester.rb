class RandomizedTester
  MAX_DELAY = 0.1
  attr_accessor :unique_val

  def initialize
    @end_time = nil
    @unique_val = 0
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
        args = m.arity.times.map { @unique_val += 1 }
        m.call(*args)
      end
    end
  end

  def run(obj, num_threads, time_limit: nil)
    @end_time = Time.now + time_limit if time_limit
    num_threads.times.map{ randomized_thread(obj) }.each(&:join)
  end
end

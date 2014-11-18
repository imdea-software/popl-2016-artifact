class RandomizedTester
  MAX_DELAY = 0.1

  def initialize
    @unique_val = 0
    @thread_pool = []
    @object = nil
  end

  def unique_val
    @unique_val += 1
  end

  def randomized_thread
    gen = Random.new
    Thread.new do
      loop do
        Thread.stop
        loop do
          object, *methods = @object
          break unless object
          Thread.pass
          m = object.method(methods[gen.rand(methods.count)])
          args = m.arity.times.map { unique_val }
          m.call(*args)
        end
      end
    end
  end

  def run(obj, num_threads, time_limit: nil)
    $DEBUG = true
    (num_threads - @thread_pool.count).times {@thread_pool << randomized_thread}

    methods = obj.methods.
      reject{|m| Object.instance_methods.include? m}.
      reject{|m| obj.methods.include?("#{m.to_s.chomp('=')}=".to_sym)}
    @object = [obj] + methods
    @thread_pool.each {|t| t.run}
    sleep time_limit
    @object = nil
    loop until @thread_pool.all? {|t| t.status == "sleep"}
  end
end

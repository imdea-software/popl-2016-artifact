class RandomizedTester

  PASS_BOUND = 3

  def initialize
    $DEBUG = true # without this exceptions in threads are invisible
    @thread_pool = []
    @gen = Random.new
  end

  def randomized_thread
    gen = Random.new
    Thread.new do
      loop do
        Thread.stop
        loop do
          break unless @operation_count > 0
          @operation_count -= 1

          # gen.rand(PASS_BOUND).times { Thread.pass } # give others a chance

          m = @object.method(@methods[gen.rand(@methods.count)])
          args = m.arity.times.map { @unique_val += 1 }
          m.call(*args)
        end
      end
    end
  end

  def run(object, thread_count, operation_limit: Float::INFINITY, time_limit: nil)
    thread_count = @gen.rand(thread_count) + 1
    (thread_count - @thread_pool.count).times {@thread_pool << randomized_thread}

    @object = object
    @methods = object.methods.reject do |m|
      next true if Object.instance_methods.include? m
      next true if object.methods.include?("#{m.to_s.chomp('=')}=".to_sym)
      false
    end

    @unique_val = 0
    @operation_count = operation_limit

    @thread_pool.each(&:run)

    if time_limit
      sleep time_limit
      @operation_count = 0

    elsif @operation_count < Float::INFINITY
      loop while @operation_count > 0

    end
    loop until @thread_pool.all? {|t| t.status == "sleep"}
  end
end

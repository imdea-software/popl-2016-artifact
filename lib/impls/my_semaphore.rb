class MySemaphore
  include AdtImplementation
  adt_scheme :semaphore

  attr_accessor :value, :mutex
  def initialize
    @value = []
    @mutex = Mutex.new
  end

  def self.spec; "lock" end
  def to_s; "my-lock" end

  def signal(tid)
    @mutex.synchronize do
      @value << tid
      nil
    end
  end

  def wait
    @mutex.synchronize do
      if @value.empty?
        :empty
      else
        @value.pop
      end
    end
  end
end

class MyLock
  attr_accessor :holder, :mutex
  def initialize
    @holder = nil
    @mutex = Mutex.new
  end

  def self.spec; "lock" end
  def to_s; "my-lock" end

  def lock(tid)
    @mutex.synchronize do
      if @holder
        :fail
      else
        @holder = tid
        :ok
      end
    end
  end

  def unlock
    @mutex.synchronize do
      if @holder
        h = @holder
        @holder = nil
        h
      else
        nil
      end
    end
  end
end

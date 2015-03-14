class MyLock
  include AdtImplementation
  adt_scheme :lock

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
        @holder
      else
        @holder = tid
        :empty
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
        :empty
      end
    end
  end
end

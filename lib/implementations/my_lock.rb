class MyLock
  include AdtImplementation
  adt_scheme :lock

  attr_accessor :holder, :mutex

  def initialize(**options)
    @holder = nil
    @mutex = Mutex.new
  end

  def to_s; "My Lock" end

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

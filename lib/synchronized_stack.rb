class SynchronizedStack
  attr_accessor :contents, :mutex, :gen
  def initialize
    @contents = []
    @mutex = Mutex.new
    @gen = Random.new
  end
  def to_s; "Synchronized Stack" end
  def add(val)
    sleep @gen.rand(0.2)
    @mutex.synchronize { @contents.push val }
    sleep @gen.rand(0.1)
    nil
  end
  def remove
    sleep @gen.rand(0.02)
    val = @mutex.synchronize { @contents.pop }
    sleep @gen.rand(0.01)
    val || :empty
  end
end

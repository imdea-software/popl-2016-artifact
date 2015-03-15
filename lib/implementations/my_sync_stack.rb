class MySyncStack
  attr_accessor :contents, :mutex, :gen
  def initialize
    @contents = []
    @mutex = Mutex.new
    @gen = Random.new
  end
  def self.spec; "atomic-stack" end
  def to_s; "my-sync-stack" end
  def push(val)
    sleep @gen.rand(0.2)
    @mutex.synchronize { @contents.push val }
    sleep @gen.rand(0.1)
    nil
  end
  def pop
    sleep @gen.rand(0.02)
    val = @mutex.synchronize { @contents.pop }
    sleep @gen.rand(0.01)
    val || :empty
  end
end

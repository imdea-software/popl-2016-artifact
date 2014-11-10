class MyUnsafeStack
  attr_accessor :contents, :gen
  def initialize
    @contents = []
    @gen = Random.new
  end
  def self.spec; "atomic-stack" end
  def to_s; "my-unsafe-stack" end
  def push(val)
    sleep @gen.rand(0.2)
    @contents.push val
    sleep @gen.rand(0.1)
    nil
  end
  def pop
    sleep @gen.rand(0.02)
    val = @contents.pop
    sleep @gen.rand(0.01)
    val || :empty
  end
end

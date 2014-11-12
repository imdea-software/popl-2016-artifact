class Cell
  attr_accessor :value
  attr_accessor :next
  def initialize(val, n)
    @value = val
    @next = n
  end
end

class MyUnsafeStack
  attr_accessor :contents, :gen
  def initialize
    @top = nil
    @gen = Random.new
  end
  def self.spec; "atomic-stack" end
  def to_s; "my-unsafe-stack" end
  def push(val)
    sleep @gen.rand(0.2)
    t = Cell.new(val, @top)
    sleep @gen.rand(0.1)
    @top = t
    sleep @gen.rand(0.1)
    nil
  end
  def pop
    sleep @gen.rand(0.02)
    if t = @top
      val = t.value
    sleep @gen.rand(0.01)
      @top = t.next
    else
      val = :empty
    end
    sleep @gen.rand(0.01)
    val
  end
end

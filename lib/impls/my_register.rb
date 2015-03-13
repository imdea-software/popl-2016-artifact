class MyRegister
  attr_accessor :value, :mutex
  def initialize
    @value = nil
    @mutex = Mutex.new
  end

  def self.spec; "atomic-register" end
  def to_s; "my-register" end

  def write(value)
    @mutex.synchronize do
      @value = value
      nil
    end
  end

  def read
    @mutex.synchronize do
      @value
    end
  end
end

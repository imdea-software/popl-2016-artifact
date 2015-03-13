class MySet
  attr_accessor :values, :mutex
  def initialize
    @values = Set.new
    @mutex = Mutex.new
  end

  def self.spec; "atomic-set" end
  def to_s; "my-set" end

  def insert(value)
    @mutex.synchronize do
      @values.add(value)
      nil
    end
  end

  def contains(value)
    @mutex.synchronize do
      @values.include?(value)
    end
  end

  def remove(value)
    @mutex.synchronize do
      @values.delete(value)
      nil
    end
  end
end

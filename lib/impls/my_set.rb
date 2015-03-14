class MySet
  include AdtImplementation
  adt_scheme :set

  attr_accessor :values, :mutex
  def initialize
    @values = Set.new
    @mutex = Mutex.new
  end

  def self.spec; "atomic-set" end
  def to_s; "my-set" end

  def insert(value)
    @mutex.synchronize do
      if @values.include?(value)
        value
      else
        @values.add(value)
        :empty
      end
    end
  end

  def contains(value)
    @mutex.synchronize do
      if @values.include?(value)
        value
      else
        :empty
      end
    end
  end

  def remove(value)
    @mutex.synchronize do
      if @values.include?(value)
        @values.delete(value)
        value
      else
        :empty
      end
    end
  end
end

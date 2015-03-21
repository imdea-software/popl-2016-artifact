class MyRegister
  include AdtImplementation
  adt_scheme :register

  attr_accessor :value, :mutex

  def initialize(**options)
    @value = nil
    @mutex = Mutex.new
  end

  def to_s; "My Register" end

  def write(value)
    @mutex.synchronize do
      @value = value
      nil
    end
  end

  def read
    @mutex.synchronize do
      @value || :empty
    end
  end
end

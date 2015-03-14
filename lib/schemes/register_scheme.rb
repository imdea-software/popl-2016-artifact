class RegisterScheme < Scheme

  def initialize
    @value_limit = 1
  end

  def adt_methods
    [:write, :read]
  end

  def match?(history, x, y)
    history.method_name(x) == :write && x == y ||
    history.method_name(x) == :write &&
    history.method_name(y) == :read &&
    history.arguments(x) == history.returns(y)
  end

  def generate_arguments(method_name)
    case method_name
    when :write
      @value_limit += 1
      [[@value_limit-1]]
    else
      [[]]
    end
  end

  def generate_returns(method_name)
    case method_name
    when :read
      (@value_limit.times.to_a + [:empty]).map{|v| [v]}
    else
      [[]]
    end
  end

end

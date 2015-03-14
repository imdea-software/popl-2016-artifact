class SemaphoreScheme < Scheme

  def initialize
    @value_limit = 1
  end

  def adt_methods
    [:signal, :wait]
  end

  def match?(history, x, y)
    history.method_name(x) == :signal && x == y ||
    history.method_name(x) == :wait && x == y && history.returns(x) == [:empty] ||
    history.method_name(x) == :signal &&
    history.method_name(y) == :wait &&
    history.arguments(x) == history.returns(y)
  end

  def generate_arguments(method_name)
    case method_name
    when :signal
      @value_limit += 1
      [[@value_limit-1]]
    else
      [[]]
    end
  end

  def generate_returns(method_name)
    case method_name
    when :wait
      (@value_limit.times.to_a + [:empty]).map{|v| [v]}
    else
      [[]]
    end
  end

end

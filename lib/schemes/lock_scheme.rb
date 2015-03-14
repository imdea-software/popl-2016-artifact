class LockScheme < Scheme

  def initialize
    @value_limit = 1
  end

  def adt_methods
    [:lock, :unlock]
  end

  def match?(history, x, y)
    x == y && history.returns(x) == [:empty] ||
    history.method_name(x) == :lock && history.arguments(x) == history.returns(y)
  end

  def generate_arguments(method_name)
    case method_name
    when :lock
      @value_limit += 1
      @value_limit.times.to_a.reject{|v| v == 0}.map{|v| [v]}
    else
      [[]]
    end
  end

  def generate_returns(method_name)
    (@value_limit.times.to_a + [:empty]).map{|v| [v]}
  end

end

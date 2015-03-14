class SetScheme < Scheme

  def initialize
    @value_limit = 1
  end

  def adt_methods
    [:insert, :remove, :contains]
  end

  def match?(history, x, y)
    x == y && history.returns(x) == [:empty] ||
    x != y && history.method_name(x) == :insert && history.arguments(x) == history.returns(y)
  end

  def generate_arguments(method_name)
    @value_limit += 1 if method_name == :insert
    @value_limit.times.to_a.reject{|v| v == 0 && method_name == :insert}.map{|v| [v]}
  end

  def generate_returns(method_name)
    (@value_limit.times.to_a + [:empty]).map{|v| [v]}
  end
end

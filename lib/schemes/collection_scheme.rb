class CollectionScheme < Scheme

  def initialize
    @value_limit = 1
  end

  def adt_methods
    [:add, :remove]
  end

  def normalize(method_name)
    case method_name
    when :add, :push, :enqueue
      :add
    when :remove, :pop, :dequeue
      :remove
    end
  end

  def match?(history, x, y)
    normalize(history.method_name(x)) == :add && x == y ||
    normalize(history.method_name(x)) == :remove && x == y && history.returns(y) == [:empty] ||
    normalize(history.method_name(x)) == :add &&
    normalize(history.method_name(y)) == :remove &&
    history.arguments(x) == history.returns(y)
  end

  def generate_arguments(method_name)
    case method_name
    when :add
      @value_limit += 1
      [[@value_limit-1]]
    else
      [[]]
    end
  end

  def generate_returns(method_name)
    case method_name
    when :remove
      (@value_limit.times.to_a + [:empty]).map{|v| [v]}
    else
      [[]]
    end
  end

end

class CollectionScheme < Scheme

  def initialize
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

  def generate_arguments(history, method_name)
    case normalize(method_name)
    when :add
      [[(history.argument_values | [0]).select{|v| v.is_a?(Fixnum)}.max + 1]]
    else
      [[]]
    end
  end

  def generate_returns(history, method_name, smart: false)
    case normalize(method_name)
    when :remove
      values = history.argument_values
      values -= history.return_values if smart
      values |= [(values|[0]).select{|v| v.is_a?(Fixnum)}.max + 1] unless smart
      values |= [:empty]
      values.map{|v| [v]}
    else
      [[]]
    end
  end

end

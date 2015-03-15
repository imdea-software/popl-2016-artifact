class SemaphoreScheme < Scheme

  def initialize
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

  def generate_arguments(history, method_name)
    case method_name
    when :signal
      [[(history.argument_values | [0]).select{|v| v.is_a?(Fixnum)}.max + 1]]
    else
      [[]]
    end
  end

  def generate_returns(history, method_name, smart: false)
    case method_name
    when :wait
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

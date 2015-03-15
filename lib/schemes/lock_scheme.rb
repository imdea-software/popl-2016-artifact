class LockScheme < Scheme

  def initialize
  end

  def adt_methods
    [:lock, :unlock]
  end

  def match?(history, x, y)
    x == y && history.returns(x) == [:empty] ||
    history.method_name(x) == :lock && history.arguments(x) == history.returns(y)
  end

  def generate_arguments(history, method_name)
    case method_name
    when :lock
      [[(history.argument_values | [0]).select{|v| v.is_a?(Fixnum)}.max + 1]]
    else
      [[]]
    end
  end

  def generate_returns(history, method_name, smart: false)
    values = history.argument_values
    values -= history.return_values if smart
    values |= [(values|[0]).select{|v| v.is_a?(Fixnum)}.max + 1] unless smart
    values |= [:empty]
    values.map{|v| [v]}
  end

end

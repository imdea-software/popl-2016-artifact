class SetScheme < Scheme

  def initialize
  end

  def adt_methods
    [:insert, :remove, :contains]
  end

  def match?(history, x, y)
    x == y && history.returns(x) == [:empty] ||
    x != y && history.method_name(x) == :insert && history.arguments(x) == history.returns(y)
  end

  def generate_arguments(history, method_name)
    values = (history.argument_values).select{|v| v.is_a?(Fixnum)}
    case method_name
    when :insert
      [[(values|[0]).max + 1]]
    else
      values |= [(values|[0]).max + 1]
      values.map{|v| [v]}
    end
  end

  def generate_returns(history, method_name, smart: false)
    values = history.argument_values
    values |= [(values|[0]).select{|v| v.is_a?(Fixnum)}.max + 1] unless smart
    values |= [:empty]
    values.map{|v| [v]}
  end
end
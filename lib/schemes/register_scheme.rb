class RegisterScheme < Scheme

  def initialize
  end

  def adt_methods
    [:write, :read]
  end

  def read_only?(history, id)
    history.method_name(id) == :read
  end

  def match?(history, x, y)
    history.method_name(x) == :write && x == y ||
    history.method_name(x) == :read && x == y && history.returns(x) == [:empty] ||
    history.method_name(x) == :write &&
    history.method_name(y) == :read &&
    history.arguments(x) == history.returns(y)
  end

  def generate_arguments(history, method_name)
    case method_name
    when :write
      [[(history.argument_values | [0]).select{|v| v.is_a?(Fixnum)}.max + 1]]
    else
      [[]]
    end
  end

  def generate_returns(history, method_name, smart: false)
    case method_name
    when :read
      values = history.argument_values
      values |= [(values|[0]).select{|v| v.is_a?(Fixnum)}.max + 1] unless smart
      values |= [:empty]
      values.map{|v| [v]}
    else
      [[]]
    end
  end

end

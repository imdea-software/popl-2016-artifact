class WorkStealingQueueScheme < Scheme

  def initialize
  end

  def adt_methods
    [:give, :take, :steal]
  end

  def read_only?(history,id)
    case history.method_name(id)
    when :take, :steal
      history.returns(id) == [:empty]
    else
      false
    end
  end

  def match?(history, x, y)
    history.method_name(x) == :give && x == y ||
    history.method_name(x) != :give && x == y && history.returns(y) == [:empty] ||
    history.method_name(x) == :give &&
    history.method_name(y) != :give &&
    history.arguments(x) == history.returns(y)
  end

  def generate_arguments(history, method_name)
    case method_name
    when :give
      [[(history.argument_values | [0]).select{|v| v.is_a?(Fixnum)}.max + 1]]
    else
      [[]]
    end
  end

  def generate_returns(history, method_name, smart: false)
    case method_name
    when :take, :steal
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

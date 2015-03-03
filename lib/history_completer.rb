module HistoryCompleter

  def self.get(object)
    case object
    when /lock/
      Proc.new do |history, id|
        case history.method_name(id)
        when /unlock/
          locked = history.map{|id| history.arguments(id)}.flatten(1)
          unlocked = history.map{|id| history.returns(id) || []}.flatten(1).reject{|v| v == :ok || v == :fail}
          ([[]] + locked - unlocked).map{|v| [v]}
        when /lock/
          [[:ok], [:fail]]
        else
          fail "I don’t know how to complete #{history.method_name(id)} methods."
        end
      end
    when /atomic-(stack|queue)/
      Proc.new do |history, id|
        case history.method_name(id)
        when /add|push|enqueue/
          [[]]
        when /rm|remove|pop|dequeue/
          added_values = history.map{|id| history.arguments(id)}.flatten(1)
          removed_values = history.map{|id| history.returns(id)||[]}.flatten(1)
          ([:empty] + added_values - removed_values).map{|v| [v]}
        else
          fail "I don’t know how to complete #{history.method_name(id)} methods."
        end
      end
    else
      fail "I don’t know how to complete #{object} operations."
    end
  end

end
  
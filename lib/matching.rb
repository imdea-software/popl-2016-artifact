require 'set'

module Matching
  ADD_PATTERN = /add|put|push|enqueue/
  REM_PATTERN = /rem|get|pop|dequeue/

  # TODO this predicate will be an input…
  def self.collection_match?(history,x,y)
    history.method_name(x) =~ ADD_PATTERN &&
    history.method_name(y) =~ REM_PATTERN &&
    history.arguments(x) == history.returns(y) ||
    history.method_name(x) =~ ADD_PATTERN && x == y
  end

  def self.get(history,id)

    # TODO replace what follows with this one generic line…
    # history.find {|m| self.collection_match?(history,m,id)}

    case history.method_name(id)
    when ADD_PATTERN
      id
    when REM_PATTERN
      if history.returns(id).nil?
        nil
      elsif history.returns(id).first == :empty
        id
      else
        history.find do |a|
          history.method_name(a) =~ ADD_PATTERN &&
          history.arguments(a) == history.returns(id)
        end
      end
    else
      nil
    end

  end
end

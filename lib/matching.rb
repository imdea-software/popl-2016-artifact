require 'set'

module Matching
  ADD_PATTERN = /add|put|push|enqueue/
  REM_PATTERN = /rem|get|pop|dequeue/

  # TODO this predicate will be an input…
  def self.collection_match?(history,x,y)
    history.method_name(x) =~ ADD_PATTERN && x == y ||
    history.method_name(x) =~ REM_PATTERN && x == y && history.returns(y) == [:empty] ||
    history.method_name(x) =~ ADD_PATTERN &&
    history.method_name(y) =~ REM_PATTERN &&
    history.arguments(x) == history.returns(y)
  end

  def self.get(history,id)

    return history.find {|m| self.collection_match?(history,m,id)}

  end
end

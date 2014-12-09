require 'set'

module Matching
  ADD_PATTERN = /add|put|push|enqueue/
  REM_PATTERN = /rem|get|pop|dequeue/

  def self.get(history,id)
    case history.method_name(id)
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

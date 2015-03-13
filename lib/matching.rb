require 'set'

module Matching
  ADD_PATTERN = /\A(add|put|push|enqueue)\Z/
  REM_PATTERN = /\A(rem|get|pop|dequeue)\Z/

  ACQ_PATTERN = /\A(lock|acquire)\Z/
  REL_PATTERN = /\A(unlock|release)\Z/

  INSERT_PATTERN = /\Ainsert\Z/
  REMOVE_PATTERN = /\Aremove\Z/
  CONTAINS_PATTERN = /\Acontains\Z/

  WRITE_PATTERN = /\Astore|write\Z/
  READ_PATTERN = /\Aload|read\Z/

  SIGNAL_PATTERN = /\Asignal\Z/
  WAIT_PATTERN = /\Await\Z/

  # TODO this predicate will be an input…
  def self.collection_match?(history,x,y)
    history.method_name(x) =~ ADD_PATTERN && x == y ||
    history.method_name(x) =~ REM_PATTERN && x == y && history.returns(y) == [:empty] ||
    history.method_name(x) =~ ADD_PATTERN &&
    history.method_name(y) =~ REM_PATTERN &&
    history.arguments(x) == history.returns(y)
  end

  def self.register_match?(history,x,y)
    history.method_name(x) =~ WRITE_PATTERN && x == y ||
    history.method_name(x) =~ WRITE_PATTERN &&
    history.method_name(y) =~ READ_PATTERN &&
    history.arguments(x) == history.returns(y)
  end

  def self.set_match?(history,x,y)
    history.method_name(x) =~ INSERT_PATTERN && x == y ||
    history.method_name(x) =~ CONTAINS_PATTERN && x == y && history.returns(x) == [false] ||
    history.method_name(x) =~ INSERT_PATTERN &&
    history.method_name(y) =~ /#{REMOVE_PATTERN}|#{CONTAINS_PATTERN}/ &&
    history.arguments(x) == history.arguments(y) &&
    [[true], []].include?(history.returns(y))
  end

  def self.lock_match?(history,x,y)
    history.method_name(x) =~ ACQ_PATTERN && x == y && history.returns(x) == [:empty] ||
    history.method_name(x) =~ REL_PATTERN && x == y && history.returns(x) == [:empty] ||
    history.method_name(x) =~ ACQ_PATTERN &&
    history.method_name(y) =~ /#{ACQ_PATTERN}|#{REL_PATTERN}/ &&
    history.arguments(x) == history.returns(y)
  end

  def self.semaphore_match?(history,x,y)
    history.method_name(x) =~ SIGNAL_PATTERN && x == y ||
    history.method_name(x) =~ WAIT_PATTERN && x == y && history.returns(x) == [:empty] ||
    history.method_name(x) =~ SIGNAL_PATTERN &&
    history.method_name(y) =~ WAIT_PATTERN &&
    history.arguments(x) == history.returns(y)
  end

  def self.get(history,id)
    history.find do |m|
      case history.method_name(id)
      when ADD_PATTERN, REM_PATTERN
        self.collection_match?(history,m,id)
      when WRITE_PATTERN, READ_PATTERN
        self.register_match?(history,m,id)
      when INSERT_PATTERN, REMOVE_PATTERN, CONTAINS_PATTERN
        self.set_match?(history,m,id)
      when SIGNAL_PATTERN, WAIT_PATTERN
        self.semaphore_match?(history,m,id)
      when ACQ_PATTERN, REL_PATTERN
        self.lock_match?(history,m,id)
      else
        fail "Unexpected method name: #{history.method_name(id)}"
      end
    end
  end

  def self.good_argument_values(method_name, domain)
    used_numbers = [0] + domain.select{|i| i.is_a?(Fixnum)}
    case method_name
    when ADD_PATTERN, WRITE_PATTERN, SIGNAL_PATTERN, ACQ_PATTERN
      [[ used_numbers.max + 1 ]]
    when INSERT_PATTERN, REMOVE_PATTERN, CONTAINS_PATTERN
      used_numbers.map{|i| [i]} + [[ used_numbers.max + 1 ]]
    when REM_PATTERN, READ_PATTERN, WAIT_PATTERN, REL_PATTERN
      [[]]
    else
      fail "Unexpected method name: #{method_name}"
    end
  end

  def self.possible_return_values(method_name, args, domain)
    domain = [0] + domain
    case method_name
    when ADD_PATTERN
      []
    when REM_PATTERN
      domain + [:empty]
    when WRITE_PATTERN
      []
    when READ_PATTERN
      domain
    when INSERT_PATTERN
      []
    when REMOVE_PATTERN
      []
    when CONTAINS_PATTERN
      [true, false]
    when SIGNAL_PATTERN
      []
    when WAIT_PATTERN
      domain + [:empty]
    when ACQ_PATTERN
      domain - args + [:empty]
    when REL_PATTERN
      domain + [:empty]
    else
      fail "Unexpected method name: #{method_name}"
    end
  end
end

require_relative 'history.rb'
require_relative 'theories.rb'
require_relative 'z3.rb'

class LineUpChecker
  include Z3
  extend Theories
  include BasicTheories
  include CollectionTheories

  def initialize
    @solver = Z3.context.solver
    @solver.theory basic_theory
    @solver.theory collection_theory
    @solver.theory lifo_theory
  end

  theory :ground_theory do |history,seq,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}
    vals.each {|v| t.yield v, :value}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})"
    t.yield "(distinct #{vals * " "})"

    seq.each_with_index do |id,idx|
      arg = history.arguments(id).first
      ret = history.returns(id).first
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      t.yield "(= (arg o#{id}) #{arg})" if arg
      t.yield "(= (ret o#{id}) #{ret})" if ret
      seq.drop(idx+1).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  def check(history)
    num_checked = 0
    sat = false
    log.debug('LineUp') {"checking linearizations of history\n#{history}"}
    history.linearizations.each do |seq|
      log.debug('LineUp') {"checking linearization #{seq * ", "}"}
      @solver.push
      @solver.theory ground_theory(history,seq)
      sat = @solver.check
      num_checked += 1
      @solver.pop
      break if sat
    end
    log.debug('LineUp') {"checked #{num_checked} linearizations: #{sat ? "OK" : "violation"}"}
    return sat
  end

end
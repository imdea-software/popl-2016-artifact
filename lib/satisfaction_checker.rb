require_relative 'history.rb'
require_relative 'theories.rb'
require_relative 'z3.rb'

class SatisfactionChecker
  include Z3
  extend Theories
  include BasicTheories
  include CollectionTheories

  def initialize
    @solver = Z3.context.solver
    @solver.debug = true
    @solver.theory basic_theory
    @solver.theory collection_theory
    @solver.theory lifo_theory
  end

  theory :ground_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}
    vals.each {|v| t.yield v, :value}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})"
    t.yield "(distinct #{vals * " "})"

    history.each do |id|
      arg = history.arguments(id).first
      ret = history.returns(id).first
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      t.yield "(= (arg o#{id}) #{arg})" if arg
      t.yield "(= (ret o#{id}) #{ret})" if ret
      history.after(id).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  def check(history)
    @solver.push
    @solver.theory ground_theory(history)
    res = @solver.check
    @solver.pop
    res
  end

end

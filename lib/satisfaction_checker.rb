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
    @solver.theory basic_theory
    @solver.theory collection_theory
    @solver.theory lifo_theory
  end

  def to_s
    "SMT checker (Z3)"
  end

  theory :ground_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}
    vals.each {|v| t.yield "v#{v}".to_sym, :value unless v == :empty}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1

    # TODO this code should not depend the collection theory
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

    # TODO this code should not depend the collection theory
    # TODO THE FOLLOWING IS UNSOUND... PENDING POPS MIGHT RETURN THAT VALUE
    # vals.each.reject do |v|
    #   v == :empty ||
    #   ops.any? {|id| history.returns(id) && history.returns(id).include?(v)}
    # end.each {|v| t.yield "(not (popped v#{v}))"}

    history.each do |id|
      args = history.arguments(id)
      rets = history.returns(id) || []
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      args.each_with_index {|x,idx| t.yield "(= (arg o#{id} #{idx}) v#{x})"}
      rets.each_with_index {|x,idx| t.yield "(= (ret o#{id} #{idx}) v#{x})"}
      history.after(id).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  def check(history)
    log.info('theory-checker') {"checking history\n#{history}"}
    @solver.push
    @solver.theory ground_theory(history)
    res = @solver.check
    @solver.pop
    log.info('theory-checker') {"result: #{res ? "OK" : "violation"}"}
    res
  end

end

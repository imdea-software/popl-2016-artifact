require_relative 'history'
require_relative 'history_checker'
require_relative 'theories'
require_relative 'z3'

class SatisfactionChecker < HistoryChecker
  include Z3
  extend Theories
  include BasicTheories
  include CollectionTheories

  def initialize(object, history, incremental)
    super(object, history, incremental)
    @solver = Z3.context.solver
    @solver.theory basic_theory
    case @object
    when 'atomic-stack'
      @solver.theory collection_theory
      @solver.theory lifo_theory
    when 'atomic-queue'
      @solver.theory collection_theory
      @solver.theory fifo_theory
    end
    @needs_refresh = true
  end

  def name; "SMT checker (Z3)" end

  def removed!(id); @needs_refresh = true end
  def refresh?;     @needs_refresh end
  def refresh!;     @needs_refresh = false end

  # TODO implement the incremental version
  def started!(m, *values)
  end
  def completed!(id, *values)
  end

  theory :ground_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}

    # TODO this code should not depend the collection theory
    vals.each {|v| t.yield "v#{v}".to_sym, :value unless v == :empty}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(forall ((x id)) (or #{ops.map{|id| "(= x o#{id})"} * " "}))"
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

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

  def check()
    super()
    log.info('theory-checker') {"checking history\n#{@history}"}
    @solver.push
    @solver.theory ground_theory(@history)
    sat = @solver.check
    @solver.pop
    log.info('theory-checker') {"result: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end

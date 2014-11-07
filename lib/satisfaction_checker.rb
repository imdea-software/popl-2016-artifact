require_relative 'history'
require_relative 'history_checker'
require_relative 'theories'
require_relative 'z3'

class SatisfactionChecker < HistoryChecker
  include Z3
  extend Theories
  include BasicTheories

  def initialize(object, history, completion, incremental)
    super(object, history, completion, incremental)
    @solver = Z3.context.solver
    theories_for(object).each {|t| @solver.theory t}
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
    vals.reject{|v| v == :empty}.each {|v| t.yield "v#{v}".to_sym, :value}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(forall ((x id)) (or #{ops.map{|id| "(= x o#{id})"} * " "}))" if ops.count > 1
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

    # TODO this code should not depend the collection theory
    if history.complete?
      unremoved =
        history.map{|id| history.arguments(id)}.flatten(1) -
        history.map{|id| history.returns(id)||[]}.flatten(1)
      unremoved.each {|v| t.yield "(not (removed v#{v}))"}
    end

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

  def check_history(history)
    @solver.push
    @solver.theory ground_theory(@history)
    sat = @solver.check
    @solver.pop
    return [sat, 1]
  end

  def check_completions(history)
    num_checked = 0
    sat = false
    history.completions(HistoryCompleter.get(@object)).each do |complete_history|
      log.info('theory-checker') {"checking completion\n#{complete_history}"}
      sat, _ = check_history(complete_history)
      num_checked += 1
      break if sat
    end
    return [sat, num_checked]
  end

  def check()
    super()
    log.info('theory-checker') {"checking history\n#{@history}"}
    sat, _ = @completion ? check_completions(@history) : check_history(@history)
    log.info('theory-checker') {"result: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end

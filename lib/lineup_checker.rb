require_relative 'history'
require_relative 'history_checker'
require_relative 'theories'
require_relative 'z3'

class LineUpChecker < HistoryChecker
  include Z3
  extend Theories
  include BasicTheories

  @@do_completion = true

  def initialize(object, history, incremental)
    super(object, history, incremental)
    @solver = Z3.context.solver
    theories_for(object).each {|t| @solver.theory t}
  end

  def name; "Line-Up checker" end

  theory :ground_theory do |history,seq,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}

    # TODO this code should not depend the collection theory
    vals.reject{|v| v == :empty}.each {|v| t.yield "v#{v}".to_sym, :value}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(forall ((x id)) (or #{ops.map{|id| "(= x o#{id})"} * " "}))" if ops.count > 1
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

    # TODO this code should not depend the collection theory
    # TODO THE FOLLOWING IS ONLY SOUND FOR COMPLETE HISTORIES
    if @@do_completion
      unremoved =
        history.map{|id| history.arguments(id)}.flatten(1) -
        history.map{|id| history.returns(id)||[]}.flatten(1)
      unremoved.each {|v| t.yield "(not (removed v#{v}))"}
    end

    seq.each_with_index do |id,idx|
      args = history.arguments(id)
      rets = history.returns(id) || []
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      args.each_with_index {|x,idx| t.yield "(= (arg o#{id} #{idx}) v#{x})"}
      rets.each_with_index {|x,idx| t.yield "(= (ret o#{id} #{idx}) v#{x})"}
      seq.drop(idx+1).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  def completer(history,id)
    case @object
    when /atomic-(stack|queue)/
      ([:empty] +
        history.map{|id| history.arguments(id)}.flatten(1) -
        history.map{|id| history.returns(id)||[]}.flatten(1)).map{|v| [v]}
    else
      log.error('LineUp') {"I don't know how to complete #{@object} operations."}
    end
  end

  def check_completions(history)
    num_checked = 0
    sat = false
    history.completions(method(:completer)).each do |complete_history|
      log.info('LineUp') {"checking completion\n#{complete_history}"}
      sat, n = check_linearizations(complete_history)
      num_checked += n
      break if sat
    end
    return [sat, num_checked]
  end

  def check_linearizations(history)
    num_checked = 0
    sat = false
    history.linearizations.each do |seq|
      log.info('LineUp') {"checking linearization\n#{seq.map{|id| history.label(id)} * ", "}"}
      @solver.push
      @solver.theory ground_theory(history,seq)
      sat = @solver.check
      num_checked += 1
      @solver.pop
      break if sat
    end
    return [sat, num_checked]
  end

  def check()
    super()
    sat = false
    log.info('LineUp') {"checking linearizations of history\n#{@history}"}
    sat, n = @@do_completion ? check_completions(@history) : check_linearizations(@history)
    log.info('LineUp') {"checked #{n} linearizations: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end
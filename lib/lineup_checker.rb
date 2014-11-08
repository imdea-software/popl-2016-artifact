require_relative 'history'
require_relative 'history_checker'
require_relative 'history_completer'
require_relative 'theories'
require_relative 'z3'

class LineUpChecker < HistoryChecker
  include Z3
  extend Theories
  include BasicTheories

  def initialize(object, history, completion, incremental)
    super(object, history, completion, incremental)
    @solver = Z3.context.solver
    theories_for(object).each(&@solver.method(:theory))
    log.warn('LineUp') {"I don't have an incremental mode."} if @incremental
  end

  def name; "Line-Up checker" end

  def check_sequential_history(history,seq)
    @solver.push
    @solver.theory seq_history_ops_theory(history,seq)
    @solver.theory history_domains_theory(history)
    sat = @solver.check
    @solver.pop
    return [sat,1]
  end

  def check_linearizations(history)
    num_checked = 0
    sat = false
    history.linearizations.each do |seq|
      log.info('LineUp') {"checking linearization\n#{seq.map{|id| history.label(id)} * ", "}"}
      sat, n = check_sequential_history(history,seq)
      num_checked += n
      break if sat
    end
    return [sat, num_checked]
  end

  def check_completions(history)
    num_checked = 0
    sat = false
    history.completions(HistoryCompleter.get(@object)).each do |complete_history|
      log.info('LineUp') {"checking completion\n#{complete_history}"}
      sat, n = check_linearizations(complete_history)
      num_checked += n
      break if sat
    end
    return [sat, num_checked]
  end

  def check()
    super()
    log.info('LineUp') {"checking linearizations of history\n#{@history}"}
    sat, n = @completion ? check_completions(@history) : check_linearizations(@history)
    log.info('LineUp') {"checked #{n} linearizations: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end
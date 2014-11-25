require_relative 'history'
require_relative 'history_checker'
require_relative 'history_completer'
require_relative 'theories'
require_relative 'z3'

class SymbolicChecker < HistoryChecker
  include Z3

  def initialize(*args)
    super(*args)

    context = Z3.context
    @theories = Theories.new(context)

    # THE EASY WAY
    @solver = context.solver
    @theories.theory(object).each(&@solver.method(:assert))

    # THE LONG WAY...
    # @configuration = Z3.config
    # # configuration.set("timeout","10")
    # # configuration.set("model","true")
    # @context = Z3.context(config: @configuration)
    # @solver = @context.solver

    # params = Z3.context.params
    # params.set("max_conflicts",0)
    # @solver.set_params(params)

    log.warn('Symbolic') {"I don't know how to handle incremental AND completion!"} \
      if incremental && completion

    @solver.push if incremental
    @removed = false
  end

  def name; "Symbolic checker (Z3)" end

  def started!(id, method_name, *arguments)
    return unless incremental
    @theories.called(id,history).each(&@solver.method(:assert))
  end

  def completed!(id, *returns)
    return unless incremental
    @theories.returned(id,history).each(&@solver.method(:assert))
  end

  def removed!(id)
    @removed = true
  end

  def refresh
    return unless incremental
    @solver.pop
    @solver.push
    @theories.history(history).each(&@solver.method(:assert))
    @removed = false
  end

  def check_history(history)
    refresh if @removed

    @solver.push
    if incremental then @theories.domains(history)
    else                @theories.history(history)
    end.each(&@solver.method(:assert))
    sat = @solver.check
    @solver.pop
    return sat
  end

  def check()
    super()
    sat = false
    log.info('Symbolic') {"checking history\n#{history}"}

    if completion then history.completions(HistoryCompleter.get(object))
    else [history]
    end.each do |h|
      log.info('Symbolic') {"checking completion\n#{h}"} if completion
      break if (sat = check_history(h))
    end

    log.info('Symbolic') {"result: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end

require_relative 'history'
require_relative 'history_checker'
require_relative 'history_completer'
require_relative 'theories'
require_relative 'z3'

class EnumerateChecker < HistoryChecker
  include Z3

  def initialize(options)
    super(options)

    configuration = Z3.config
    context = Z3.context(config: configuration)
    @solver = context.solver

    if options[:time_limit]
      # TODO come on Z3 give me a break!!
      Z3.global_param_set("timeout", options[:time_limit].to_s)
      configuration.set("timeout", options[:time_limit])
      parameters = context.params
      parameters.set("soft_timeout", options[:time_limit])
      @solver.set_params(parameters)
    end

    @theories = Theories.new(context)

    log.warn('Enumerate') {"I don't have an incremental mode."} if incremental
  end

  def name; "Enumerate checker" end

  def check_history(history, seq)
    @theories.theory(object).each(&@solver.method(:assert))
    @theories.history(history, order: seq).each(&@solver.method(:assert))
    sat = @solver.check
    @solver.reset
    return sat
  end

  def check()
    super()
    sat = false
    num_checked = 0
    log.info('Enumerate') {"checking linearizations of history\n#{history}"}

    if completion then history.completions(HistoryCompleter.get(object))
    else [history]
    end.each do |h|
      log.info('Enumerate') {"checking completion\n#{h}"} if completion

      h.linearizations.each do |seq|
        log.info('Enumerate') {"checking linearization\n#{seq.map(&h.method(:label)) * ", "}"}
        sat = check_history(h,seq)
        num_checked += 1
        break if sat
      end

      break if sat
    end

    log.info('Enumerate') {"checked #{num_checked} linearizations: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end
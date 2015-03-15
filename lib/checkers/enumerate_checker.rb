class EnumerateChecker < HistoryChecker
  include Z3

  attr_reader :reference_impl

  def initialize(options)
    super(options)

    configuration = Z3.config
    context = Z3.context(config: configuration)
    @solver = context.solver

    if options[:time_limit]
      # TODO come on Z3 give me a break!!
      Z3.global_param_set("timeout", options[:time_limit].to_s)
      configuration.set("timeout", options[:time_limit])
    end

    @theories = Theories.new(context)

    log.warn('Enumerate') {"I don't have an incremental mode."} if incremental
  end

  def name; "Enumerate" end

  def kernel_contains?(history, seq)
    if reference_impl
      object = reference_impl.call()
      seq.all? do |op|
        rets = object.send(history.method_name(op), *history.arguments(op))
        # TODO make this more consistent
        rets ||= []
        rets = [rets] unless rets.is_a?(Array)
        rets == history.returns(op)
      end

    elsif @solver
      @theories.theory(adt).each(&@solver.method(:assert))
      @theories.history(history, order: seq).each(&@solver.method(:assert))
      sat = @solver.check
      @solver.reset
      sat

    else
      log.fatal('Enumerate') {"I don't have a checker"}
      exit
    end
  end

  def linearizable?(history)
    ok = false
    num_checked = 0
    log.info('Enumerate') {"checking linearizations of history\n#{history}"}

    if completion then history.completions else [history] end.each do |h|
      log.info('Enumerate') {"checking completion\n#{h}"} if completion

      h.linearizations.each do |seq|
        log.info('Enumerate') {"checking linearization\n#{seq.map(&h.method(:label)) * ", "}"}
        ok = kernel_contains?(h,seq)
        num_checked += 1
        break if ok
      end

      break if ok
    end

    log.info('Enumerate') {"checked #{num_checked} linearizations: #{ok ? "OK" : "violation"}"}
    return ok
  end

  def check()
    super()
    flag_violation unless linearizable?(history)
  end

end
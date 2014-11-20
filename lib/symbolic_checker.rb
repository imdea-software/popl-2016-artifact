require_relative 'history'
require_relative 'history_checker'
require_relative 'history_completer'
require_relative 'theories'
require_relative 'z3'

class SymbolicChecker < HistoryChecker
  include Z3

  def initialize(object, matcher, history, completion, incremental, opts)
    super(object, matcher, history, completion, incremental, opts)

    context = Z3.context
    @theories = Theories.new(context)

    # THE EASY WAY
    @solver = context.solver

    @theories.on_init()

    # THE LONG WAY...
    # @configuration = Z3.config
    # # configuration.set("timeout","10")
    # # configuration.set("model","true")
    # @context = Z3.context(config: @configuration)
    # @solver = @context.solver

    # params = Z3.context.params
    # params.set("max_conflicts",0)
    # @solver.set_params(params)
  end

  def name; "Symbolic checker (Z3)" end

  def started!(id, method_name, *arguments)
    @theories.on_call(id, @history, @solver)
  end

  def completed!(id, *returns)
    @theories.on_return(id, @history, @solver)
  end

  # def started!(id, method_name, *arguments)
  #   return unless @incremental
  #   ops = @history
  #   vals = @history.values | [:empty]
  #   @solver.decl "o#{id}", :id
  #   @solver.assert "(= (meth o#{id}) #{method_name})"
  #   arguments.each_with_index do |x,idx|
  #     @solver.decl "v#{x}", :value
  #     @solver.assert "(= (arg o#{id} #{idx}) v#{x})"
  #   end
  #   @history.before(id).each do |b|
  #     @solver.assert "(hb o#{b} o#{id})"
  #   end
  #   @solver.assert "(P o#{id})"
  #
  #   ops = @history.map{|id| id}
  #   vals = @history.values | [:empty]
  #   @solver.assert "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
  #   @solver.assert "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1
  # end
  #
  # def completed!(id, *returns)
  #   return unless @incremental
  #   returns.each_with_index do |x,idx|
  #     @solver.decl "v#{x}", :value
  #     @solver.assert "(= (ret o#{id} #{idx}) v#{x})"
  #     @solver.assert "(C o#{id})"
  #   end
  #   vals = @history.values | [:empty]
  #   @solver.assert "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1
  # end
  #
  # def removed!(id)
  #   return unless @incremental
  #   @refresh = true
  # end

  def check_history(history)

    # if @refresh
    #   @solver.pop
    #   @solver.push
    #   @solver.theory history_ops_theory(@history)
    #   @refresh = false
    # end
    # # @solver.push
    # @solver.theory history_labels_theory(history) unless @incremental
    # @solver.theory history_order_theory(history) unless @incremental
    # @solver.theory history_domains_theory(history) unless @incremental

    # @theories.theory(history, @object).each do |th|
    #   @solver.assert th
    # end
    sat = @solver.check
    # @solver.reset

    # @solver.pop
    return [sat, 1]
  end

  def check_completions(history)
    num_checked = 0
    sat = false
    history.completions(HistoryCompleter.get(@object)).each do |complete_history|
      log.info('Symbolic') {"checking completion\n#{complete_history}"}
      sat, n = check_history(complete_history)
      num_checked += n
      break if sat
    end
    return [sat, num_checked]
  end

  def check()
    super()
    log.info('Symbolic') {"checking history\n#{@history}"}
    sat, _ = @completion ? check_completions(@history) : check_history(@history)
    log.info('Symbolic') {"result: #{sat ? "OK" : "violation"}"}
    flag_violation unless sat
  end

end

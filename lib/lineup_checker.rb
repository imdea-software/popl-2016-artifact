require_relative 'history.rb'
require_relative 'theories.rb'
require_relative 'z3.rb'

class LineUpChecker
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

  theory :ground_theory do |history,seq,t|
    ops = history.map{|id| id}
    vals = history.values

    ops.each {|id| t.yield "o#{id}".to_sym, :id}
    vals.each {|v| t.yield "v#{v}".to_sym, :value}

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

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

  def check(history)
    num_checked = 0
    sat = false
    log.info('LineUp') {"checking linearizations of history\n#{history}"}
    history.linearizations.each do |seq|
      log.info('LineUp') {"checking linearization #{seq * ", "}"}
      @solver.push
      @solver.theory ground_theory(history,seq)
      sat = @solver.check
      num_checked += 1
      @solver.pop
      break if sat
    end
    log.info('LineUp') {"checked #{num_checked} linearizations: #{sat ? "OK" : "violation"}"}
    return sat
  end

end
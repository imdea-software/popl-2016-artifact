require_relative 'history.rb'
require_relative 'z3.rb'

module SatisfactionChecker
  include Z3

  class << self
    extend Z3

    theory :basic_theory do |t|
      t.yield :id
      t.yield :method
      t.yield :value

      t.yield :meth, :id, :method
      t.yield :arg, :id, :value
      t.yield :ret, :id, :value

      t.yield :hb, :id, :id, :bool
      t.yield :lb, :id, :id, :bool
    
      # "linearization order includes happens-before order"
      t.yield "(forall ((x id) (y id)) (=> (hb x y) (lb x y)))"

      # linearization order is transitive
      t.yield "(forall ((x id) (y id) (z id)) (=> (and (lb x y) (lb y z)) (lb x z)))"

      # linearization order is anitsymmetric
      t.yield "(forall ((x id) (y id)) (=> (and (lb x y) (lb y x)) (= x y)))"

      # linearization order is total
      t.yield "(forall ((x id) (y id)) (or (lb x y) (lb y x)))"
    end

    theory :collection_theory do |t|
      t.yield :push, :method
      t.yield :pop, :method
      t.yield :match, :id, :id, :bool

      # matching
      t.yield "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) push) (= (meth y) pop) (= (arg x) (ret y)))))"

      # adds before matched removes
      t.yield "(forall ((x id) (y id)) (=> (match x y) (lb x y)))"
    end

    theory :stack_theory do |t|
      # LIFO order
      t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2) (lb r1 r2)) (lb r1 a2)))"
    end

    theory :queue_theory do |t|
      # FIFO order
      t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2)) (lb r1 r2)))"
    end

    theory :ground_theory do |history,t|
      ops = history.map{|id| id}
      vals = history.values

      ops.each {|id| t.yield "o#{id}".to_sym, :id}
      vals.each {|v| t.yield v, :value}

      t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})"
      t.yield "(distinct #{vals * " "})"

      history.each do |id|
        arg = history.arguments(id).first
        ret = history.returns(id).first
        t.yield "(= (meth o#{id}) #{history.method_name(id)})"
        t.yield "(= (arg o#{id}) #{arg})" if arg
        t.yield "(= (ret o#{id}) #{ret})" if ret
        history.after(id).each do |a|
          t.yield "(hb o#{id} o#{a})"
        end
      end
    end

  end

  def self.check(history)
    solver = Z3.context.solver
    solver.debug = true
    solver.theory basic_theory
    solver.theory collection_theory
    solver.theory stack_theory
    solver.theory ground_theory(history)
    solver.check
  end

end

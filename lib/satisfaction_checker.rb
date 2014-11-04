require_relative 'history.rb'
require_relative 'z3.rb'

module SatisfactionChecker
  include Z3

  Z = Z3.context

  def self.op(id)
    Z.const("op_#{id}",@sorts[:id])
  end

  def self.method(m)
    Z.const(m,@sorts[:method])
  end

  def self.value(v)
    Z.const(v.to_s,@sorts[:value])
  end

  def self.check(history)
    ops = history.map{|id| id}
    vals = history.values
    # Z3::enable_trace("z3.trace")
    solver = Z.solver

    @sorts = [:id, :method, :value].map{|s| [s,Z.ui_sort(s)]}
    @decls = [
      [:meth, :id, :method],
      [:push, :method],
      [:pop, :method],
      [:lbefore, :id, :id, :bool],
      [:hbefore, :id, :id, :bool],
      [:arg, :id, :value],
      [:ret, :id, :value],
      [:match, :id, :id, :bool],
      *ops.map{|id| ["o#{id}", :id]},
      *vals.map{|v| [v, :value]},
    ].map{|name,*types| [name,Z.function(name,*types.map{|t| @sorts.to_h.merge({bool: Z.bool_sort})[t]})]}

    @axioms = [
      # TODO USE PATTERNS OR NOTHING WILL FIRE

      # "linearization order includes happens-before order"
      # "(forall ((x id) (y id)) (! (=> (hbefore x y) (lbefore x y)) :pattern ((hbefore x y)) ))",
      "(forall ((x id) (y id)) (=> (hbefore x y) (lbefore x y)))",

      # linearization order is transitive
      "(forall ((x id) (y id) (z id)) (=> (and (lbefore x y) (lbefore y z)) (lbefore x z)))",

      # linearization order is anitsymmetric
      "(forall ((x id) (y id)) (=> (and (lbefore x y) (lbefore y x)) (= x y)))",

      # linearization order is total
      "(forall ((x id) (y id)) (or (lbefore x y) (lbefore y x)))",

      # matching
      "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) push) (= (meth y) pop) (= (arg x) (ret y)))))",

      # adds before matched removes
      "(forall ((x id) (y id)) (=> (match x y) (lbefore x y)))",

      # FIFO order
      "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lbefore a1 a2)) (lbefore r1 r2)))",

      # LIFO order
      "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lbefore a1 a2) (lbefore r1 r2)) (lbefore r1 a2)))"
    ]

    puts
    @axioms.each do |ax|
      solver.assert(Z.parse("(assert #{ax})",@sorts,@decls), debug:true)
    end
    facts = []
    
    facts << "(distinct #{ops.map{|id| "o#{id}"} * " "})"
    facts << "(distinct #{vals * " "})"
    history.each do |id|
      arg = history.arguments(id).first
      ret = history.returns(id).first
      facts << "(= (meth o#{id}) #{history.method_name(id)})"
      facts << "(= (arg o#{id}) #{arg})" if arg
      facts << "(= (ret o#{id}) #{ret})" if ret
      history.after(id).each do |a|
        facts << "(hbefore o#{id} o#{a})"
      end
    end
    facts.each do |f|
      solver.assert(Z.parse("(assert #{f})",@sorts,@decls), debug:true)
    end
    solver.check(debug: true)
  end

end

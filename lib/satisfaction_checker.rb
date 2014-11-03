require_relative 'history.rb'
require_relative 'z3.rb'

module SatisfactionChecker
  include Z3

  def self.op(id)
    Expr::symbol("op_#{id}",@sorts[:id])
  end

  def self.method(m)
    Expr::symbol(m,@sorts[:method])
  end

  def self.value(v)
    Expr::symbol(v.to_s,@sorts[:value])
  end

  def self.check(history)
    ops = history.map{|id| id}
    vals = history.values
    Z3::enable_trace("z3.trace")
    solver = Solver.make

    @sorts = [:id, :method, :value].map{|s| [s,Sort::ui(s)]}
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
    ].map{|name,*types| [name,Function.make(name,*types.map{|t| @sorts.to_h.merge({bool: Sort::bool})[t]})]}

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
      "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) push) (= (meth y) pop) (= (arg x) (ret y)))))"
    ]

    puts
    @axioms.each do |ax|
      solver.assert(Z3::parse("(assert #{ax})",@sorts,@decls), debug:true)
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
        # facts << "(hbefore o#{a} o#{id})"
      end
    end
    facts.each do |f|
      solver.assert(Z3::parse("(assert #{f})",@sorts,@decls), debug:true)
    end
    solver.check(debug: true)
  end

end

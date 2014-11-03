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
    Z3::enable_trace("z3.trace")
    solver = Solver.make

    @sorts = [:id, :method, :value].map{|s| [s,Sort::ui(s)]}
    @decls = [
      [:method, :id, :method],
      [:push, :method],
      [:pop, :method],
      [:lbefore, :id, :id, :bool],
      [:hbefore, :id, :id, :bool],
      [:argument, :id, :value],
      [:return, :id, :value],
      [:match, :id, :id, :bool],
      [:o1, :id],
      [:o2, :id],
      [:o3, :id],
    ].map{|name,*types| [name,Function.make(name,*types.map{|t| @sorts.to_h.merge({bool: Sort::bool})[t]})]}

    @axioms = [
      # TODO USE PATTERNS OR NOTHING WILL FIRE

      # "linearization order includes happens-before order"
      "(forall ((x id) (y id)) (! (=> (hbefore x y) (lbefore x y)) :pattern ((hbefore x y)) ))",

      # linearization order is transitive
      "(forall ((x id) (y id) (z id)) (=> (and (lbefore x y) (lbefore y z)) (lbefore x z)))",

      # linearization order is anitsymmetric
      "(forall ((x id) (y id)) (=> (and (lbefore x y) (lbefore y x)) (= x y)))",

      # linearization order is total
      "(forall ((x id) (y id)) (or (lbefore x y) (lbefore y x)))",

      # matching
      "(forall ((x id) (y id)) (= (match x y) (and (= (method x) push) (= (method y) pop) (= (argument x) (return y)))))"
    ]

    puts
    @axioms.each do |ax|
      solver.assert(Z3::parse("(assert #{ax})",@sorts,@decls), debug:true)
    end


    history.each do |id|
      solver.assert(Z3::parse("(assert (= (method o#{id}) #{history.method_name(id)}))",@sorts,@decls), debug:true)
    #   solver.assert \
    #     @functions[:method].app(op(id)) == method(history.method_name(id)),
    #     debug: true
    #
    #   solver.assert \
    #     @functions[:arg].app(op(id)) == value(history.arguments(id).first),
    #     debug: true \
    #     unless history.arguments(id).empty?
    #
    #   solver.assert \
    #     @functions[:ret].app(op(id)) == value(history.returns(id).first),
    #     debug: true \
    #     unless history.returns(id).empty?
    #
    #   history.after(id).each do |a|
    #     solver.assert \
    #       @functions[:hb].app(op(id),op(a)),
    #       debug: true
    #   end
    end

    solver.check(debug: true)
  end

end

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

    @sorts = {
      id:     Sort::uninterpreted(Symbol::string("id")),
      method: Sort::uninterpreted(Symbol::string("method")),
      value:  Sort::uninterpreted(Symbol::string("value"))
    }

    @functions = {
      method: Function::make('method_name', @sorts[:id], @sorts[:method]),
      lin:    Function::make('lin_before', @sorts[:id], @sorts[:id], Sort::bool),
      hb:     Function::make('happens_before', @sorts[:id], @sorts[:id], Sort::bool),
      arg:    Function::make('argument', @sorts[:id], @sorts[:value]),
      ret:    Function::make('return', @sorts[:id], @sorts[:value]),
      match:  Function::make('match', @sorts[:id], @sorts[:id], Sort::bool)
    }

    @axioms = [

      # NOTE MUST USE PATTERNS OR NOTHING WILL FIRE

      # "linearization order includes happens-before order"
      Expr::forall(
        [Symbol::string("op_1"), @sorts[:id]],
        [Symbol::string("op_2"), @sorts[:id]],
        @functions[:hb].app(op(1),op(2)).
        implies(@functions[:lin].app(op(1),op(2)))
      ),

      # "linearization order is transitive"
      Expr::forall(
        [Symbol::string("op_1"), @sorts[:id]],
        [Symbol::string("op_2"), @sorts[:id]],
        [Symbol::string("op_3"), @sorts[:id]],
        @functions[:lin].app(op(1),op(2)).
        and(@functions[:lin].app(op(2),op(3))).
        implies(@functions[:lin].app(op(1),op(3)))
      ),

      # "two operations match when ..."
      Expr::forall(
        [Symbol::string("op_1"), @sorts[:id]],
        [Symbol::string("op_2"), @sorts[:id]],
        @functions[:match].app(op(1),op(2)).iff(
          (@functions[:method].app(op(1)) == method("push")).
          and(@functions[:method].app(op(2)) == method("pop")).
          and(@functions[:arg].app(op(1)) == @functions[:ret].app(op(2)))
        )
      ),

    ]

    puts
    @axioms.each do |ax|
      solver.assert(ax, debug:true)
    end

    history.each do |id|
      solver.assert \
        @functions[:method].app(op(id)) == method(history.method_name(id)),
        debug: true

      solver.assert \
        @functions[:arg].app(op(id)) == value(history.arguments(id).first),
        debug: true \
        unless history.arguments(id).empty?

      solver.assert \
        @functions[:ret].app(op(id)) == value(history.returns(id).first),
        debug: true \
        unless history.returns(id).empty?

      history.after(id).each do |a|
        solver.assert \
          @functions[:hb].app(op(id),op(a)),
          debug: true
      end
    end

    puts "SOLVER ? #{solver.check}"
  end

end

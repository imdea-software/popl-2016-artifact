require_relative 'z3'
require_relative 'history.rb'
require_relative 'satisfaction_checker.rb'
require 'test/unit'

class TestZ3 < Test::Unit::TestCase
  include Z3

  def test_z3
    solver = Solver.make
    it = Sort::int
    t = Expr::true
    f = Expr::false
    x = Expr::int(1)
    y = Expr::int(2)
    s = Z3::Symbol::int(1)
    s2 = Z3::Symbol::string("before")
    z = Expr::const(s,Z3::Sort::int)
    f = Function.make(s,it,it,it)
    f2 = Function.make(s2,it,it,it)
    solver.push
    solver.assert Expr::forall(
      [s,Sort::int],
      (f2.app(f.app(x,y),z) != z) & t === (-x + y * z == y - x + y)
    )
    assert solver.check
    solver.push
    solver.assert Expr::false
    assert !solver.check
    solver.pop 2
    solver.assert (x == y)
    assert !solver.check
    solver.reset
    assert solver.check
  end
end

class TestHistory < Test::Unit::TestCase
  def test_history
    h = History.new
    id1 = h.start! :push, :a
    h1 = h.clone
    id2 = h.start! :push, :b
    h2 = h.clone
    h.complete! id1
    h3 = h.clone
    id3 = h.start! :pop
    h4 = h.clone
    h.complete! id3, :b
    h5 = h.clone
    h.complete! id2

    assert h1.include?(id1)
    assert !h1.include?(id2)
    assert !h1.include?(id3)
    assert h1.pending?(id1)

    assert h2.include?(id1)
    assert h2.include?(id2)
    assert !h2.include?(id3)
    assert h2.pending?(id1)
    assert h2.pending?(id2)

    assert h3.include?(id1)
    assert h3.include?(id2)
    assert !h3.include?(id3)
    assert !h3.pending?(id1)
    assert h3.pending?(id2)

    assert h4.include?(id1)
    assert h4.include?(id2)
    assert h4.include?(id3)
    assert !h4.pending?(id1)
    assert h4.pending?(id2)
    assert h4.pending?(id3)

    assert h5.include?(id1)
    assert h5.include?(id2)
    assert h5.include?(id3)
    assert !h5.pending?(id1)
    assert h5.pending?(id2)
    assert !h5.pending?(id3)

    assert h.include?(id1)
    assert h.include?(id2)
    assert h.include?(id3)
    assert !h.pending?(id1)
    assert !h.pending?(id2)
    assert !h.pending?(id3)

    assert h.before(id3).include?(id1)
    assert h.after(id1).include?(id3)

    assert h.linearizations.count == 3

    SatisfactionChecker::check(h)
  end
end
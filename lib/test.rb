require_relative 'z3'
require_relative 'history.rb'
require_relative 'satisfaction_checker.rb'
require 'test/unit'

class TestZ3 < Test::Unit::TestCase
  include Z3
  Z = Z3::context
  def test_z3
    solver = Z.solver
    it = Z.int_sort
    t = Z.true
    f = Z.false
    x = Z.int(1)
    y = Z.int(2)
    s = Z.int_symbol(1)
    s2 = Z.string_symbol("before")
    z = Z.const(s,Z.int_sort)
    f = Z.function(s,it,it,it)
    f2 = Z.function(s2,it,it,it)
    solver.push
    solver.assert Z.forall(
      [s,Z.int_sort],
      (f2.app(f.app(x,y),z) != z) & t === (-x + y * z == y - x + y)
    )
    assert solver.check
    solver.push
    solver.assert Z.false
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

    assert SatisfactionChecker::check(h)

    h = History.new
    h.complete! (h.start! :push, :a)
    h.complete! (h.start! :push, :b)
    h.complete! (h.start! :pop), :b
    h.complete! (h.start! :pop), :a
    assert SatisfactionChecker::check(h)

    h = History.new
    h.complete! (h.start! :push, :a)
    h.complete! (h.start! :push, :b)
    h.complete! (h.start! :pop), :a
    h.complete! (h.start! :pop), :b
    assert !SatisfactionChecker::check(h)
  end
end
require_relative 'history.rb'
require 'test/unit'

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
  end
end
module Theories
  def theory(name,&blk)
    define_method(name) do |*args|
      Enumerator.new do |y|
        blk.call(*args,y)
      end
    end
  end
end

module BasicTheories
  extend Theories

  theory :basic_theory do |t|
    t.yield :id
    t.yield :method
    t.yield :value

    t.yield :meth, :id, :method
    t.yield :arg, :id, :int, :value
    t.yield :ret, :id, :int, :value

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
end

module CollectionTheories
  extend Theories

  theory :collection_theory do |t|
    t.yield :push, :method
    t.yield :pop, :method
    t.yield :match, :id, :id, :bool
    t.yield :vempty, :value

    # matching
    t.yield "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) push) (= (meth y) pop) (= (arg x 0) (ret y 0)))))"

    # adds before matched removes
    t.yield "(forall ((x id) (y id)) (=> (match x y) (lb x y)))"

    # all matched pairs before or after empty removes
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (match x y) (= (meth z) pop) (= (ret z 0) vempty) (lb x z)) (lb y z)))"
  end

  theory :lifo_theory do |t|
    # LIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2) (lb r1 r2)) (lb r1 a2)))"
  end

  theory :fifo_theory do |t|
    # FIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2)) (lb r1 r2)))"
  end
end

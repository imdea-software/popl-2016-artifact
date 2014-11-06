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
    t.yield :pushed, :value, :bool
    t.yield :popped, :value, :bool
    t.yield :unmatched, :id, :bool
    t.yield :vempty, :value

    # matching
    t.yield "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) push) (= (meth y) pop) (= (arg x 0) (ret y 0)))))"

    # unmatched
    t.yield "(forall ((x id) (v value)) (=> (and (= (meth x) push) (= (arg x 0) v)) (pushed v)))"
    t.yield "(forall ((x id) (v value)) (=> (and (= (meth x) pop) (= (ret x 0) v)) (popped v)))"
    t.yield "(forall ((x id)) (= (unmatched x) (and (= (meth x) push) (not (popped (arg x 0))))))"

    # all popped elements are pushed
    t.yield "(forall ((v value)) (=> (and (not (= v vempty)) (popped v)) (pushed v)))"
    t.yield "(forall ((x id) (y id)) (=> (and (not (= x y)) (= (meth x) pop) (= (meth y) pop)) (not (= (ret x 0) (ret y 0)))))"

    # adds before matched removes
    t.yield "(forall ((x id) (y id)) (=> (match x y) (lb x y)))"

    # all adds removed before empty removes
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (match x y) (= (meth z) pop) (= (ret z 0) vempty) (lb x z)) (lb y z)))"
    t.yield "(forall ((x id) (z id)) (=> (and (unmatched x) (= (meth z) pop) (= (ret z 0) vempty)) (lb x z)))"
  end

  theory :lifo_theory do |t|
    # LIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2) (lb r1 r2)) (lb r1 a2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (match a1 r1) (unmatched a2) (not (= a1 a2)) (lb a1 a2)) (lb r1 a2)))"
  end

  theory :fifo_theory do |t|
    # FIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2)) (lb r1 r2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (match a1 r1) (unmatched a2) (not (= a1 a2))) (lb a1 a2)))"
  end
end

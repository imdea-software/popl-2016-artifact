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

  def theories_for(object)
    ts = []
    ts << basic_theory
    ts << atomic_theory if @object =~ /atomic/
    ts << collection_theory if @object =~ /stack|queue/
    case @object
    when /stack/
      ts << lifo_theory
      ts << stack_theory
    when /queue/
      ts << fifo_theory
      ts << queue_theory
    end
    return ts
  end

  theory :basic_theory do |t|
    t.yield :id
    t.yield :method
    t.yield :value

    t.yield :meth, :id, :method
    t.yield :arg, :id, :int, :value
    t.yield :ret, :id, :int, :value
    t.yield :C, :id, :bool

    t.yield :hb, :id, :id, :bool
    t.yield :lb, :id, :id, :bool
  
    # "linearization order includes happens-before order"
    t.yield "(forall ((x id) (y id)) (=> (and (C x) (C y) (hb x y)) (lb x y)))"

    # linearization order is transitive
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (C x) (C y) (C z) (lb x y) (lb y z)) (lb x z)))"

    # linearization order is anitsymmetric
    t.yield "(forall ((x id) (y id)) (=> (and (C x) (C y) (lb x y) (lb y x)) (= x y)))"
  end

  theory :atomic_theory do |t|
    # linearization order is total
    t.yield "(forall ((x id) (y id)) (=> (and (C x) (C y)) (or (lb x y) (lb y x))))"
  end

  theory :collection_theory do |t|
    t.yield :add, :method
    t.yield :rm, :method
    t.yield :match, :id, :id, :bool
    t.yield :added, :value, :bool
    t.yield :removed, :value, :bool
    t.yield :unmatched, :id, :bool
    t.yield :emptyrm, :id, :bool
    t.yield :vempty, :value

    t.yield "(distinct add rm)"

    # matching
    t.yield "(forall ((x id) (y id)) (= (match x y) (and (C x) (C y) (= (meth x) add) (= (meth y) rm) (= (arg x 0) (ret y 0)))))"

    # unmatched
    t.yield "(forall ((x id)) (= (unmatched x) (and (C x) (= (meth x) add) (not (exists ((y id)) (match x y))))))"

    # added & removed
    t.yield "(forall ((x id)) (= (added (arg x 0)) (and (C x) (= (meth x) add))))"
    t.yield "(forall ((x id)) (= (removed (ret x 0)) (and (C x) (= (meth x) rm))))"

    # empty
    t.yield "(forall ((x id)) (= (emptyrm x) (and (C x) (= (meth x) rm) (= (ret x 0) vempty))))"

    # all popped elements are pushed
    t.yield "(forall ((x id)) (=> (and (C x) (= (meth x) rm) (not (= (ret x 0) vempty))) (exists ((y id)) (and (C y) (= (meth y) add) (= (arg y 0) (ret x 0))))))"

    # no two non-empty removes return the same value
    t.yield "(forall ((x id) (y id)) (=> (and (C x) (C y) (= (meth x) rm) (= (meth y) rm) (not (= x y)) (not (= (ret x 0) vempty))) (not (= (ret x 0) (ret y 0)))))"

    # adds before matched removes
    t.yield "(forall ((x id) (y id)) (=> (and (C x) (C y) (match x y)) (lb x y)))"

    # all adds removed before empty removes
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (C x) (C y) (C z) (match x y) (emptyrm z) (lb x z)) (lb y z)))"
    t.yield "(forall ((x id) (z id)) (=> (and (C x) (C z) (unmatched x) (emptyrm z)) (lb z x)))"
  end

  theory :stack_theory do |t|
    t.yield :push, :method
    t.yield :pop, :method
    t.yield "(= push add)"
    t.yield "(= pop rm)"
  end

  theory :queue_theory do |t|
    t.yield :enqueue, :method
    t.yield :dequeue, :method
    t.yield "(= enqueue add)"
    t.yield "(= dequeue rm)"
  end

  theory :lifo_theory do |t|
    # LIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (C a1) (C r1) (C a2) (C r2) (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2) (lb r1 r2)) (lb r1 a2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (C a1) (C r1) (C a2) (match a1 r1) (unmatched a2) (not (= a1 a2)) (lb a1 a2)) (lb r1 a2)))"
  end

  theory :fifo_theory do |t|
    # FIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (C a1) (C r1) (C a2) (C r2) (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2)) (lb r1 r2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (C a1) (C r1) (C a2) (match a1 r1) (unmatched a2) (not (= a1 a2))) (lb a1 a2)))"
  end

  theory :history_labels_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values | [:empty]

    ops.each {|id| t.yield "o#{id}", :id}
    vals.each {|v| t.yield "v#{v}", :value}

    history.each do |id|
      args = history.arguments(id)
      rets = history.returns(id) || []
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      args.each_with_index {|x,idx| t.yield "(= (arg o#{id} #{idx}) v#{x})"}
      rets.each_with_index {|x,idx| t.yield "(= (ret o#{id} #{idx}) v#{x})"}

    end
  end

  theory :history_order_theory do |order,t|
    if order.is_a?(History)
      order.each {|id| order.after(id).each {|a| t.yield "(hb o#{id} o#{a})"}}
    elsif order.is_a?(Array)
      order.each_cons(2) {|id1,id2| t.yield "(hb o#{id1} o#{id2})"}
    elsif order.is_a?(Enumerable)
      order.each {|id1,id2| t.yield "(hb o#{id1} o#{id2})"}
    else
      fail "Unexpected history or enumerator."
    end
  end

  theory :history_domains_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values | [:empty]

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(forall ((x id)) (or #{ops.map{|id| "(= x o#{id})"} * " "}))" if ops.count > 0
    t.yield "(and #{ops.select(&history.method(:completed?)).map{|id| "(C o#{id})"} * " "})"
    t.yield "(distinct #{vals.map{|v| "v#{v}"} * " "})" if vals.count > 1

    # TODO this code should not depend the collection theory
    if history.complete?
      unremoved =
        history.map{|id| history.arguments(id)}.flatten(1) -
        history.map{|id| history.returns(id)||[]}.flatten(1)
      unremoved.each {|v| t.yield "(not (removed v#{v}))"}
    end
  end

end

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

    t.yield :hb, :id, :id, :bool
    t.yield :lb, :id, :id, :bool
  
    # "linearization order includes happens-before order"
    t.yield "(forall ((x id) (y id)) (=> (hb x y) (lb x y)))"

    # linearization order is transitive
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (lb x y) (lb y z)) (lb x z)))"

    # linearization order is anitsymmetric
    t.yield "(forall ((x id) (y id)) (=> (and (lb x y) (lb y x)) (= x y)))"
  end

  theory :atomic_theory do |t|
    # linearization order is total
    t.yield "(forall ((x id) (y id)) (or (lb x y) (lb y x)))"
  end

  theory :collection_theory do |t|
    t.yield :add, :method
    t.yield :rm, :method
    t.yield :match, :id, :id, :bool
    t.yield :added, :value, :bool
    t.yield :removed, :value, :bool
    t.yield :unmatched, :id, :bool
    t.yield :vempty, :value

    t.yield "(distinct add rm)"

    # matching
    t.yield "(forall ((x id) (y id)) (= (match x y) (and (= (meth x) add) (= (meth y) rm) (= (arg x 0) (ret y 0)))))"

    # unmatched
    t.yield "(forall ((x id)) (= (unmatched x) (and (= (meth x) add) (not (exists ((y id)) (and (= (meth y) rm) (= (ret y 0) (arg x 0))))))))"

    # same, using added/removed instead of nested quantifier
    t.yield "(forall ((x id) (v value)) (=> (and (= (meth x) add) (= (arg x 0) v)) (added v)))"
    t.yield "(forall ((x id) (v value)) (=> (and (= (meth x) rm) (= (ret x 0) v)) (removed v)))"
    t.yield "(forall ((x id)) (= (unmatched x) (and (= (meth x) add) (not (removed (arg x 0))))))"

    # all popped elements are pushed
    t.yield "(forall ((x id)) (=> (and (= (meth x) rm) (not (= (ret x 0) vempty))) (exists ((y id)) (and (= (meth y) add) (= (arg y 0) (ret x 0))))))"

    # same, using added/removed instead of nested quantifier
    t.yield "(forall ((v value)) (=> (and (not (= v vempty)) (removed v)) (added v)))"

    # no two non-empty removes return the same value
    t.yield "(forall ((x id) (y id)) (=> (and (= (meth x) rm) (= (meth y) rm) (not (= x y)) (not (= (ret x 0) vempty))) (not (= (ret x 0) (ret y 0)))))"

    # adds before matched removes
    t.yield "(forall ((x id) (y id)) (=> (match x y) (lb x y)))"

    # all adds removed before empty removes
    t.yield "(forall ((x id) (y id) (z id)) (=> (and (match x y) (= (meth z) rm) (= (ret z 0) vempty) (lb x z)) (lb y z)))"
    t.yield "(forall ((x id) (z id)) (=> (and (unmatched x) (= (meth z) rm) (= (ret z 0) vempty)) (lb z x)))"
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
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2) (lb r1 r2)) (lb r1 a2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (match a1 r1) (unmatched a2) (not (= a1 a2)) (lb a1 a2)) (lb r1 a2)))"
  end

  theory :fifo_theory do |t|
    # FIFO order
    t.yield "(forall ((a1 id) (r1 id) (a2 id) (r2 id)) (=> (and (match a1 r1) (match a2 r2) (not (= a1 a2)) (lb a1 a2)) (lb r1 r2)))"
    t.yield "(forall ((a1 id) (r1 id) (a2 id)) (=> (and (match a1 r1) (unmatched a2) (not (= a1 a2))) (lb a1 a2)))"
  end

  theory :history_ops_theory do |history,t|
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
      history.after(id).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  theory :seq_history_ops_theory do |history,seq,t|
    ops = history
    vals = history.values | [:empty]

    ops.each {|id| t.yield "o#{id}", :id}
    vals.each {|v| t.yield "v#{v}", :value}

    seq.each_with_index do |id,idx|
      args = history.arguments(id)
      rets = history.returns(id) || []
      t.yield "(= (meth o#{id}) #{history.method_name(id)})"
      args.each_with_index {|x,idx| t.yield "(= (arg o#{id} #{idx}) v#{x})"}
      rets.each_with_index {|x,idx| t.yield "(= (ret o#{id} #{idx}) v#{x})"}
      seq.drop(idx+1).each do |a|
        t.yield "(hb o#{id} o#{a})"
      end
    end
  end

  theory :history_domains_theory do |history,t|
    ops = history.map{|id| id}
    vals = history.values | [:empty]

    t.yield "(distinct #{ops.map{|id| "o#{id}"} * " "})" if ops.count > 1
    t.yield "(forall ((x id)) (or #{ops.map{|id| "(= x o#{id})"} * " "}))" if ops.count > 0
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

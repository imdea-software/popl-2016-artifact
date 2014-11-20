require 'forwardable'

class Theories

  extend Forwardable
  def_delegators :@context, :decl_const, :decl_sort, :distinct, :expr
  def_delegators :@context, :conj, :disj, :tt, :ff
  def_delegators :@context, :pattern, :forall, :exists
  alias :e :expr

  def initialize(context)
    @context = context
  end

  def op(id) "o#{id}".to_sym end
  def val(v) "v#{v}".to_sym end

  # generic predicates
  def meth?(id)      e(:mth, e(op(id))) end
  def arg?(id,i)    e(:arg, e(op(id)), e(i)) end
  def ret?(id,i)    e(:ret, e(op(id)), e(i)) end
  def before?(i,j)  e(:bef, e(op(i)), e(op(j))) end
  def c?(id)        e(:c, e(op(id))) end

  def p(o)          e(:p, o) end
  def c(o)          e(:c, o) end
  def meth(o)       e(:mth, o) end
  def arg(o,i)      e(:arg, o, e(i)) end
  def ret(o,i)      e(:ret, o, e(i)) end
  def before(o,p)   e(:bef, o, p) end

  def add(a)        meth(a) == e(:add) end
  def rem(a)        meth(a) == e(:rmv) end
  def match(a,r)    add(a) & rem(r) & (arg(a,0) == ret(r,0)) end
  def unmatched(a)  add(a) & !exists_ids {|r| match(a,r)} end
  def empty(r)      rem(r) & (ret(r,0) == e(val(:empty))) end

  def call_label(id,h)
    [(meth?(id) == e(h.method_name(id)))] +
    h.arguments(id).each_with_index.map{|v,i| arg?(id,i) == e(val(v))}
  end

  def ret_label(id,h)
    (h.returns(id) || []).each_with_index.map{|v,i| ret?(id,i) == e(val(v))}
  end

  # collection predicates
  def add?(id) meth?(id) == e(:add) end
  def rem?(id) meth?(id) == e(:rmv) end
  def match?(i,j) add?(i) & rem?(j) & (arg?(i,0) == ret?(j,0)) end
  def bounded_unmatched?(i,ids) add?(i) & !bounded_exists(ids-[i]) {|j| match?(i,j)} end
  def empty?(id) rem?(id) & (ret?(id,0) == e(val(:empty))) end

  def dprod(a,k)
    return a if k < 2
    p = a.product(a).reject{|x,y| x == y}
    (k-2).times do
      p = p.product(a).map{|xs,y| xs+[y] unless xs.include?(y)}.compact
    end
    return p
  end

  # TODO unclear how to use the bound variables with nested quantifiers...

  def forall_ids(&f)
    ids = f.arity.times.map {|i| @context.bound(i,@context.resolve(:id))}
    forall(
      *f.arity.times.map {|i| [@context.wrap_symbol(op(i)),@context.resolve(:id)]},
      f.call(*ids),
      patterns: [pattern(*ids.map{|o| c(o)})]
    )
  end
  def exists_ids(&f)
    ids = f.arity.times.map {|i| @context.bound(i,@context.resolve(:id))}
    exists(
      *f.arity.times.map {|i| [@context.wrap_symbol(op(i)),@context.resolve(:id)]},
      ids.map{|o| c(o)}.reduce(:&) & f.call(*ids),
      patterns: [pattern(*ids.map{|o| p(o)})]
    )
  end

  def bounded_forall(ids,&f) conj(*dprod(ids,f.arity).map{|*ids| f.call(*ids)}.compact) end
  def bounded_exists(ids,&f) disj(*dprod(ids,f.arity).map{|*ids| f.call(*ids)}.compact) end

  def maybe_match?(i,j,h)
    h.method_name(i) =~ /push/ &&
    h.method_name(j) =~ /pop/ &&
    (h.returns(j).nil? || h.returns(j).first == h.arguments(i).first)
  end

  def maybe_empty?(i,h)
    h.method_name(i) =~ /pop/ &&
    (h.returns(i).nil? || h.returns(i).first == :empty)
  end

  def maybe_nonempty?(i,h)
    h.method_name(i) =~ /pop/ &&
    (h.returns(i).nil? || h.returns(i).first != :empty)
  end

  def on_init()
    decl_sort :id
    decl_sort :method
    decl_sort :value

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :add, :method
    decl_const :rmv, :method
    decl_const :remove, :method
    decl_const val(:empty), :value

    decl_const :push, :method
    decl_const :pop, :method

    decl_const :c, :id, :bool
    decl_const :p, :id, :bool
  end

  def quantified_theory(object)
    Enumerator.new do |y|

      # before is transitive
      y << forall_ids {|i,j,k| (before(i,j) & before(j,k)).implies(before(i,k))}

      # before is antisymmetric
      y << forall_ids {|i,j| (before(i,j) & before(j,i)).implies(i == j)}
      
      if object =~ /atomic/
        # before is total
        y << forall_ids {|i,j| before(i,j) | before(j,i)}
      end

      if object =~ /stack|queue/
        # an add for every remove
        y << forall_ids {|r| (rem(r) & !empty(r)).implies(exists_ids {|a| match(a,r)})}

        # adds before removes
        y << forall_ids {|a,r| match(a,r).implies(before(a,r))}

        # unique removes
        y << forall_ids {|r1,r2| (rem(r1) & rem(r2) & !empty(r1)).implies(ret(r1,0) != ret(r2,0))}

        # adds removed before empty
        y << forall_ids {|a,r,e| (match(a,r) & empty(e) & before(a,e)).implies(before(r,e))}

        # unmatched adds before empty
        y << forall_ids {|a,e| (unmatched(a) & empty(e)).implies(before(a,e))}
      end

      if object =~ /queue/
        # fifo order
        y << forall_ids {|a1,r1,a2,r2| (match(a1,r1) & match(a2,r2) & before(a1,a2)).implies(before(r1,r2))}
        y << forall_ids {|a1,r1,a2| (match(a1,r1) & unmatched(a2)).implies(before(a1,a2))}
      end

      if object =~ /stack/
        # lifo order
        y << forall_ids {|a1,r1,a2,r2| (match(a1,r1) & match(a2,r2) & before(a1,a2) & before(r1,r2)).implies(before(r1,a2))}
        y << forall_ids {|a1,r1,a2| (match(a1,r1) & unmatched(a2) & before(a1,a2)).implies(before(r1,a2))}
      end

    end
  end

  def on_call(id, history, solver)
    ids = history.to_a
    decl_const op(id), :id
    history.arguments(id).each do |v|
      decl_const val(v), :value
      solver.assert call_label(id,history).reduce(:&)
    end
    history.before(id).each do |jd|
      solver.assert before?(jd,id)
    end
    solver.assert distinct(*ids.map{|id| e(op(id))})
    solver.assert distinct(*history.values.map{|v| e(val(v))}) unless history.arguments(id).empty?

    # before is transitive
    bounded_forall(ids-[id]) do |j,k|
      solver.assert (before?(id,j) & before?(j,k)).implies(before?(id,k)) unless history.before?(id,k) || history.before?(j,id) || history.before?(k,j)
      solver.assert (before?(j,id) & before?(id,k)).implies(before?(j,k)) unless history.before?(j,k) || history.before?(id,j) || history.before?(k,id)
      solver.assert (before?(j,k) & before?(k,id)).implies(before?(j,id)) unless history.before?(j,id) || history.before?(k,j) || history.before?(id,k)
    end

    # before is antisymmetric
    bounded_forall(ids-[id]) do |j|
      solver.assert (before?(id,j) & before?(j,id)).implies(e(op(id)) == e(op(j)))
    end

    # before is total
    bounded_forall(ids-[id]) do |j|
      next if history.before?(id,j)
      next if history.before?(j,id)
      solver.assert (before?(id,j) | before?(j,id))
    end
    
    solver.assert (e(:remove) == e(:rmv))
    solver.assert (e(:push) == e(:add))
    solver.assert (e(:pop) == e(:rmv))

    if history.method_name(id) =~ /push/

      # adds before removes
      bounded_forall(ids-[id]) do |j|
        next unless maybe_match?(id,j,history)
        solver.assert match?(id,j).implies(before?(id,j))
      end

      # adds removed before empty
      bounded_forall(ids-[id]) do |e,p|
        next unless maybe_empty?(e,history)
        next unless maybe_match?(id,p,history)
        next if history.before?(p,e)

        solver.assert (empty?(e) & match?(id,p) & before?(id,e)).implies(before?(p,e))
      end

      # lifo order between two matches
      bounded_forall(ids-[id]) do |a1,r1,r2|
        next unless maybe_match?(a1,r1,history)
        next unless maybe_match?(id,r2,history)
        
        solver.assert (match?(a1,r1) & match?(id,r2) & before?(a1,id) & before?(r1,r2)).implies(before?(r1,a2)) unless history.before?(r1,id)
        solver.assert (match?(id,r2) & match?(a1,r1) & before?(id,a1) & before?(r2,r1)).implies(before?(r2,a1)) unless history.before?(r2,a1)
      end

    elsif history.method_name(id) =~ /pop/

      # an add for every remove
      # TODO this is unsound, because the add might not yet exist
      # solver.assert (empty?(id) | bounded_exists(ids-[id]) {|j| match?(j,id)})

      # adds before removes
      bounded_forall(ids-[id]) do |j|
        next unless maybe_match?(j,id,history)
        next if history.before?(j,id)

        solver.assert match?(j,id).implies(before?(j,id))
      end

      # unique removes
      bounded_forall(ids-[id]) do |j|
        next unless maybe_nonempty?(j,history)

        solver.assert (empty?(id) | (ret?(id,0) != ret?(j,0)))
      end

      # adds removed before empty
      bounded_forall(ids-[id]) do |o,p|
        next unless maybe_match?(o,p,history)
        next if history.before?(p,id)

        solver.assert (empty?(id) & match?(o,p) & before?(o,id)).implies(before?(p,id))
      end

      # unmatched adds removed after empty
      bounded_forall(ids-[id]) do |o|
        next unless history.method_name(o) =~ /push/
        # TODO how to be sound w/ bounded_unmatched?
      end

      # lifo order between two matches
      bounded_forall(ids-[id]) do |a1,r1,a2|
        next unless maybe_match?(a1,r1,history)
        next unless maybe_match?(a2,id,history)
        
        solver.assert (match?(a1,r1) & match?(a2,id) & before?(a1,a2) & before?(r1,id)).implies(before?(r1,a2)) unless history.before?(r1,a2)
        solver.assert (match?(a2,id) & match?(a1,r1) & before?(a2,a1) & before?(id,r1)).implies(before?(id,a1)) unless history.before?(id,a1)
      end

      # lifo order between a match and unmatched
      bounded_forall(ids-[id]) do |a1,a2|
        next unless maybe_match?(a1,id,history)
        next if history.before?(id,a2)

        # TODO how to reconcile completeness here?
        # solver.assert (match?(a1,id) & bounded_unmatched?(a2,ids) & before?(a1,a2)).implies(before?(r1,a2))
      end
    end

  end

  def on_return(id, history, solver)
    history.returns(id).each do |v|
      decl_const val(v), :value
      solver.assert ret_label(id,history).reduce(:&)
    end
    solver.assert distinct(*history.values.map{|v| e(val(v))}) unless history.returns(id).empty?
  end

  def theory(history, object, order: nil)
    ids = history.to_a
    th = []
    th.push *background_theory(history)
    th.push *order_theory(history)
    th.push *atomic_theory(history) if object =~ /atomic/
    th.push *collection_theory(history) if object =~ /stack|queue/
    th.push *lifo_theory(history) if object =~ /stack/
    th.push *fifo_theory(ids) if object =~ /queue/
    th.push *history_theory(history, order: order)
    th
  end

  def background_theory(history)
    decl_sort :id
    decl_sort :method
    decl_sort :value

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value

    history.each        {|id| decl_const op(id), :id}
    history.values.each {|v|  decl_const val(v), :value}

    th = []
    th << distinct(*history.map{|id| e(op(id))})
    th << distinct(*history.values.map{|v| e(val(v))})
    th
  end

  def order_theory(history)
    ids = history.to_a
    decl_const :bef, :id, :id, :bool

    th = []

    # before is transitive
    th << bounded_forall(ids) {|o,p,q| (before?(o,p) & before?(p,q)).implies(before?(o,q)) unless history.before?(o,q)} if ids.count > 2

    # before is antisymmetric
    th << bounded_forall(ids) {|o,p| (before?(o,p) & before?(p,o)).implies(e(op(o)) == e(op(p))) unless o == p} if ids.count > 1

    th
  end

  def atomic_theory(history)
    ids = history.to_a
    th = []
    # before is total
    th << bounded_forall(ids) {|o,p| before?(o,p) | before?(p,o) unless history.before?(o,p) || history.before?(p,o)} if ids.count > 1
    th
  end

  def collection_theory(history)
    ids = history.to_a
    decl_const :add, :method
    decl_const :rmv, :method
    decl_const :remove, :method
    decl_const val(:empty), :value

    th = []

    th << (e(:remove) == e(:rmv))

    # an add for every remove
    th << bounded_forall(ids) do |o|
      next unless history.method_name(o) == :pop
      next unless (history.returns(o).nil? || history.returns(o).first != :empty)
      (rem?(o) & !empty?(o)).implies(bounded_exists(ids-[o]) do |p|
        next unless history.method_name(p) == :push
        match?(p,o)
      end)
    end if ids.count > 1

    # adds before removes
    th << bounded_forall(ids) do |o,p|
      next if history.before?(o,p)
      next unless history.method_name(o) == :push 
      next unless history.method_name(p) == :pop
      next unless (history.returns(p).nil? || history.returns(p).first == history.arguments(o).first)

      match?(o,p).implies(before?(o,p))
    end if ids.count > 1

    # unique removes
    th << bounded_forall(ids) do |o,p|
      next unless history.method_name(o) == :pop
      next unless history.method_name(p) == :pop
      orets = history.returns(o)
      prets = history.returns(p)
      next if orets && orets.first == :empty
      next if prets && prets.first == :empty
      next if orets && prets && orets.first != prets.first

      (rem?(o) & rem?(p) & !empty?(o)).implies(ret?(o,0) != ret?(p,0))
    end if ids.count > 1

    # adds removed before empty
    th << bounded_forall(ids) do |e,o,p|
      next unless history.method_name(e) == :pop
      next if history.returns(e) && history.returns(e).first != :empty
      next unless history.method_name(o) == :push
      next unless history.method_name(p) == :pop
      next unless history.returns(p).nil? || history.returns(p).first == history.arguments(o).first
      next if history.before?(p,e)

      (empty?(e) & match?(o,p) & before?(o,e)).implies(before?(p,e))
    end if ids.count > 2

    th << bounded_forall(ids) do |e,o|
      next unless history.method_name(e) == :pop
      next unless history.method_name(o) == :push
      next if history.returns(e) && history.returns(e).first != :empty
      next if history.before?(e,o)

      (empty?(e) & bounded_unmatched?(o,ids-[o,e])).implies(before?(e,o))
    end if ids.count > 1
    th
  end

  def lifo_theory(history)
    ids = history.to_a
    decl_const :push, :method
    decl_const :pop, :method

    th = []
    th << (e(:push) == e(:add))
    th << (e(:pop) == e(:rmv))
    th << bounded_forall(ids) do |a1,r1,a2,r2|
      next unless history.method_name(a1) == :push
      next unless history.method_name(a2) == :push
      next unless history.method_name(r1) == :pop
      next unless history.method_name(r2) == :pop
      next if history.returns(r1) && history.returns(r1).first != history.arguments(a1).first
      next if history.returns(r2) && history.returns(r2).first != history.arguments(a2).first
      next if history.before?(r1,a2)

      (match?(a1,r1) & match?(a2,r2) & before?(a1,a2) & before?(r1,r2)).implies(before?(r1,a2))
    end if ids.count > 3
    th << bounded_forall(ids) do |a1,r1,a2|
      next unless history.method_name(a1) == :push
      next unless history.method_name(a2) == :push
      next unless history.method_name(r1) == :pop
      next if history.returns(r1) && history.returns(r1).first != history.arguments(a1).first
      next if history.before?(r1,a2)

      (match?(a1,r1) & bounded_unmatched?(a2,ids) & before?(a1,a2)).implies(before?(r1,a2))
    end if ids.count > 2
    th
  end

  def fifo_theory(ids)
    decl_const :enqueue, :method
    decl_const :dequeue, :method

    th = []
    th << (e(:enqueue) == e(:add))
    th << (e(:dequeue) == e(:rmv))
    th << bounded_forall(ids) {|a1,r1,a2,r2| (match?(a1,r1) & match?(a2,r2) & before?(a1,a2)).implies(before?(r1,r2))} if ids.count > 3
    th << bounded_forall(ids) {|a1,r1,a2| (match?(a1,r1) & bounded_unmatched?(a2,ids-[a1,r1,a2])).implies(before?(a1,a2))} if ids.count > 2
    th
  end

  def history_theory(history, order: nil)
    th = []
    history.each do |id|
      th.push *call_label(id,history)
      th.push *ret_label(id,history) if history.completed?(id)
    end
    th.push *case order
    when Array;       order.each_cons(2).map {|i,j| before?(i,j)}
    when Enumerable;  order.map {|i,j| before?(i,j)}
    else history.map{|i| history.after(i).map {|j| before?(i,j)}}.flatten
    end
    th
  end

end

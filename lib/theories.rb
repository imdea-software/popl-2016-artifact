require 'forwardable'

class Theories

  extend Forwardable
  def_delegators :@context, :decl_const, :decl_sort, :resolve, :expr
  def_delegators :@context, :conj, :disj, :tt, :ff, :const, :distinct
  def_delegators :@context, :pattern, :forall, :exists
  alias :e :expr

  def initialize(context)
    @context = context
  end

  def id_sort; resolve :id end

  # TODO rethink this predicate
  def val(v) "v#{v}".to_sym end

  def default_op(id) "o#{id}".to_sym end
  def default_val(v) "v#{v}".to_sym end

  def p(o)          e(:p, o) end
  def c(o)          e(:c, o) end
  def meth(o)       e(:mth, o) end
  def arg(o,i)      e(:arg, o, e(i)) end
  def ret(o,i)      e(:ret, o, e(i)) end
  def before(o,p)   e(:bef, o, p) end

  def add(a)        meth(a) == e(:add) end
  def rem(a)        meth(a) == e(:remove) end
  def match(a,r)    add(a) & rem(r) & (arg(a,0) == ret(r,0)) end
  def unmatched(a)  add(a) & !exists_ids {|r| c(r) & match(a,r)} end
  def empty(r)      rem(r) & (ret(r,0) == e(val(:empty))) end

  def with_ids(n)
    reset = @id_number.nil?
    @unique_id ||= 0
    vars = n.times.map {const("x#{@unique_id += 1}", id_sort)}
    f = yield vars
    @unique_id = nil if reset
    f
  end

  def forall_ids(&f)
    with_ids(f.arity) do |xs|
      forall(*xs, (conj(*xs.map{|x| c(x)})).implies(f.call(*xs)))
      # patterns: [pattern(*xs.map{|o| c(o)})]
    end
  end

  def exists_ids(&f)
    with_ids(f.arity) do |xs|
      exists(*xs, (conj(*xs.map{|x| c(x)})) & f.call(*xs))
      # patterns: [pattern(*xs.map{|o| c(o)})]
    end
  end

  def product_of_distinct(a,k)
    return a if k < 2
    p = a.product(a).reject{|x,y| x == y}
    (k-2).times do
      p = p.product(a).map{|xs,y| xs+[y] unless xs.include?(y)}.compact
    end
    return p
  end

  def bounded_forall(ids,&f)
    conj(*product_of_distinct(ids,f.arity).map{|*ids| f.call(*ids)}.compact)
  end

  def bounded_exists(ids,&f)
    disj(*product_of_distinct(ids,f.arity).map{|*ids| f.call(*ids)}.compact)
  end

  def theory(object)
    decl_sort :id
    decl_sort :method
    decl_sort :value

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :c, :id, :bool
    decl_const :p, :id, :bool

    Enumerator.new do |y|

      # before is transitive
      y << forall_ids {|i,j,k| (before(i,j) & before(j,k)).implies(before(i,k))}

      # before is antisymmetric
      y << forall_ids {|i,j| (before(i,j) & before(j,i)).implies(i == j)}
      
      if object =~ /atomic/
        # before is total
        y << forall_ids {|i,j| (i == j) | before(i,j) | before(j,i)}
      end

      if object =~ /stack|queue/
        decl_const :add, :method
        decl_const :remove, :method
        decl_const :rm, :method
        decl_const val(:empty), :value

        y << (e(:rm) == e(:remove))
        y << (e(:add) != e(:remove))

        # an add for every remove
        y << forall_ids {|r| (rem(r) & !empty(r)).implies(exists_ids {|a| match(a,r)})}

        # adds before removes
        y << forall_ids {|a,r| (match(a,r)).implies(before(a,r))}

        # unique removes
        y << forall_ids {|r1,r2| ((r1 != r2) & rem(r1) & rem(r2) & !empty(r1)).implies(ret(r1,0) != ret(r2,0))}

        # adds removed before empty
        y << forall_ids {|a,r,e| (match(a,r) & empty(e) & before(a,e)).implies(before(r,e))}

        # unmatched adds before empty
        y << forall_ids {|a,e| (unmatched(a) & empty(e)).implies(before(e,a))}
      end

      if object =~ /queue/
        decl_const :enqueue, :method
        decl_const :dequeue, :method

        y << (e(:enqueue) == e(:add))
        y << (e(:dequeue) == e(:remove))

        # fifo order
        y << forall_ids {|a1,r1,a2,r2| ((a1 != a2) & match(a1,r1) & match(a2,r2) & before(a1,a2)).implies(before(r1,r2))}
        y << forall_ids {|a1,r1,a2| ((a1 != a2) & match(a1,r1) & unmatched(a2)).implies(before(a1,a2))}
      end

      if object =~ /stack/
        decl_const :push, :method
        decl_const :pop, :method

        y << (e(:push) == e(:add))
        y << (e(:pop) == e(:remove))

        # lifo order
        y << forall_ids {|a1,r1,a2,r2| (match(a1,r1) & match(a2,r2) & before(a1,a2) & before(r1,r2)).implies(before(r1,a2))}
        y << forall_ids {|a1,r1,a2| (match(a1,r1) & unmatched(a2) & before(a1,a2)).implies(before(r1,a2))}
      end

    end
  end

  def rename(o) e(:g, o) end
  def dom(o) e(:domain_g, o) end
  def range(o) e(:range_g, o) end

  def weaker_than(h1, h2)
    decl_const :g, :id, :id
    Enumerator.new do |y|
      op2 = Proc.new {|id| "p#{id}".to_sym}
      history(h1).each(&y.method(:yield))
      history(h2, op:op2).each(&y.method(:yield))

      # TODO assert the matching facts

      h2.each {|id| y << dom(e(op2(id))); y << range(rename(e(op2(id)))) }
      y << forall_ids {|i,j| (rename(i) == rename(j)).implies(i == j)}
      y << forall_ids {|i,j| (dom(i) & dom(j) & match(rename(i),rename(j))).implies(match(i,j))}
      y << forall_ids {|i,j| (dom(i) & dom(j) & before(rename(i),rename(j))).implies(before(i,j))}
    end
  end

  def history(h, order: nil, op: method(:default_op), val: method(:default_val))
    h.each {|id| decl_const op.call(id), :id}
    h.values.each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      h.each do |id|
        called(id, h, order:order, op:op, val:val).each(&y.method(:yield))
        returned(id,h, op:op, val:val).each(&y.method(:yield)) if h.completed?(id)
      end
      domains(h).each(&y.method(:yield))

      case order
      when Array; order.each_cons(2)
      when Enumerator; order
      else []
      end.each do |i,j|
        y << c(e(op.call(i)))
        y << before(e(op.call(i)),e(op.call(j)))
      end
    end
  end

  def called(id, history, order: nil, op: method(:default_op), val: method(:default_val))
    decl_const op.call(id), :id
    history.arguments(id).each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      history.each {|j| y << (e(op.call(id)) != e(op.call(j))) unless j == id}
      y << (meth(e(op.call(id))) == e(history.method_name(id)))
      history.arguments(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val.call(v)) != e(val.call(u))) unless u == v}
        y << (e(val.call(v)) != e(val.call(:empty)))
        y << (arg(e(op.call(id)),i) == e(val.call(v)))
      end
      history.before(id).each {|j| y << before(e(op.call(j)), e(op.call(id)))} unless order
      y << p(e(op.call(id)))
    end
  end

  def returned(id, history, op: method(:default_op), val: method(:default_val))
    history.returns(id).each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      history.returns(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val.call(v)) != e(val.call(u))) unless u == v}
        y << (e(val.call(v)) != e(val.call(:empty))) unless v == :empty
        y << (ret(e(op.call(id)),i) == e(val.call(v)))
      end
      y << c(e(op.call(id)))
    end
  end

  def domains(history, op: method(:default_op), val: method(:default_val))
    Enumerator.new do |y|
      y << forall_ids {|o| disj(*history.map{|j| o == e(op.call(j))})}
    end
  end

end

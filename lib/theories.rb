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

  def id_sort; @context.resolve :id end

  def op(id) "o#{id}".to_sym end
  def val(v) "v#{v}".to_sym end

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
    vars = n.times.map {@context.const("x#{@unique_id += 1}", id_sort)}
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

  # def dprod(a,k)
  #   return a if k < 2
  #   p = a.product(a).reject{|x,y| x == y}
  #   (k-2).times do
  #     p = p.product(a).map{|xs,y| xs+[y] unless xs.include?(y)}.compact
  #   end
  #   return p
  # end

  # def bounded_forall(ids,&f) conj(*dprod(ids,f.arity).map{|*ids| f.call(*ids)}.compact) end
  # def bounded_exists(ids,&f) disj(*dprod(ids,f.arity).map{|*ids| f.call(*ids)}.compact) end

  def theory(object)
    decl_sort :id
    decl_sort :method
    decl_sort :value

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :add, :method
    decl_const :remove, :method
    decl_const val(:empty), :value

    decl_const :push, :method
    decl_const :pop, :method

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

  def history(h, order: nil)
    h.each {|id| decl_const "o#{id}", :id}
    h.values.each {|v| decl_const "v#{v}", :value}
    Enumerator.new do |y|
      h.each do |id|
        called(id,h).each(&y.method(:yield))
        returned(id,h).each(&y.method(:yield)) if h.completed?(id)
      end
      domains(h).each(&y.method(:yield))

      case order
      when Array; order.each_cons(2)
      when Enumerator; order
      else []
      end.each do |i,j|
        y << c(e(op(i)))
        y << before(e(op(i)),e(op(j)))
      end
    end
  end

  def called(id, history)
    decl_const "o#{id}", :id
    history.arguments(id).each {|v| decl_const "v#{v}", :value}

    Enumerator.new do |y|
      history.each {|j| y << (e(op(id)) != e(op(j))) unless j == id}
      y << (meth(e(op(id))) == e(history.method_name(id)))
      history.arguments(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val(v)) != e(val(u))) unless u == v}
        y << (e(val(v)) != e(val(:empty)))
        y << (arg(e(op(id)),i) == e(val(v)))
      end
      history.before(id).each {|j| y << before(e(op(j)), e(op(id)))}
      y << p(e(op(id)))
    end
  end

  def returned(id, history)
    history.returns(id).each {|v| decl_const "v#{v}", :value}

    Enumerator.new do |y|
      history.returns(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val(v)) != e(val(u))) unless u == v}
        y << (e(val(v)) != e(val(:empty))) unless v == :empty
        y << (ret(e(op(id)),i) == e(val(v)))
      end
      y << c(e(op(id)))
    end
  end

  def domains(history)
    Enumerator.new do |y|
      y << forall_ids {|o| disj(*history.map{|j| o == e(op(j))})}
    end
  end

end

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

  def with_bound_ids(n)
    # reset_var_index = @var_index.nil?
    var_index = -1
    x = yield n.times.map {@context.bound(var_index += 1, @context.resolve(:id))}
    # @var_index = nil if reset_var_index
    x
  end

  def forall_ids(&f)
    with_bound_ids(f.arity) do |xs|
      forall(
        *f.arity.times.map {|i| [@context.wrap_symbol("x#{i+1}"),@context.resolve(:id)]},
        f.call(*xs)
        # patterns: [pattern(*xs.map{|o| c(o)})]
      )
    end
  end

  def exists_ids(&f)
    with_bound_ids(f.arity) do |xs|
      exists(
        *f.arity.times.map {|i| [@context.wrap_symbol("x#{i+1}"),@context.resolve(:id)]},
        # xs.map{|o| c(o)}.reduce(:&) &
        f.call(*xs)
        # patterns: [pattern(*xs.map{|o| p(o)})]
      )
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

  def on_init()
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
        y << (e(:add) != e(:remove))

        # an add for every remove
        y << forall_ids {|r| (c(r) & rem(r) & !empty(r)).implies(exists_ids {|a| add(a) & (arg(a,0) == ret(r,0))})}

        # adds before removes
        y << forall_ids {|a,r| (c(a) & c(r) & match(a,r)).implies(before(a,r))}

        # unique removes
        y << forall_ids {|r1,r2| (c(r1) & c(r2) & (r1 != r2) & rem(r1) & rem(r2) & !empty(r1)).implies(ret(r1,0) != ret(r2,0))}

        # adds removed before empty
        y << forall_ids {|a,r,e| (c(a) & c(r) & c(e) & match(a,r) & empty(e) & before(a,e)).implies(before(r,e))}

        # unmatched adds before empty
        # y << forall_ids {|a,e| (c(a) & c(e) & unmatched(a) & empty(e)).implies(before(e,a))}
      end

      if object =~ /queue/
        decl_const :enqueue, :method
        decl_const :dequeue, :method

        y << (e(:enqueue) == e(:add))
        y << (e(:dequeue) == e(:remove))

        # fifo order
        y << forall_ids {|a1,r1,a2,r2| (c(a1) & c(a1) & c(a2) & c(r2) & (a1 != a2) & match(a1,r1) & match(a2,r2) & before(a1,a2)).implies(before(r1,r2))}
        y << forall_ids {|a1,r1,a2| (c(a1) & c(r1) & c(a2) & (a1 != a2) & match(a1,r1) & unmatched(a2)).implies(before(a1,a2))}
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

  def on_call(id, history)
    decl_const "o#{id}", :id
    history.arguments(id).each {|v| decl_const "v#{v}", :value}
    Enumerator.new do |y|
      history.each {|j| y << (e(op(id)) != e(op(j))) unless j == id}
      y << (meth(e(op(id))) == e(history.method_name(id)))
      history.arguments(id).each_with_index.map do |v,i|
        y << (e(val(v)) != e(val(:empty)))
        y << (arg(e(op(id)),i) == e(val(v)))
      end
      history.before(id).each {|j| y << before(e(op(j)), e(op(id)))}
      y << p(e(op(id)))
    end
  end

  def on_return(id, history)
    history.returns(id).each {|v| decl_const "v#{v}", :value}
    Enumerator.new do |y|
      history.returns(id).each_with_index.map do |v,i|
        y << (e(val(v)) != e(val(:empty))) unless v == :empty
        y << (ret(e(op(id)),i) == e(val(v)))
      end
      y << c(e(op(id)))
    end
  end

  def only(history)
    Enumerator.new do |y|
      y << forall_ids {|o| disj(*history.map{|j| o == e(op(j))})}
      y << distinct(*history.values.map{|v| e(val(v))})
    end
  end

end

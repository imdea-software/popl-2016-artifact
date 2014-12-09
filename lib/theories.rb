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

  def p(o)            e(:p, o) end
  def c(o)            e(:c, o) end
  def meth(o)         e(:mth, o) end
  def arg(o,i)        e(:arg, o, e(i)) end
  def ret(o,i)        e(:ret, o, e(i)) end
  def before(o,p)     e(:bef, o, p) end

  def match(o,p)      e(:match, o, p) end
  def unmatched(o)    e(:unmatched, o) end
  def match_group(o)  e(:grp, o) end
  def match_source(o) e(:src, o) end

  def add(a)        meth(a) == e(:add) end
  def rem(a)        meth(a) == e(:remove) end
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
    decl_sort :group

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :match, :id, :id, :bool
    decl_const :unmatched, :id, :bool
    decl_const :grp, :id, :group
    decl_const :src, :id, :bool

    decl_const :c, :id, :bool
    decl_const :p, :id, :bool

    Enumerator.new do |y|

      # before is transitive
      y << forall_ids {|i,j,k| (before(i,j) & before(j,k)).implies(before(i,k))}

      # before is antisymmetric
      y << forall_ids {|i,j| (before(i,j) & before(j,i)).implies(i == j)}
      
      # something about matching
      y << forall_ids {|i,j| match(i,j) == ((match_group(i) == match_group(j)) & match_source(i) & !match_source(j))}
      y << forall_ids {|i| unmatched(i) == (match_source(i) & !exists_ids{|j| c(j) & match(i,j)})}

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

  def omap(o) e(:omap, o) end
  def odom(o) e(:odom, o) end
  def gmap(g) e(:gmap, g) end
  def gdom(g) e(:gdom, g) end

  def weaker_than(h1, h2, object: nil)
    decl_sort :id
    decl_sort :method
    decl_sort :value

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :c, :id, :bool
    decl_const :p, :id, :bool

    decl_const :add, :method
    decl_const :remove, :method
    decl_const :rm, :method
    decl_const val(:empty), :value

    decl_const :omap, :id, :id
    decl_const :odom, :id, :bool
    decl_const :gmap, :group, :group
    decl_const :gdom, :group, :bool

    Enumerator.new do |y|
      op2 = Proc.new {|id| "p#{id}".to_sym}
      gp2 = Proc.new {|g| "f#{g}".to_sym}

      m1 = Matcher.new(object, h1)
      m2 = Matcher.new(object, h2)

      puts "CHECKING WEAKER_THAN\n#{h1}\n#{m1}\n#{h2}\n#{m2}"

      history(h1, matcher: m1).each(&y.method(:yield))
      history(h2, op:op2, matcher: m2).each(&y.method(:yield))

      h2.each do |id|
        y << odom(e(op2.call(id)))
        y << gdom(e(gp2.call(m2.group_of(id)))) if m2.source?(id) || h2.completed?(id)
      end

      # injective operation mapping
      y << forall_ids {|i,j| (odom(i) & odom(j) & (omap(i) == omap(j))).implies(i == j)}

      # injective group mapping
      y << forall_ids {|i,j| (odom(i) & odom(j) & (match_group(omap(i)) == match_group(omap(j)))).implies(match_group(i) == match_group(j))}

      # operation mapping consistent with grouping
      y << forall_ids {|i| odom(i).implies(gmap(match_group(i)) == match_group(omap(i)))}

      # operation mapping consistent with matching
      y << forall_ids {|i,j| (odom(i) & odom(j) & match(omap(i),omap(j))).implies(match(i,j))}

      # operation mapping consistent with order
      y << forall_ids {|i,j| (odom(i) & odom(j) & before(omap(i),omap(j))).implies(before(i,j))}
    end
  end

  def history(h, order: nil, op: method(:default_op), val: method(:default_val), matcher: nil)
    h.each {|id| decl_const op.call(id), :id}
    h.values.each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      h.each do |id|
        called(id, h, order:order, op:op, val:val, matcher:matcher).each(&y.method(:yield))
        returned(id,h, op:op, val:val, matcher:matcher).each(&y.method(:yield)) if h.completed?(id)
      end
      domains(h, op:op, val:val).each(&y.method(:yield))

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

  def called(id, history, order: nil, op: method(:default_op), val: method(:default_val), matcher: nil)
    decl_const op.call(id), :id
    history.arguments(id).each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      history.each {|j| y << (e(op.call(id)) != e(op.call(j))) unless j == id}
      y << (meth(e(op.call(id))) == e(history.method_name(id)))
      history.arguments(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val.call(v)) != e(val.call(u))) unless u == v} # TODO collection specific
        y << (e(val.call(v)) != e(val.call(:empty))) # TODO collection specific
        y << (arg(e(op.call(id)),i) == e(val.call(v)))
      end
      history.before(id).each {|j| y << before(e(op.call(j)), e(op.call(id)))} unless order
      y << p(e(op.call(id)))
      if matcher
        g = grp.call(matcher.group_of(id))
        if matcher.source?(id)
          decl_const g, :group
          y << match_group(e(op.call(id))) == e(g)
          y << match_source(e(op.call(id)))
        else
          y << !match_source(e(op.call(id)))
        end
      end
    end
  end

  def returned(id, history, op: method(:default_op), val: method(:default_val), matcher: nil)
    history.returns(id).each {|v| decl_const val.call(v), :value}

    Enumerator.new do |y|
      history.returns(id).each_with_index.map do |v,i|
        history.values.each {|u| y << (e(val.call(v)) != e(val.call(u))) unless u == v} # TODO collection specific
        y << (e(val.call(v)) != e(val.call(:empty))) unless v == :empty # TODO collection specific
        y << (ret(e(op.call(id)),i) == e(val.call(v)))
      end
      y << c(e(op.call(id)))
      if matcher && !matcher.source?(id)
        g = grp.call(matcher.group_of(id))
        decl_const g, :group
        y << match_group(e(op.call(id))) == e(g)
      end
    end
  end

  def domains(history, op: method(:default_op), val: method(:default_val))
    Enumerator.new do |y|
      y << forall_ids {|o| disj(*history.map{|j| o == e(op.call(j))})}
    end
  end

end

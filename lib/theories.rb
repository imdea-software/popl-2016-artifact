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

  def default_naming
    unless @default_naming
      @default_naming = Object.new
      def @default_naming.id(i)     "o#{i}" end
      def @default_naming.method(m) "#{m}" end
    end
    @default_naming
  end

  def p(o)            e(:p, o) end
  def c(o)            e(:c, o) end
  def meth(o)         e(:mth, o) end
  def before(o,p)     e(:bef, o, p) end

  def match(o)        e(:match, o) end
  def unmatched(o)    add(o) & !exists_ids_c {|p| rem(p) & (o == match(p))} end

  def add(a)        meth(a) == e(:add) end
  def rem(a)        meth(a) == e(:remove) end

  def with(n, sort)
    reset = @id_number.nil?
    @unique_id ||= 0
    vars = n.times.map {const("x#{@unique_id += 1}", resolve(sort))}
    f = yield vars
    @unique_id = nil if reset
    f
  end

  def with_ids(n, &f)
    with(n,:id,&f)
  end

  def forall_(sort, &f)
    with(f.arity, sort) {|xs| forall(*xs, f.call(*xs))}
  end

  def exists_(sort, &f)
    with(f.arity, sort) {|xs| exists(*xs, f.call(*xs))}
  end

  def forall_ids(&f)
    with_ids(f.arity) {|xs| forall(*xs, f.call(*xs))}
  end

  def exists_ids(&f)
    with_ids(f.arity) {|xs| exists(*xs, f.call(*xs))}
  end

  def forall_ids_c(&f)
    with_ids(f.arity) {|xs| forall(*xs, conj(*xs.map{|id| c(id)}).implies(f.call(*xs)))}
    # patterns: [pattern(*xs.map{|o| c(o)})]
  end

  def exists_ids_c(&f)
    with_ids(f.arity) {|xs| exists(*xs, conj(*xs.map{|id| c(id)}) & f.call(*xs))}
    # patterns: [pattern(*xs.map{|o| c(o)})]
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
    n = default_naming

    decl_sort :id
    decl_sort :method

    decl_const :mth, :id, :method
    decl_const :c, :id, :bool
    decl_const :p, :id, :bool
    decl_const :bef, :id, :id, :bool
    decl_const :match, :id, :id

    Enumerator.new do |y|

      # before is transitive
      y << forall_ids_c {|i,j,k| (before(i,j) & before(j,k)).implies(before(i,k))}

      # before is antisymmetric
      y << forall_ids_c {|i,j| (before(i,j) & before(j,i)).implies(i == j)}
      
      if object =~ /atomic/
        # before is total
        y << forall_ids_c {|i,j| (i == j) | before(i,j) | before(j,i)}
      end

      if object =~ /stack|queue/
        decl_const :add, :method
        decl_const :remove, :method
        decl_const :rm, :method

        y << (e(:rm) == e(:remove))
        y << (e(:add) != e(:remove))

        # TODO REMOVE THIS
        # every remove is matched (with an add, or itself)
        y << forall_ids_c do |r|
          rem(r).implies(exists_ids_c {|a| a == match(r)})
        end

        # matches are ordered
        y << forall_ids_c {|a,r| ((a != r) & (a == match(r))).implies(before(a,r))}

        # unique removes
        y << forall_ids_c do |r1,r2|
          ((r1 != r2) & rem(r1) & rem(r2)).implies(match(r1) != match(r2))
        end

        # adds removed before empty
        y << forall_ids_c {|a,r,e| (add(a) & rem(r) & rem(e) & (a == match(r)) & (e == match(e)) & before(a,e)).implies(before(r,e))}

        # unmatched adds before empty
        y << forall_ids_c {|a,e| (unmatched(a) & rem(e) & (e == match(e))).implies(before(e,a))}
      end

      if object =~ /queue/
        decl_const :enqueue, :method
        decl_const :dequeue, :method

        y << (e(:enqueue) == e(:add))
        y << (e(:dequeue) == e(:remove))

        # fifo order
        y << forall_ids_c {|a1,r1,a2,r2| (add(a1) & rem(r1) & add(a2) & rem(r2) & (a1 == match(r1)) & (a2 == match(r2)) & before(a1,a2)).implies(before(r1,r2))}
        y << forall_ids_c {|a1,r1,a2| (add(a1) & rem(r1) & (a1 == match(r1)) & unmatched(a2)).implies(before(a1,a2))}
      end

      if object =~ /stack/
        decl_const :push, :method
        decl_const :pop, :method

        y << (e(:push) == e(:add))
        y << (e(:pop) == e(:remove))

        # lifo order
        y << forall_ids_c do |a1,r1,a2,r2|
          ((a1 == match(r1)) & (a2 == match(r2)) & before(a1,a2) & before(r1,r2)).implies(before(r1,a2))
        end
        y << forall_ids_c do |a1,r1,a2|
          ((a1 == match(r1)) & unmatched(a2) & before(a1,a2)).implies(before(r1,a2))
        end

      end

    end
  end

  def ordered(h1, h2)
    Enumerator.new do |y|
      decl_sort :id1
      decl_sort :id2
      decl_sort :method

      decl_const :red, :id2, :bool

      decl_const :g, :id1, :id2
      decl_const :dom, :id1, :bool
      decl_const :rng, :id2, :bool

      methods = (h1.method_names + h2.method_names).uniq
      methods.each {|m| decl_const m, :method}
      methods.each {|m1| methods.each {|m2| y << (e(m1) != e(m2)) if m1 != m2}}

      [h1,h2].each_with_index do |h,idx|
        idx = idx + 1
        o = if idx == 1 then "o" else "p" end

        decl_const :"mth#{idx}", :"id#{idx}", :method
        decl_const :"c#{idx}", :"id#{idx}", :bool
        decl_const :"bef#{idx}", :"id#{idx}", :"id#{idx}", :bool
        decl_const :"match#{idx}", :"id#{idx}", :"id#{idx}"
        decl_const :"um#{idx}", :"id#{idx}", :bool
        
        h.each {|id| decl_const :"#{o}#{id}", :"id#{idx}"}
        h.each do |id|
          i = e(:"#{o}#{id}")
          y << (e(:"mth#{idx}",i) == e(:"#{e(h.method_name(id))}"))
          y << if h.completed?(id) then e(:"c#{idx}",i) else !e(:"c#{idx}",i) end
          if h.match(id)
            y << (e(:"match#{idx}",i) == e(:"#{o}#{h.match(id)}"))
            y << !e(:"um#{idx}",i)
          elsif h.completed?(id)
            y << e(:"um#{idx}",i)
          end

          h.each do |jd|
            next if id == jd
            y << (e(:"#{o}#{id}") != e(:"#{o}#{jd}"))
            j = e(:"#{o}#{jd}")
            y << if h.before?(id,jd) then e(:"bef#{idx}",i,j) else !e(:"bef#{idx}",i,j) end
          end
        end
      end

      h1.completed.each {|id| y << e(:dom,e(:"o#{id}"))}
      h2.each do |id|
        i = e(:"p#{id}")
        ids = h2.select {|jd| id != jd && h2.identical(id,jd)}
        y << e(:red,i).implies(disj(*ids.map{|jd| !e(:red,e(:"p#{jd}"))}))
      end

      # identifiers are bounded
      y << forall_(:id1) {|i| disj(*h1.map{|id| i == e(:"o#{id}")})}
      y << forall_(:id2) {|i| disj(*h2.map{|id| i == e(:"p#{id}")})}

      # labels are preserved
      y << forall_(:id1) {|i| e(:dom,i).implies(e(:mth1,i) == e(:mth2,e(:g,i)))}

      # completion is preserved
      y << forall_(:id1) {|i| (e(:dom,i) & e(:c1,i)).implies(e(:c2,e(:g,i)))}

      # order is preserved
      y << forall_(:id1) {|i,j| (e(:dom,i) & e(:dom,j) & e(:bef1,i,j)).implies(e(:bef2,e(:g,i),e(:g,j)))}

      # matching is preserved
      y << forall_(:id1) {|i,j| (e(:dom,i) & e(:dom,j) & (e(:match1,i) == j)).implies(e(:match2,e(:g,i)) == e(:g,j))}
      y << forall_(:id1) {|i| e(:um1,i).implies(e(:um2,e(:g,i)))}

      # TODO DO WE REALLY NEED THESE?
      # mapping takes entire match groups
      y << forall_(:id1) {|i,j| (e(:dom,i) & (e(:match1,i) == j)).implies(e(:dom,j))}
      y << forall_(:id1) {|i,j| (e(:dom,j) & (e(:match1,i) == j)).implies(e(:dom,i))}
      y << forall_(:id2) {|i,j| (e(:rng,i) & (e(:match2,i) == j) & !e(:red,j)).implies(e(:rng,j))}
      y << forall_(:id2) {|i,j| (e(:rng,j) & (e(:match2,i) == j) & !e(:red,i)).implies(e(:rng,i))}

      # mapping is injective
      y << forall_(:id1) {|i,j| (e(:dom,i) & e(:dom,j) & (e(:g,i) == e(:g,j))).implies(i == j)}

      # the mapping has a named range
      y << forall_(:id1) {|i| e(:dom,i).implies(e(:rng,e(:g,i)))}
      y << forall_(:id2) {|i| e(:rng,i).implies(disj(*h1.map{|j| e(:dom,e(:"o#{j}")) & (i == e(:g,e(:"o#{j}")))}))}

    end
  end

  def history(h, order: nil)
    n = default_naming
    h.each {|id| decl_const n.id(id), :id}

    Enumerator.new do |y|
      h.each do |id|
        called(id, h, order:order).each(&y.method(:yield))
        returned(id, h).each(&y.method(:yield)) if h.completed?(id)
      end
      domains(h).each(&y.method(:yield))

      case order
      when Array; order.each_cons(2)
      when Enumerator; order
      else []
      end.each do |i,j|
        y << c(e(n.id(i)))
        y << before(e(n.id(i)),e(n.id(j)))
      end
    end
  end

  def called(id, history, order: nil)
    n = default_naming
    m = history.match(id)
    decl_const n.id(id), :id
    Enumerator.new do |y|
      history.each {|j| y << (e(n.id(id)) != e(n.id(j))) unless j == id}
      y << (meth(e(n.id(id))) == e(n.method(history.method_name(id))))
      history.before(id).each {|j| y << before(e(n.id(j)), e(n.id(id)))} unless order
      y << (match(e(n.id(id))) == e(n.id(m))) if m
      y << p(e(n.id(id)))
    end
  end

  def returned(id, history)
    n = default_naming
    m = history.match(id)
    Enumerator.new do |y|
      y << (match(e(n.id(id))) == e(n.id(m))) if m
      y << c(e(n.id(id)))
    end
  end

  def domains(history)
    n = default_naming
    Enumerator.new do |y|
      y << forall_ids_c {|o| disj(*history.map{|j| o == e(n.id(j))})}
      history.completed.each do |id|
        next if history.match(id)
        history.each do |jd|
          y << (match(e(n.id(id))) != e(n.id(jd)))
        end
      end
    end
  end

end

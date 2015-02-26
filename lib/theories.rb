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

  def default_naming
    unless @default_naming
      @default_naming = Object.new
      def @default_naming.id(i)     "o#{i}" end
      def @default_naming.value(v)  "v#{v}" end
      def @default_naming.method(m) "#{m}" end
    end
    @default_naming
  end

  def alternate_naming
    unless @alternate_naming
      @alternate_naming = Object.new
      def @alternate_naming.id(i)     "p#{i}" end
      def @alternate_naming.value(v)  "u#{v}" end
      def @alternate_naming.method(m) "#{m}" end
    end
    @alternate_naming
  end

  def p(o)            e(:p, o) end
  def c(o)            e(:c, o) end
  def meth(o)         e(:mth, o) end
  def arg(o,i)        e(:arg, o, e(i)) end
  def ret(o,i)        e(:ret, o, e(i)) end
  def before(o,p)     e(:bef, o, p) end

  def match(o,p)      o == e(:match, p) end
  def sink(o)         !match(e(:no_match),o) end
  def unmatched(o)    !sink(o) & !exists_ids_c {|p| match(o,p)} end

  def add(a)        meth(a) == e(:add) end
  def rem(a)        meth(a) == e(:remove) end

  def with_ids(n)
    reset = @id_number.nil?
    @unique_id ||= 0
    vars = n.times.map {const("x#{@unique_id += 1}", id_sort)}
    f = yield vars
    @unique_id = nil if reset
    f
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

  def declarations
    decl_sort :id
    decl_sort :method
    decl_sort :value
    decl_sort :group

    decl_const :mth, :id, :method
    decl_const :arg, :id, :int, :value
    decl_const :ret, :id, :int, :value
    decl_const :bef, :id, :id, :bool

    decl_const :match, :id, :id
    decl_const :no_match, :id

    decl_const :c, :id, :bool
    decl_const :p, :id, :bool
  end

  def theory(object, naming: default_naming)
    n = naming
    declarations

    Enumerator.new do |y|

      y << !p(e(:no_match))
      y << !c(e(:no_match))

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

        # every remove is matched (with an add, or itself)
        y << forall_ids_c do |r|
          sink(r).implies(exists_ids_c {|a| match(a,r)})
        end

        # matches are ordered
        y << forall_ids_c {|a,r| ((a != r) & match(a,r)).implies(before(a,r))}

        # unique removes
        y << forall_ids_c do |r1,r2|
          ((r1 != r2) & sink(r1) & sink(r2)).implies(e(:match,r1) != e(:match,r2))
        end

        # adds removed before empty
        y << forall_ids_c {|a,r,e| (match(a,r) & match(e,e) & before(a,e)).implies(before(r,e))}

        # unmatched adds before empty
        y << forall_ids_c {|a,e| (unmatched(a) & match(e,e)).implies(before(e,a))}
      end

      if object =~ /queue/
        decl_const :enqueue, :method
        decl_const :dequeue, :method

        y << (e(:enqueue) == e(:add))
        y << (e(:dequeue) == e(:remove))

        # fifo order
        y << forall_ids_c {|a1,r1,a2,r2| (match(a1,r1) & match(a2,r2) & before(a1,a2)).implies(before(r1,r2))}
        y << forall_ids_c {|a1,r1,a2| ((a1 != a2) & match(a1,r1) & unmatched(a2)).implies(before(a1,a2))}
      end

      if object =~ /stack/
        decl_const :push, :method
        decl_const :pop, :method

        y << (e(:push) == e(:add))
        y << (e(:pop) == e(:remove))

        # lifo order
        y << forall_ids_c do |a1,r1,a2,r2|
          (match(a1,r1) & match(a2,r2) & before(a1,a2) & before(r1,r2)).implies(before(r1,a2))
        end
        y << forall_ids_c do |a1,r1,a2|
          (match(a1,r1) & unmatched(a2) & before(a1,a2)).implies(before(r1,a2))
        end

      end

    end
  end

  def embedding(h2, h1)
    Enumerator.new do |y|
      n1 = default_naming
      n2 = alternate_naming

      declarations
      decl_const :g, :id, :id
      decl_const :dom, :id, :bool
      decl_const :rng, :id, :bool
      decl_const :codom, :id, :bool

      methods = (h1.method_names + h2.method_names).uniq
      methods.each {|m| decl_const m, :method}
      methods.each {|m1| methods.each {|m2| y << (e(m1) != e(m2)) if m1 != m2}}

      history(h1, naming:n1, alone:false, order:false).each(&y.method(:yield))
      history(h2, naming:n2, alone:false, order:false).each(&y.method(:yield))

      h1.each do |id|
        y << e(:codom, e(n1.id(id)))
        y << (h1.completed?(id) ? c(e(n1.id(id))) : !c(e(n1.id(id))))
        h1.each do |jd|
          next if id == jd
          if h1.before?(id,jd)
            y << before(e(n1.id(id)),e(n1.id(jd)))
          else
            y << !before(e(n1.id(id)),e(n1.id(jd)))
          end
        end
      end
      h2.each do |id|
        y << e(:dom, e(n2.id(id)))
        y << (h2.completed?(id) ? c(e(n2.id(id))) : !c(e(n2.id(id))))
        h2.each do |jd|
          next if id == jd
          if h2.before?(id,jd)
            y << before(e(n2.id(id)),e(n2.id(jd)))
          else
            y << !before(e(n2.id(id)),e(n2.id(jd)))
          end
        end
      end
      y << forall_ids {|o| e(:dom,o).implies(disj(*h2.map{|id| o == e(n2.id(id))}))}
      y << forall_ids {|o| e(:codom,o).implies(disj(*h1.map{|id| o == e(n1.id(id))}))}
      y << forall_ids {|o| e(:rng,o).implies(e(:codom,o))}

      y << forall_ids {|o| e(:dom,o).implies(e(:rng,e(:g,o)))}
      y << forall_ids {|o| e(:rng,o).implies(disj(*h2.map{|id| o == e(:g,e(n2.id(id)))}))}

      # mapping is injective
      y << forall_ids {|o,p| (e(:dom,o) & e(:dom,p) & (e(:g,o) == e(:g,p))).implies(o == p)}

      # mapping is consistent with method naming (?)
      y << forall_ids {|i| e(:dom,i).implies(meth(i) == meth(e(:g,i)))}

      # mapping is consistent with completed operations
      y << forall_ids {|i| e(:dom,i).implies(c(i) === c(e(:g,i)))}

      # mapping takes entire match groups
      y << forall_ids {|i,j| (e(:rng,i) & e(:codom,j) & match(i,j)).implies(e(:rng,j))}
      y << forall_ids {|i,j| (e(:codom,i) & e(:rng,j) & match(i,j)).implies(e(:rng,i))}

      # mapping is consistent with matching
      y << forall_ids {|i,j| (e(:dom,i) & e(:dom,j)).implies(match(i,j) === match(e(:g,i),e(:g,j)))}

      # mapping is consistent with order
      y << forall_ids {|i,j| (e(:dom,i) & e(:dom,j)).implies(before(i,j) === before(e(:g,i),e(:g,j)))}
    end
  end

  def weaker_than(h1, h2)
    Enumerator.new do |y|
      n1 = default_naming
      n2 = alternate_naming

      declarations
      decl_const :g, :id, :id
      decl_const :dom, :id, :bool
      decl_const :rng, :id, :bool

      methods = (h1.method_names + h2.method_names).uniq
      methods.each {|m| decl_const m, :method}
      methods.each {|m1| methods.each {|m2| y << (e(m1) != e(m2)) if m1 != m2}}

      history(h1, naming:n1, alone:false).each(&y.method(:yield))
      history(h2, naming:n2, alone:false).each(&y.method(:yield))

      h1.each do |id|
        y << e(:rng, e(n1.id(id))) if h1.completed?(id)
        y << (h1.completed?(id) ? c(e(n1.id(id))) : !c(e(n1.id(id))))
      end
      h2.each do |id|
        y << e(:dom, e(n2.id(id)))
        y << (h2.completed?(id) ? c(e(n2.id(id))) : !c(e(n2.id(id))))
      end
      y << forall_ids {|o| e(:dom,o).implies(disj(*h2.map{|id| o == e(n2.id(id))}))}
      y << forall_ids {|o| (e(:dom,o)).implies(e(:rng,e(:g,o)))}
      y << forall_ids {|o| e(:rng,o).implies(disj(*h1.map{|id| o == e(n1.id(id))}))}

      # mapping is injective
      y << forall_ids {|o,p| (e(:dom,o) & e(:dom,p) & (e(:g,o) == e(:g,p))).implies(o == p)}

      # mapping is consistent with method naming (?)
      y << forall_ids {|i| e(:dom,i).implies(meth(i) == meth(e(:g,i)))}

      # mapping is consistent with completed operations
      y << forall_ids {|i| (e(:dom,i) & c(e(:g,i))).implies(c(i))}

      # mapping is consistent with matching
      y << forall_ids {|i,j| (e(:dom,i) & e(:dom,j) & match(e(:g,i),e(:g,j))).implies(match(i,j))}
      y << forall_ids {|o,p| (e(:dom,o) & e(:dom,p) & match(o,p) & !match(e(:g,o),e(:g,p))).implies(!c(e(:g,p)))}

      # mapping is consistent with order
      y << forall_ids {|i,j| (e(:dom,i) & e(:dom,j) & before(e(:g,i),e(:g,j))).implies(before(i,j))}
    end
  end

  def history(h, order: nil, naming: default_naming, alone: true)
    n = naming
    h.each {|id| decl_const n.id(id), :id}
    h.values.each {|v| decl_const n.value(v), :value}

    Enumerator.new do |y|
      h.each do |id|
        called(id, h, order:order, naming:n).each(&y.method(:yield))
        returned(id, h, naming:n).each(&y.method(:yield)) if h.completed?(id)
      end
      domains(h, naming:n).each(&y.method(:yield)) if alone

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

  def called(id, history, order: nil, naming: default_naming)
    n = naming
    m = history.match(id)
    decl_const n.id(id), :id
    history.arguments(id).each {|v| decl_const n.value(v), :value}

    Enumerator.new do |y|
      history.each {|j| y << (e(n.id(id)) != e(n.id(j))) unless j == id}
      y << (e(n.id(id)) != e(:no_match))
      y << (meth(e(n.id(id))) == e(n.method(history.method_name(id))))
      history.arguments(id).each_with_index.map do |v,i|
        # TODO assert distinct values?
        y << (arg(e(n.id(id)),i) == e(n.value(v)))
      end
      history.before(id).each {|j| y << before(e(n.id(j)), e(n.id(id)))} unless order
      y << match(e(m == :none ? :no_match : n.id(m)), e(n.id(id))) if m
      y << !match(e(:no_match), e(n.id(id))) unless m
      y << p(e(n.id(id)))
    end
  end

  def returned(id, history, naming: default_naming)
    n = naming
    m = history.match(id)
    history.returns(id).each {|v| decl_const n.value(v), :value}

    Enumerator.new do |y|
      history.returns(id).each_with_index.map do |v,i|
        # TODO assert distinct values?
        y << (ret(e(n.id(id)),i) == e(n.value(v)))
      end
      if m
        y << match(e(m == :none ? :no_match : n.id(m)), e(n.id(id)))
      else
        y << !match(e(:no_match), e(n.id(id)))
        history.each {|j| y << !match(e(n.id(j)),e(n.id(id)))}
      end
      y << c(e(n.id(id)))
    end
  end

  def domains(history, naming: default_naming)
    n = naming
    Enumerator.new do |y|
      y << forall_ids_c {|o| disj(*history.map{|j| o == e(n.id(j))})}
    end
  end

end

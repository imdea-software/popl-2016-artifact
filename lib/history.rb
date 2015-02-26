require_relative 'matching'

class History
  include Enumerable

  def initialize
    @unique_id = 0
    @completed = []
    @pending = []
    @method_names = {}
    @arguments = {}
    @returns = {}
    @before = {}
    @after = {}
    @ext_before = {}
    @ext_after = {}
    @dependencies = {}
    @match = {}
    @observers = []
  end

  def initialize_copy(other)
    super
    @completed = @completed.clone
    @pending = @pending.clone
    @method_names = @method_names.clone
    @arguments = @arguments.clone
    @returns = @returns.clone
    @before = @before.clone
    @after = @after.clone
    @ext_before = @ext_before.clone
    @ext_after = @ext_after.clone
    @before.values.map {|ops| ops.clone}
    @before.each {|id,ops| @before[id] = ops.clone}
    @after.each {|id,ops| @after[id] = ops.clone}
    @ext_before.each {|id,ops| @ext_before[id] = ops.clone}
    @ext_after.each {|id,ops| @ext_after[id] = ops.clone}
    @dependencies = @dependencies.clone
    @dependencies.each {|id,ops| @dependencies[id] = ops.clone}
    @match = @match.clone
    @observers = []
  end

  def each(&block)
    if block_given?
      @completed.each(&block)
      @pending.each(&block)
      self
    else
      to_enum
    end
  end

  def empty?;             count == 0 end
  def include?(id)        !@method_names[id].nil? end
  def pending;            @pending end
  def pending?(id)        @returns[id].nil? end
  def completed;          @completed end
  def completed?(id)      !pending?(id) end
  def complete?;          @pending.empty? end

  def ext_completed?(id)  @dependencies[id].empty? end

  # TODO unclear whether this is only valid for intervla orders...
  def sequential?;        @before.values.map(&:count).uniq.count == count end

  def method_name(id)     @method_names[id] end
  def arguments(id)       @arguments[id] end
  def returns(id)         @returns[id] end

  def before?(i1,i2)      before(i2).include?(i1) end
  def before(id)          @before[id] end
  def after(id)           @after[id] end

  def ext_before?(i1,i2)  ext_before(i2).include?(i1) end
  def ext_before(id)      @before[id] + @ext_before[id] end
  def ext_after(id)       @after[id] + @ext_after[id] end

  def match(id)           @match[id] end
  def num_matches;        select {|id| [nil, :none, id].include?(match(id))}.length end

  def minimals;           select {|id| before(id).empty? } end
  def maximals;           select {|id| after(id).empty? } end

  def start(m,*args)      h = clone; id = h.start!(m,*args); [h,id] end
  def complete(id,*rets)  clone.complete!(id,*rets) end
  def remove(id)          clone.remove!(id) end
  def uncomplete(id)      clone.uncomplete!(id) end
  def unorder(i1,i2)      clone.unorder!(i1,i2) end

  def matches
    ms = {}
    each do |id|
      m = match(id)
      m = id if m.nil? || m == :none
      ms[m] ||= []
      ms[m] << id
    end
    ms
  end

  def identical(i1,i2)
    match(i1) && match(i2) &&
    match(i1) == match(i2) &&
    method_name(i1) == method_name(i2) &&
    arguments(i1) == arguments(i2) &&
    returns(i1) == returns(i2)
  end

  def self.from_enum(e)
    h = self.new
    e.each do |meth, args, rets|
      h.complete!(h.start!(meth, *args), *rets)
    end
    h
  end

  def update(act,*args)
    case act
    when :start;      start!(*args)
    when :complete;   complete!(*args)
    else              fail "Unexpected history update."
    end
  end

  def to_s
    if interval_order?
      str = to_interval_s
    else
      str = to_partial_order_s
    end
    extras = @ext_after.map{|a,ids| "#{a} < #{ids * ", "}" unless ids.empty?}.compact
    str << "\n" + extras * "\n" unless extras.empty?
    str
  end

  def method_names; @method_names.values.uniq end
  def values; (@arguments.values + @returns.values).flatten(1).uniq end

  def interval_order?
    @before.values.sort_by(&:count).each_cons(2).all?{|p,q| (p-q).empty?}
  end

  def intervals
    past = @before.values.map(&:count).uniq.sort.map.with_index.to_h
    future = @after.values.map(&:count).uniq.sort.reverse.map.with_index.to_h
    unless (n = past.count) == future.count
      fail "PROBLEM: #PASTS != #FUTURES\nbefore: #{@before}\nafter: #{@after}"
    end
    [n, each.map{|id| [id,[past[before(id).count], future[after(id).count]]]}.to_h]
  end

  def label(id)
    str = ""
    str << @method_names[id]
    str << "(#{@arguments[id] * ", "})" unless @arguments[id].empty?
    if pending?(id)
      str << "*"
    elsif !@returns[id].empty?
      str << " => #{@returns[id] * ", "}"
    end
    str
  end

  def match_s(id)
    m = match(id)
    "[#{id}#{m.nil? ? ":_" : m != :none ? ":#{m}" : ""}]"
  end

  def to_partial_order_s
    ops = each.map do |id|
      [id, [match_s(id), label(id)]]
    end.to_h
    id_j = ops.values.map{|id,_| id.length}.max
    op_j = ops.values.map{|_,op| op.length}.max
    each.map do |id|
      str = "#{ops[id][0].ljust(id_j)} #{ops[id][1].ljust(op_j)}"
      str << "  --> #{after(id).map{|i| "[#{i}]"} * ", "}" unless after(id).empty?
      str
    end * "\n"
  end

  def to_interval_s(scale: 2)
    n, imap = intervals
    ops = each.map do |id|
      [id,[match_s(id),label(id)]]
    end.to_h
    id_j = ops.values.map{|id,_| id.length}.max
    op_j = ops.values.map{|_,op| op.length}.max
    each.map do |id|
      i, j = imap[id].map{|x| x*scale}
      "#{ops[id][0].ljust(id_j)} #{ops[id][1].ljust(op_j)}  #{' ' * i}#{'#' * (j-i+1)}"
    end * "\n"
  end

  def add_observer(o)         @observers << o if o end
  def notify_observers(*args) @observers.each {|o| o.update(*args)} end

  def start!(m,*args)
    # fail "Unexpected arguments." unless args.all?{|x| x.is_a?(Symbol)}
    id = (@unique_id += 1)
    @pending << id
    @method_names[id] = m.to_s
    @arguments[id] = args
    @returns[id] = nil
    @before[id] = []
    @after[id] = []
    @ext_before[id] = []
    @ext_after[id] = []
    @dependencies[id] = []
    @before[id].push *@completed
    @completed.each do |c|
      @after[c] << id
      @ext_before[c].each do |b|
        next if ext_before?(b,id)
        @ext_after[b] << id
        @ext_before[id] << b
      end
      @match[c] = id if @match[c].nil? && Matching.get(self,c) == id
    end
    @match[id] = Matching.get(self,id)
    notify_observers :start, id, m, *args
    id
  end

  def complete!(id,*rets)
    fail "Operation #{id} not present."     unless include?(id)
    fail "Operation #{id} already updated." unless pending?(id)
    # fail "Unexpected returns." unless rets.all?{|x| x.is_a?(Symbol)}
    @pending.delete id
    @completed << id
    @returns[id] = rets
    @dependencies[id] = @pending.clone
    @dependencies.each {|_,ops| ops.delete id}
    @match[id] = Matching.get(self,id)
    notify_observers :complete, id, *rets
    self
  end

  def remove!(id)
    fail "Operation #{id} not present." unless include?(id)
    notify_observers :remove, id
    @completed.delete id
    @pending.delete id
    @method_names.delete id
    @arguments.delete id
    @returns.delete id
    @before.delete id
    @before.each {|_,ops| ops.delete id}
    @after.delete id
    @after.each {|_,ops| ops.delete id}
    @ext_before.delete id
    @ext_before.each {|_,ops| ops.delete id}
    @ext_after.delete id
    @ext_after.each {|_,ops| ops.delete id}
    @dependencies.delete id
    @dependencies.each {|_,ops| ops.delete id}
    @match.delete id
    @match.reject! {|_,m| m == id}
    self
  end

  def uncomplete!(id)
    fail "Operation #{id} not present." unless include?(id)
    fail "Operation #{id} already pending." if pending?(id)
    @pending << id
    @completed.delete id
    @returns[id] = nil
    @before.each {|_,ops| ops.delete id}
    @after[id] = []
    @dependencies[id] = [] # TODO correct those depending on self?
    @match.delete id
    self
  end

  def unorder!(x,y)
    return self unless before?(x,y)
    return self if any? {|id| before?(x,id) && before?(id,y)}
    @before[y].delete x
    @after[x].delete y
    self
  end

  def order!(x,y)
    return self if ext_before?(x,y)
    @ext_before[y] << x
    @ext_after[x] << y
    ext_before(x).each do |w|
      next if ext_before?(w,y)
      @ext_before[y] << w
      @ext_after[w] << y
    end
    ext_after(y).each do |z|
      next if ext_before?(x,z)
      @ext_before[z] << x
      @ext_after[x] << z
    end
    self
  end

  def completions(completer)
    Enumerator.new do |y|
      partials = []
      partials << self

      while !partials.empty? do
        h = partials.shift
        if h.complete?
          y << h
        else
          p = h.instance_variable_get('@pending').first
          partials << h.remove(p)
          completer.call(h,p).each do |rets|
            partials << h.complete(p,*rets)
          end
        end
      end
    end
  end

  def linearizations()
    Enumerator.new do |y|
      partials = []
      partials << [[], self]

      while !partials.empty? do
        seq, h = partials.shift
        if h.empty?
          y << seq
        else
          h.minimals.each do |id|
            partials << [seq + [id], h.remove(id)]
          end
        end
      end
    end
  end

  def uncomplete_once
    completed.each do |c|
      next if any? {|id| before?(c,id)}
      w = uncomplete(c)
      return w if yield(w)
    end
    return nil
  end

  def unorder_once
    completed.each do |x|
      after(x).each do |y|
        next if any? {|id| before?(x,id) && before?(id,y)}
        w = unorder(x,y)
        return w if yield(w)
      end
    end
    return nil
  end

  def remove_one_match
    # TODO
  end

  def prune_once
    each do |p|
      next unless any? {|id| id != p && identical(id,p)}
      w = remove(p)
      return w if yield(w)
    end
    return nil
  end

  def weaken(make_pending: false, &blk)
    h = self
    fail "Expected predicate block." unless block_given?
    fail "History does not satisfy predicate." unless yield(h)
    while (make_pending && w = h.uncomplete_once(&blk)) || w = h.unorder_once(&blk) || w = h.prune_once(&blk) do h = w end
    return h
  end

end

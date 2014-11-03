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
    @before.each {|id,ops| @before[id] = ops.clone}
    @after.each {|id,ops| @after[id] = ops.clone}
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

  def before(id)          @before[id] end
  def after(id)           @after[id] end
  def minimals;           select {|id| before(id).empty? } end
  def maximals;           select {|id| after(id).empty? } end

  def start(m,*args)      clone.start!(m,*args) end
  def complete(id,*rets)  clone.complete!(id,*rets) end
  def remove(id)          clone.remove!(id) end

  def update(act,*args)
    case act
    when :start;      start!(args[0], args.drop(1))
    when :complete;   complete!(args[0], args.drop(1))
    else              fail "Unexpected history update."
    end
  end

  def to_s; to_interval_s end

  def intervals
    past = @before.values.map{|ops| ops.count}.uniq.sort.map.with_index{|c,i| [c,i]}.to_h
    future = @after.values.map{|ops| ops.count}.uniq.sort.reverse.map.with_index{|c,i| [c,i]}.to_h
    fail "Uh oh..." unless n = past.count == future.count
    [n, each.map{|id| [id,[past[before(id).count], future[after(id).count]]]}.to_h]
  end

  def op_to_s(id)
    str = ""
    str << @method_names[id]
    str << "(#{@arguments[id] * ", "})" unless @arguments[id].empty?
    if @returns[id].nil?
      str << "*"
    elsif !@returns[id].empty?
      str << " => #{@returns[id] * ", "}"
    end
    str
  end

  def to_interval_s(scale: 2)
    n, imap = intervals
    ops = each.map{|id| [id,["[#{id}]",op_to_s(id)]]}.to_h
    id_j = ops.values.map{|id,_| id.length}.max
    op_j = ops.values.map{|_,op| op.length}.max
    each.map do |id|
      i, j = imap[id].map{|x| x*scale}
      "#{ops[id][0].ljust(id_j)} #{ops[id][1].ljust(op_j)}  #{' ' * i}#{'#' * (j-i+1)}"
    end * "\n"
  end

  def start!(m,*args)
    id = (@unique_id += 1)
    @pending << id
    @method_names[id] = m.to_s
    @arguments[id] = args
    @returns[id] = nil
    @completed.each {|c| @after[c] << id}
    @before[id] = []
    @before[id].push *@completed
    @after[id] = []
    [id, self]
  end

  def complete!(id,*rets)
    fail "Operation #{id} already updated." if @returns[id]
    @pending.delete id
    @completed << id
    @returns[id] = rets
    self
  end

  def remove!(id)
    fail "Operation #{id} not present." unless @method_names[id]
    @completed.delete id
    @pending.delete id
    @method_names.delete id
    @arguments.delete id
    @returns.delete id
    @before.delete id
    @before.each {|_,ops| ops.delete id}
    @after.delete id
    @after.each {|_,ops| ops.delete id}
    self
  end
end

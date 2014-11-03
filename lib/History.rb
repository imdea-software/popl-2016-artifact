class History
  include Enumerable

  def initialize
    @completed = []
    @pending = []
    @before = {}
    @after = {}
  end

  def initialize_copy(other)
    super
    @completed = @completed.clone
    @pending = @pending.clone
    @before = @before.clone
    @after = @after.clone
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

  def before(o) @before[o] end
  def after(o) @after[o] end
  def minimals; select {|o| before(o).empty? } end
  def maximals; select {|o| after(o).empty? } end

  def start(o) clone.start!(o) end
  def finish(o) clone.finish!(o) end
  def remove(o) clone.remove!(o) end

  def start!(o)
    @completed.each {|c| @after[c] << o}
    @pending << o
    @before[o] = []
    @before[o].push *@completed
    @after[o] = []
    self
  end

  def finish!(o)
    @completed << o
    @pending.delete o
    self
  end

  def remove!(o)
    @completed.delete o
    @pending.delete o
    @before.delete o
    @before.each {|_,v| v.delete o}
    @after.delete o
    @after.each {|_,v| v.delete o}
    self
  end
end

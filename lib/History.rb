class History
  include Enumerable

  def initialize
    @completed = []
    @pending = []
    @before = {}
    @after = {}
  end

  def each(&block)
    @completed.each(block)
    @pending.each(block)
  end

  def before(o) @before[o] end
  def after(o) @after[o] end

  def start!(o)
    @completed.each {|c| @after[c] << o}
    @pending << o
    @before[o] = []
    @before[o].push *@completed
    @after[o] = []
    o
  end

  def finish!(o)
    @completed << o
    @pending.delete o
    o
  end

  def remove!(o)
    @completed.delete o
    @pending.delete o
    @before.delete o
    @before.each {|_,v| v.delete o}
    @after.delete o
    @after.each {|_,v| v.delete o}
    o
  end
end

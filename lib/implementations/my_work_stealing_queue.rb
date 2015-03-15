class MyWorkStealingQueue
  include AdtImplementation
  adt_scheme :work_stealing_queue

  attr_accessor :contents, :mutex

  def initialize(take_from: :head, steal_from: :head)
    @contents = []
    @mutex = Mutex.new
    @take_from = take_from.to_sym
    @steal_from = steal_from.to_sym
  end

  def to_s
    "Work-Stealing Queue (take: #{@take_from}, steal: #{@steal_from})"
  end

  def give(val)
    @mutex.synchronize do
      @contents.push val
      nil
    end
  end

  def take
    @mutex.synchronize do
      (case @take_from when :head then @contents.shift else @contents.pop end) || :empty
    end
  end

  def steal
    @mutex.synchronize do
      (case @steal_from when :head then @contents.shift else @contents.pop end) || :empty
    end
  end

end

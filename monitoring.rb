require 'set'

module ConcurrentObject

  class Operation
    attr_accessor :method_name, :arg_value, :return_value
    attr_accessor :start_time, :end_time
    attr_accessor :dependencies

    def initialize(method, val, time)
      start!(method, val, time)
    end

    def start!(method, val, time)
      @method_name = method
      @arg_value = val
      @start_time = time
    end

    def complete!(val, time, pending_ops)
      fail "#{self} already completed!" if completed?
      @return_value = val
      @end_time = time
      @dependencies = pending_ops
    end

    def refresh!
      @dependencies.reject!(&:completed?) if @dependencies
    end

    def to_s
      arg = @arg_value == :unit ? "" : "(#{@arg_value})"
      ret = case @return_value
        when nil; "..."
        when :unit; ""
        else " => #{@return_value}"
      end
      "#{@method_name}#{arg}#{ret}" +
      (obsolete? ? " (X)" : "")
    end

    def pending?; @end_time.nil? end
    def completed?; !pending? end
    def obsolete?; completed? && @dependencies.empty? end
    def impossible?; @end_time && @end_time < @start_time end

    def before?(op) completed? && (op.nil? || @end_time < op.start_time) end

    def before!(op)
      updated = false
      if @end_time && op && op.end_time && @end_time > op.end_time
        @end_time = op.end_time
        updated = true
      end
      if op && op.start_time < @start_time
        op.start_time = @start_time
        updated = true
      end
      updated
    end
  end

  class Monitor
    attr_accessor :operations
    attr_accessor :time
    attr_accessor :mutex

    def initialize
      @operations = []
      @time = 0
      @mutex = Mutex.new
    end

    def create_op(method, val)
      Operation.new(method, val, @time)
    end

    def on_call(method, val)
      op = nil
      @mutex.synchronize do
        op = create_op(method, val)
        @operations << op
        @time += 1
        on_start! op
      end
      return op
    end

    def on_return(op, val)
      @mutex.synchronize do
        op.complete!(val, @time, @operations.select(&:pending?))
        @time += 1
        on_completed! op
        warn "Found a contradiction" if contradiction?
        cleanup!
      end
    end

    def on_start!(op)
      # nothing to do in the default case
    end

    def on_completed!(op)
      # nothing to do in the default case
    end

    def contradiction?
      @operations.any?(&:impossible?)
    end

    def cleanup!
      @operations.each(&:refresh!)
      @operations.reject!(&:obsolete?)
    end

    def stats; {
      time: @time,
      num_ops: @operations.count,
      num_obsolete: @operations.select(&:obsolete?).count
      }
    end

    def to_s
      @operations.map do |op|
        i = op.start_time
        j = op.end_time
        len = (j||time)-i
        if len >= 0
          "#{" " * i}|#{"-" * len}#{j ? "|" : "-"} #{op}"
        else
          "#{" " * i}X #{op}"
        end
      end * "\n"
    end
  end

end

module AtomicStack

  class Operation < ConcurrentObject::Operation
    attr_accessor :match
    alias :default_obsolete? :obsolete?
    def obsolete?
      default_obsolete? &&
      (@match && @match.default_obsolete? || @return_value == :empty)
    end
    def add?; @method_name == :add end
    def remove?; @method_name == :remove end
    def value; add? ? @arg_value : @return_value end
    def empty?; value == :empty end
  end

  class Element
    attr_accessor :add, :remove
    def initialize(add) @add = add end
    def removed?; !@remove.nil? end
    def remove!(remove)
      warn "#{self} already removed!" if removed?
      @remove = remove
      @remove.match = @add
      @add.match = @remove
    end
    def obsolete?; add.obsolete? end
  end

  class Monitor < ConcurrentObject::Monitor
    attr_accessor :elements, :empties

    def initialize
      super
      @elements = {}
      @empties = []
    end

    def create_op(method, val)
      AtomicStack::Operation.new(method, val, @time)
    end

    def on_start!(op)
      @elements[op.value] = Element.new(op) if op.add?
    end

    def on_completed!(op)
      @elements.reject!{|_,e| e.obsolete?}
      @empties.reject!(&:obsolete?)

      if op.empty?
        @empties << op

      elsif op.remove?
        e = @elements[op.value]
        warn "Element #{op.value} removed yet never added!" unless e
        e.remove!(op)
      end

      saturate! op
    end

    def saturate!(op)
      worklist = Set.new
      worklist << op
      while !worklist.empty?
        op = worklist.take(1).first
        worklist.delete(op)

        if op.empty?
          @elements.each do |_,e|
            worklist << e.add << op if apply_empty!(e,op)
          end

        elsif op.value
          e1 = @elements[op.value]
          @elements.each do |_,e2|
            next if e1 == e2
            worklist << e1.add << e2.add if apply_stack_order!(e1,e2)
          end
          @empties.each do |emp|
            worklist << e1.add << emp if apply_empty!(e1,emp)
          end
        end
      end
    end

    def apply_empty!(elem, emp)
      updated = false
      updated ||= elem.remove.before!(emp) if elem.remove && elem.add.before?(emp)
      updated ||= emp.before!(elem.add) if emp.before?(elem.remove)
      updated
    end

    def apply_stack_order!(e1,e2)
      updated = false
      if e1.add.before?(e2.add) && e1.remove && e1.remove.before?(e2.remove)
        updated ||= e1.remove.before!(e2.add)
      end
      if e1.add.before?(e2.add) && e2.add.before?(e1.remove) && e2.remove
        updated ||= e2.remove.before!(e1.remove)
      end
      if e2.add.before?(e1.remove) && e1.remove && e1.remove.before?(e2.remove)
        updated ||= e2.add.before!(e1.add)
      end
      updated
    end
  end

end

class MyStack
  attr_accessor :contents, :monitor, :mutex, :gen
  def initialize(monitor)
    @contents = []
    @monitor = monitor
    @mutex = Mutex.new
    @gen = Random.new
  end
  def add(val)
    op = @monitor.on_call(:add, val)
    sleep @gen.rand(1.0)
    ret = @mutex.synchronize { @contents.push val; :unit }
    sleep @gen.rand(1.0)
    @monitor.on_return(op,ret)
    ret
  end
  def remove
    op = @monitor.on_call(:remove, :unit)
    sleep @gen.rand(1.0)
    ret = @mutex.synchronize { @contents.pop || :empty }
    sleep @gen.rand(1.0)
    @monitor.on_return(op,ret)
    ret
  end
end

module Tester
  def self.main(num_threads)
    gen = Random.new
    mon = AtomicStack::Monitor.new
    obj = MyStack.new(mon)
    val = 0
    puts "Monitoring #{obj.class}..."
    Thread.abort_on_exception=true
    stats = Thread.new do
      loop do
        puts "STATS | #{mon.stats.map{|k,v| "#{k}: #{v}"} * ", "}"
        puts "#{"-" * 80}"
        puts mon
        puts "#{"-" * 80}"
        sleep 1
      end
    end
    num_threads.times.map do
      Thread.new do
        loop do
          case gen.rand(3)
          when 0; obj.add(val += 1)
          else    obj.remove
          end
        end
      end
    end
    stats.join
  end
end

if __FILE__ == $0
  Tester::main 6
end

require 'set'

module ConcurrentObject

  class Operation
    @@unique_id = 0
    attr_accessor :id
    attr_accessor :method_name, :arg_value, :return_value
    attr_accessor :start_time, :end_time
    attr_accessor :min_time, :max_time
    attr_accessor :dependencies

    def initialize(method, *args, time)
      @id = (@@unique_id += 1)
      start!(method, *args, time)
    end

    def start!(method, *args, time)
      @method_name = method
      @arg_value = *args.compact
      @min_time = @start_time = time
    end

    def complete!(*vals, time, pending_ops)
      fail "#{self} already completed!" if completed?
      @return_value = *vals.compact
      @max_time = @end_time = time
      @dependencies = pending_ops
    end

    def refresh!
      @dependencies.reject!(&:completed?) if @dependencies
    end

    def to_s
      arg = @arg_value == [] ? "" : "(#{@arg_value * ", "})"
      ret = case @return_value
        when nil; "..."
        when []; ""
        else " => #{@return_value * ", "}"
      end
      str = ""
      str << "#{@id}: "
      str << "#{@method_name}#{arg}#{ret}"
      # str << " (#{@start_time},#{@min_time},#{@max_time || "_"},#{@end_time || "_"})"
      str
    end

    def pending?; @end_time.nil? end
    def completed?; !pending? end
    def obsolete?; completed? && @dependencies.empty? end
    def impossible?; @end_time && @end_time < @start_time end

    def before?(op) completed? && (op.nil? || @end_time < op.start_time) end

    def before!(op)
      updated = false
      if completed? && op && op.completed? && @max_time > op.max_time
        @max_time = op.max_time
        updated = true
      end
      if op && op.min_time < @min_time
        op.min_time = @min_time
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

    def create_op(method, *args)
      Operation.new(method, *args, @time)
    end

    def on_call(method, *args)
      op = nil
      @mutex.synchronize do
        op = create_op(method, *args)
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
        fail "Found a contradiction\n#{to_s}" if contradiction?
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
      num_ops: @operations.count
      }
    end

    def interval_s(op, relative_time: 0)
      bracket = {true => '|', false => ':'}
      mark = {tick: '-', empty: ' ', pending: '*', invalid: 'X'}

      i = op.start_time - relative_time
      ii = op.min_time - relative_time
      jj = op.max_time
      j = op.end_time
      jj -= relative_time if jj
      j -= relative_time if j
      k = @time - relative_time

      str = ""
      str << " " * i
      if jj && ii > jj
        str << mark[:invalid] * (j-i+1)
        str << " " * (k-j)
      else
        str << mark[:empty] * (ii-i)
        if j
          str << mark[:tick] * (jj-ii+1)
          str << mark[:empty] * (j-jj)
          str << " " * (k-j)
        else
          str << mark[:tick] * (k-ii)
          str << mark[:pending]
        end
      end
      str[i] = bracket[i==ii]
      str[j] = bracket[j==jj] if j
      str
    end

    def interval_ss(ops: @operations, relative_time: ops.map(&:start_time).min)
      ops.map {|op| interval_s(op, relative_time: relative_time) + "  #{op}"}
    end

    def debug_before_and_after(msg, focused_ops)
      t0 = @operations.map(&:start_time).min
      focused_before = interval_ss(ops: focused_ops.compact, relative_time: t0)
      if yield then
        intervals = interval_ss
        focused_after = interval_ss(ops: focused_ops.compact, relative_time: t0)
        info = stats.map{|k,v| "#{k}: #{v}"} * ", "
        width = (intervals.map(&:length) + [info.length]).max
        puts "-" * width
        puts msg, info
        puts "-" * width
        puts intervals
        puts "-" * width
        puts "BEFORE", focused_before
        puts "-" * width
        puts "AFTER", focused_after
        puts "-" * width
      end
    end

    def to_s
      intervals = interval_ss
      title = "History | " + stats.map{|k,v| "#{k}: #{v}"} * ", "
      width = (intervals.map(&:length) + [title.length]).max
      str = ""
      str << '-' * width << "\n"
      str << title << "\n"
      str << '-' * width << "\n"
      str << intervals * "\n" << "\n"
      str << '-' * width
      str
    end
  end

  class MonitoredObject
    attr_accessor :object, :monitor
    def initialize(object, monitor)
      @object = object
      @monitor = monitor
      object.methods.each do |m|
        next if Object.instance_methods.include? m
        (class << self; self; end).class_eval do
          define_method(m) do |*args|
            op = @monitor.on_call(m, *args)
            ret = @object.send(m, *args)
            @monitor.on_return(op, ret)
            ret
          end
        end
      end
    end
  end

end

module AtomicStack

  class Operation < ConcurrentObject::Operation
    attr_accessor :match
    alias :default_obsolete? :obsolete?
    def obsolete?
      default_obsolete? &&
      (@match && @match.default_obsolete? || @return_value.first == :empty)
    end
    def add?; @method_name == :add end
    def remove?; @method_name == :remove end
    def value; add? ? @arg_value.first : @return_value.first end
    def empty?; value == :empty end
  end

  class Element
    attr_accessor :add, :remove
    def initialize(add) @add = add end
    def value; add.value end
    def removed?; !@remove.nil? end
    def remove!(remove)
      fail "#{self} already removed!" if removed?
      @remove = remove
      @remove.match = @add
      @add.match = @remove
    end
    def obsolete?; add.obsolete? end
  end

  class Monitor < ConcurrentObject::Monitor
    attr_accessor :elements, :empties
    attr_accessor :napps_rem, :napps_empty, :napps_order

    def initialize
      super
      @elements = {}
      @empties = []
      @napps_rem = @napps_empty = @napps_order = 0
    end

    def create_op(method, *args)
      AtomicStack::Operation.new(method, *args, @time)
    end

    alias :super_stats :stats
    def stats
      super_stats.merge({
        napps_rem: @napps_rem,
        napps_empty: @napps_empty,
        napps_order: @napps_order
      })
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
        fail "Element #{op.value} removed yet never added!" unless e
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
          worklist << e1.add << e1.remove if apply_remove!(e1)
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

    def apply_remove!(elem)
      debug_before_and_after("APPLIED REMOVE RULE", [elem.add, elem.remove]) do
        updated = false
        updated ||= elem.add.before!(elem.remove) if elem.remove
        @napps_rem += 1 if updated
        updated
      end
    end

    def apply_empty!(elem, emp)
      debug_before_and_after("APPLIED EMPTY RULE", [elem.add, elem.remove, emp]) do
        updated = false
        if elem.remove && elem.add.before?(emp)
          updated ||= elem.remove.before!(emp)
        end
        if emp.before?(elem.remove) && (elem.remove || emp.dependencies.empty?)
          updated ||= emp.before!(elem.add)
        end
        @napps_empty += 1 if updated
        updated
      end
    end

    def apply_stack_order!(e1,e2)
      debug_before_and_after("APPLIED ORDER RULE", [e1.add, e1.remove, e2.add, e2.remove]) do
        updated = false
        if e1.add.before?(e2.add) && e1.remove && e1.remove.before?(e2.remove) &&
          (e2.remove || e1.remove.dependencies.empty?)
          updated ||= e1.remove.before!(e2.add)
        end
        if e1.add.before?(e2.add) && e2.add.before?(e1.remove) && e2.remove &&
          (e1.remove || e2.add.dependencies.empty?)
          updated ||= e2.remove.before!(e1.remove) # TODO WHAT IF !e1.remove
        end
        if e2.add.before?(e1.remove) && e1.remove && e1.remove.before?(e2.remove) &&
          (e2.remove || e1.remove.dependencies.empty?)
          updated ||= e2.add.before!(e1.add)
        end
        @napps_order += 1 if updated
        updated
      end
    end
  end

end

class MyStack
  attr_accessor :contents, :mutex, :gen
  def initialize
    @contents = []
    @mutex = Mutex.new
    @gen = Random.new
  end
  def add(val)
    sleep @gen.rand(0.2)
    @mutex.synchronize { @contents.push val }
    sleep @gen.rand(0.1)
    nil
  end
  def remove
    sleep @gen.rand(0.02)
    val = @mutex.synchronize { @contents.pop }
    sleep @gen.rand(0.01)
    val || :empty
  end
end

module Tester
  def self.main(num_threads)
    gen = Random.new
    obj = ConcurrentObject::MonitoredObject.new( MyStack.new, AtomicStack::Monitor.new )
    val = 0
    puts "Monitoring #{obj.class}..."
    Thread.abort_on_exception = true
    num_threads.times.map do
      Thread.new do
        loop do
          sleep gen.rand(0.1)
          case gen.rand(3)
          when 0; obj.add(val += 1)
          else    obj.remove
          end
        end
      end
    end.each {|t| t.join}
  end
end

if __FILE__ == $0
  Tester::main 7
end

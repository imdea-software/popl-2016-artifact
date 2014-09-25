require 'set'
require_relative 'concurrent_object'

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

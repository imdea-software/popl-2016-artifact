require 'set'
require_relative 'history'
require_relative 'history_checker'

class Rule
  def initialize(history, *triggers)
    @history = history
    @triggers = triggers
  end
  def to_s; "#{name}(#{@triggers * ","})" end
  def triggers; @triggers end
  def before?(o1,o2)
    o1 && (!o2 && @history.ext_completed?(o1) || o2 && @history.ext_before?(o1,o2))
  end
end

class SaturateChecker < HistoryChecker
  def initialize(options)
    super(options)
    @rules = {}
    log.warn('Saturate') {"I don't do completions."} if completion
    log.warn('Saturate') {"I only do incremental."} unless incremental
  end

  def self.get(options)
    case options[:adt]
    when /stack|queue/
      CollectionSaturateChecker.new(options)
    else
      fail "I don't know how to make a saturation checker for #{options[:adt]}."
    end
  end

  def name; "Saturate" end

  def get_triggers(id)
    fail "Must override get_triggers method."
  end

  def add_rules(id)
    fail "Must override add_rules method."
  end

  def inconsistent?
    history.any? {|op| history.ext_before?(op,op)}
  end

  def started!(id, method_name, *arguments)
    add_rules(id)
  end

  def completed!(id, *returns)
    add_rules(id)

    worklist = Set.new
    worklist.merge get_triggers(id)

    while !worklist.empty?
      trigger = worklist.first
      worklist.delete(trigger)
      next unless @rules.include?(trigger)

      @rules[trigger].each do |rule|
        log.debug('Saturate') {"checking #{rule} rule."}
        if rule.apply!

          # if inconsistent? ...

          log.debug('Saturate') {"applied #{rule} rule."}
          @rules.values.each {|rs| rs.delete rule}
          @rules.reject! {|_,rs| rs.empty?}
          worklist.merge(rule.triggers)
        end
      end
    end
  end

  def removed!(id)
    get_triggers(id).each do |trigger|
      @rules.delete trigger
      @rules.values.each {|rs| rs.reject! {|r| r.triggers.include? trigger}}
    end
    @rules.reject! {|_,rs| rs.empty?}
  end

  def check()
    super()
    log.info('Saturate') {"checking history\n#{history}"}
    ok = !inconsistent?
    log.info('Saturate') {"result: #{ok ? "OK" : "violation"}"}
    flag_violation unless ok
  end
end

class AddRemoveOrderRule < Rule
  def initialize(history, val)
    super(history, {value: val})
    @val = val
  end
  def name; "AR" end
  def apply!
    @add ||= @history.find{|id| @history.arguments(id).include?(@val)}
    @rem ||= @history.find{|id| (@history.returns(id)||[]).include?(@val)}

    if @add && @rem
      @history.order!(@add,@rem)
      true
    else
      false
    end
  end
end

class RemoveEmptyRule < Rule
  def initialize(history, emp, val)
    super(history, {empty: emp}, {value: val})
    @emp = emp
    @val = val
  end
  def name; "EMPTY" end
  def apply!
    @add ||= @history.find{|id| @history.arguments(id).include?(@val)}
    @rem ||= @history.find{|id| (@history.returns(id)||[]).include?(@val)}

    if before?(@add,@emp) && @rem
      @history.order!(@rem,@emp)
      true
    elsif before?(@emp,@rem) && @add
      @history.order!(@emp,@add)
      true
    else
      false
    end
  end
end

class FifoOrderRule < Rule
  def initialize(history, v1, v2)
    super(history, {value: v1}, {value: v2})
    @v1 = v1
    @v2 = v2
  end
  def name; "FIFO" end
  def apply!
    @a1 ||= @history.find{|id| @history.arguments(id).include?(@v1)}
    @r1 ||= @history.find{|id| (@history.returns(id)||[]).include?(@v1)}
    @a2 ||= @history.find{|id| @history.arguments(id).include?(@v2)}
    @r2 ||= @history.find{|id| (@history.returns(id)||[]).include?(@v2)}

    if before?(@a1,@a2) && !@r1 && @r2 && @history.all?{|id| @history.match(id) || before?(@r2,id)}
      @history.order!(@r2,@r2)
      true
    elsif before?(@a1,@a2) && @r1 && @r2
      @history.order!(@r1,@r2)
      true
    elsif before?(@r1,@r2) && @a1 && @a2
      @history.order!(@a1,@a2)
      true
    else
      false
    end
  end
end

class LifoOrderRule < Rule
  def initialize(history, v1, v2)
    super(history, {value: v1}, {value: v2})
    @v1 = v1
    @v2 = v2
  end
  def name; "LIFO" end
  def apply!
    @a1 ||= @history.find{|id| @history.arguments(id).include?(@v1)}
    @r1 ||= @history.find{|id| (@history.returns(id)||[]).include?(@v1)}
    @a2 ||= @history.find{|id| @history.arguments(id).include?(@v2)}
    @r2 ||= @history.find{|id| (@history.returns(id)||[]).include?(@v2)}

    # TODO be sure to cover the cases where some operation is missing

    if before?(@a1,@a2) && before?(@r1,@r2) && @a2
      @history.order!(@r1,@a2)
      true
    elsif before?(@a1,@a2) && before?(@a2,@r1) && @r1 && @r2
      @history.order!(@r2,@r1)
      true
    elsif before?(@a2,@r1) && before?(@r1,@r2) && @a1
      @history.order!(@a2,@a1)
      true
    else
      false
    end
  end
end

class CollectionSaturateChecker < SaturateChecker

  def get_triggers(id)
    val = (history.arguments(id) + (history.returns(id)||[])).first
    val == :empty ? [{empty: id}] : val ? [{value: val}] : []
  end

  def add_rules(id)
    v1 = (history.arguments(id) + (history.returns(id)||[])).first
    return unless v1

    if v1 == :empty

      return if @rules[{empty: id}]

      values = @rules.keys.collect{|trigger| trigger[:value]}.compact

      @rules[{empty: id}] = []
      values.each do |v2|
        r = RemoveEmptyRule.new(history, id, v2)
        @rules[{empty: id}] << r
        @rules[{value: v2}] << r
      end

    else

      # duplicate remove?
      flag_violation if history.completed.select{|id| (history.returns(id)||[]).include?(v1)}.count > 1

      # unmatched remove?
      flag_violation if history.none?{|id| history.arguments(id).include?(v1)}

      return if @rules[{value: v1}]

      values = @rules.keys.collect{|trigger| trigger[:value]}.compact
      empties = @rules.keys.collect{|trigger| trigger[:empty]}.compact

      @rules[{value: v1}] = []
      @rules[{value: v1}] << AddRemoveOrderRule.new(history, v1)
      empties.each do |em|
        r = RemoveEmptyRule.new(history, em, v1)
        @rules[{empty: em}] << r
        @rules[{value: v1}] << r
      end
      values.each do |v2|
        r1 = LifoOrderRule.new(history, v1, v2) if adt == :stack
        r2 = LifoOrderRule.new(history, v2, v1) if adt == :stack
        r1 = FifoOrderRule.new(history, v1, v2) if adt == :queue
        r2 = FifoOrderRule.new(history, v2, v1) if adt == :queue
        @rules[{value: v1}] << r1
        @rules[{value: v1}] << r2
        @rules[{value: v2}] << r1
        @rules[{value: v2}] << r2
      end
    end
  end

end

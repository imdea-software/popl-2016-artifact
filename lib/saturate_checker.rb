require 'set'
require_relative 'history'
require_relative 'history_checker'

class Rule
  def initialize(history, *ids)
    @history = history
    @ids = ids
  end
  def to_s; "#{name}(#{@ids * ","})" end
  def ids; @ids end
  def before?(o1,o2)
    o1 && (!o2 && @history.ext_completed?(o1) || o2 && @history.ext_before?(o1,o2))
  end
end

class AddRemoveOrderRule < Rule
  def initialize(history, add, rem)
    super(history, add, rem)
  end
  def name; "AR" end
  def apply!
    add, rem = @ids
    if add && rem
      @history.order!(add,rem)
      true
    else
      false
    end
  end
end

class RemoveEmptyRule < Rule
  def initialize(history, emp, add, rem)
    super(history, emp, add, rem)
  end
  def name; "EMPTY" end
  def apply!
    emp, add, rem = @ids
    if before?(add,emp) && rem
      @history.order!(rem,emp)
      true
    elsif before?(emp,rem) && add
      @history.order!(emp,add)
      true
    else
      false
    end
  end
end

class FifoOrderRule < Rule
  def initialize(history, a1, r1, a2, r2)
    super(history, a1, r1, a2, r2)
  end
  def name; "FIFO" end
  def apply!
    a1, r1, a2, r2 = @ids
    if before?(a1,a2) && r1 && r2
      @history.order!(r1,r2)
      true
    elsif before?(r1,r2) && a1 && a2
      @history.order!(a1,a2)
      true
    else
      false
    end
  end
end

class LifoOrderRule < Rule
  def initialize(history, a1, r1, a2, r2)
    super(history, a1, r1, a2, r2)
  end
  def name; "LIFO" end
  def apply!
    a1, r1, a2, r2 = @ids
    if before?(a1,a2) && before?(r1,r2) && a2
      @history.order!(r1,a2)
      true
    elsif before?(a1,a2) && before?(a2,r1) && r1 && r2
      @history.order!(r2,r1)
      true
    elsif before?(a2,r1) && before?(r1,r2) && a1
      @history.order!(a2,a1)
      true
    else
      false
    end
  end
end

class SaturateChecker < HistoryChecker
  def initialize(options)
    super(options)
    @rules = {}
    log.warn('Saturate') {"I don't do completions."} if completion
    log.warn('Saturate') {"I only do incremental."} unless incremental
  end

  def name; "Saturate" end

  def see_value(v)

    ### TODO FINISH FIXING THIS WITH THE NEW MATCHING SCHEME

    # duplicate remove?
    flag_violation if history.completed.select{|id| history.returns(id).include?(v)}.count > 1

    # unmatched remove?
    flag_violation if history.none?{|id| history.arguments(id).include?(v)}
    
    return if @rules.include?(v)
    @rules[v] = []

    if v == :empty
      matcher.each do |g2,_|
        next unless matcher.value?(g2)
        next unless @rules[g2]
        r = RemoveEmptyRule.new(history, matcher, g1, g2)
        @rules[g1].push r
        @rules[g2].push r
      end
    else
      @rules[g1].push AddRemoveOrderRule.new(history, matcher, g1)

      matcher.each do |g2,_|
        next if g1 == g2
        next unless @rules[g2]
        if matcher.value?(g2)
          r1 = LifoOrderRule.new(history, matcher, g1, g2) if object =~ /stack/
          r2 = LifoOrderRule.new(history, matcher, g2, g1) if object =~ /stack/
          r1 = FifoOrderRule.new(history, matcher, g1, g2) if object =~ /queue/
          r2 = FifoOrderRule.new(history, matcher, g2, g1) if object =~ /queue/
          @rules[g1].push r1, r2
          @rules[g2].push r1, r2
        else
          r = RemoveEmptyRule.new(history, matcher, g2, g1)
          @rules[g1].push r
          @rules[g2].push r
        end
      end
    end
  end

  def inconsistent?
    history.any? {|op| history.ext_before?(op,op)}
  end

  def started!(id, method_name, *arguments)
    see_match(id) if matcher.add?(id)
  end

  def completed!(id, *returns)
    see_match(id)

    worklist = Set.new
    worklist << matcher.group_of(id)
    while !worklist.empty?
      g = worklist.first
      worklist.delete(g)
      next unless @rules.include?(g)
      @rules[g].each do |rule|
        log.debug('Saturate') {"checking #{rule} rule."}
        if rule.apply!

          # if inconsistent? ...

          log.debug('Saturate') {"applied #{rule} rule."}
          @rules.values.each {|rs| rs.delete rule}
          @rules.reject! {|_,rs| rs.empty?}
          worklist.merge(rule.groups)
        end
      end
    end
  end

  def removed!(id)
    g = matcher.group_of(id)
    @rules.delete g
    @rules.values.each {|rs| rs.reject! {|r| r.groups.include? g}}
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

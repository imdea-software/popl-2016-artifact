require 'set'
require_relative 'history'
require_relative 'history_checker'

class Rule
  def initialize(history, matcher, *groups)
    @history = history
    @matcher = matcher
    @groups = groups
  end
  def to_s; "#{name}(#{@groups * ","})" end
  def groups; @groups end
  def before?(o1,o2)
    o1 && (!o2 && @history.ext_completed?(o1) || o2 && @history.ext_before?(o1,o2))
  end
end

class AddRemoveOrderRule < Rule
  def initialize(history, matcher, gval)
    super(history, matcher, gval)
  end
  def name; "AR" end
  def apply!
    g = @groups.first
    a = @matcher.add(g)
    r = @matcher.rem(g)
    if a && r
      @history.order!(a,r)
      true
    else
      false
    end
  end
end

class RemoveEmptyRule < Rule
  def initialize(history, matcher, gemp, gval)
    super(history, matcher, gemp, gval)
  end
  def name; "EMPTY" end
  def apply!
    gemp, gval = @groups
    e = @matcher.operations(gemp).first
    a = @matcher.add(gval)
    r = @matcher.rem(gval)
    if before?(a,e) && r
      @history.order!(r,e)
      true
    elsif before?(e,r) && a
      @history.order!(e,a)
      true
    else
      false
    end
  end
end

class FifoOrderRule < Rule
  def initialize(history, matcher, g1, g2)
    super(history, matcher, g1, g2)
  end
  def name; "FIFO" end
  def apply!
    g1, g2 = @groups
    a1 = @matcher.add(g1)
    r1 = @matcher.rem(g1)
    a2 = @matcher.add(g2)
    r2 = @matcher.rem(g2)
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
  def initialize(history, matcher, g1, g2)
    super(history, matcher, g1, g2)
  end
  def name; "LIFO" end
  def apply!
    g1, g2 = @groups
    a1 = @matcher.add(g1)
    r1 = @matcher.rem(g1)
    a2 = @matcher.add(g2)
    r2 = @matcher.rem(g2)
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

  def see_match(id)
    g1 = matcher.group_of(id)
    ops = matcher.members(g1)

    # duplicate remove?
    flag_violation if ops.count > 2

    # unmatched remove?
    flag_violation if matcher.value?(g1) && ops.none?{|id| matcher.add?(id)}
    
    return if @rules.include?(g1)
    @rules[g1] = []

    if matcher.value?(g1)
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
    else
      matcher.each do |g2,_|
        next unless matcher.value?(g2)
        next unless @rules[g2]
        r = RemoveEmptyRule.new(history, matcher, g1, g2)
        @rules[g1].push r
        @rules[g2].push r
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

require 'set'
require_relative 'history'
require_relative 'history_checker'

class Rule
  def initialize(history, matcher, *matches)
    @history = history
    @matcher = matcher
    @matches = matches
  end
  def to_s; "#{name}(#{@matches * ","})" end
  def matches; @matches end
  def before?(o1,o2)
    o1 && (!o2 && @history.ext_completed?(o1) || o2 && @history.ext_before?(o1,o2))
  end
end

class AddRemoveOrderRule < Rule
  def initialize(history, matcher, m)
    super(history, matcher, m)
  end
  def name; "AR" end
  def apply!
    m = @matches.first
    a = @matcher.add(m)
    r = @matcher.rem(m)
    if a && r
      @history.order!(a,r)
      true
    else
      false
    end
  end
end

class RemoveEmptyRule < Rule
  def initialize(history, matcher, me, mv)
    super(history, matcher, me, mv)
  end
  def name; "EMPTY" end
  def apply!
    me, mv = @matches
    e = @matcher.operations(me).first
    a = @matcher.add(mv)
    r = @matcher.rem(mv)
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
  def initialize(history, matcher, m1, m2)
    super(history, matcher, m1, m2)
  end
  def name; "FIFO" end
  def apply!
    m1, m2 = @matches
    a1 = @matcher.add(m1)
    r1 = @matcher.rem(m1)
    a2 = @matcher.add(m2)
    r2 = @matcher.rem(m2)
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
  def initialize(history, matcher, m1, m2)
    super(history, matcher, m1, m2)
  end
  def name; "LIFO" end
  def apply!
    m1, m2 = @matches
    a1 = @matcher.add(m1)
    r1 = @matcher.rem(m1)
    a2 = @matcher.add(m2)
    r2 = @matcher.rem(m2)
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

class SaturationChecker < HistoryChecker
  def initialize(object, matcher, history, completion, incremental)
    super(object, matcher, history, completion, incremental)
    @rules = {}
    log.warn('saturation-checker') {"I don't do completions."} if @completion
    log.warn('saturation-checker') {"I only do incremental."} unless @incremental
  end

  def name; "Saturation checker" end

  def see_match(id)
    m1 = @matcher.match(id)
    ops = @matcher.operations(m1)

    # duplicate remove?
    flag_violation if ops.count > 2

    # unmatched remove?
    flag_violation if @matcher.value?(m1) && ops.none? {|id| @matcher.add?(id)}

    return if @rules.include?(m1)
    @rules[m1] = []

    if @matcher.value?(m1)
      @rules[m1].push AddRemoveOrderRule.new(@history, @matcher, m1)

      @matcher.each do |m2,_|
        next if m1 == m2
        next unless @rules[m2]
        if @matcher.value?(m2)
          r1 = LifoOrderRule.new(@history, @matcher, m1, m2) if @object =~ /stack/
          r2 = LifoOrderRule.new(@history, @matcher, m2, m1) if @object =~ /stack/
          r1 = FifoOrderRule.new(@history, @matcher, m1, m2) if @object =~ /queue/
          r2 = FifoOrderRule.new(@history, @matcher, m2, m1) if @object =~ /queue/
          @rules[m1].push r1, r2
          @rules[m2].push r1, r2
        else
          r = RemoveEmptyRule.new(@history, @matcher, m2, m1)
          @rules[m1].push r
          @rules[m2].push r
        end
      end
    else
      @matcher.each do |m2,_|
        next unless @matcher.value?(m2)
        r = RemoveEmptyRule.new(@history, @matcher, m1, m2)
        @rules[m1].push r
        @rules[m2].push r
      end
    end
  end

  def inconsistent?
    @history.any? {|op| @history.ext_before?(op,op)}
  end

  def started!(id, method_name, *arguments)
    see_match(id) if @matcher.add?(id)
  end

  def completed!(id, *returns)
    see_match(id)

    worklist = Set.new
    worklist << @matcher.match(id)
    while !worklist.empty?
      m = worklist.first
      worklist.delete(m)
      next unless @rules.include?(m)
      @rules[m].each do |rule|
        log.debug('saturation-checker') {"checking #{rule} rule."}
        if rule.apply!

          # if inconsistent? ...

          log.debug('saturation-checker') {"applied #{rule} rule."}
          @rules.values.each {|rs| rs.delete rule}
          @rules.reject! {|_,rs| rs.empty?}
          worklist.merge(rule.matches)
        end
      end
    end
  end

  def removed!(id)
    m = @matcher.match(id)
    @rules.delete m
    @rules.values.each {|rs| rs.reject! {|r| r.matches.include? m}}
    @rules.reject! {|_,rs| rs.empty?}
  end

  def check()
    super()
    log.info('saturation-checker') {"checking history\n#{@history}"}
    ok = !inconsistent?
    log.info('saturation-checker') {"result: #{ok ? "OK" : "violation"}"}
    flag_violation unless ok
  end
end

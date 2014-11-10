module Matcher
  def self.get(object, history)
    case object
    when /stack|queue/
      CollectionMatcher.new(history)
    else
      # log.warn "Defaulting to the UNSOUND generic remover."
      # GenericObsoleteRemover.new(history)
      log.warn "I don't know how to match operations for #{object || "unknown"} objects."
      log.warn "Disabling operation matching."
      nil
    end
  end
end

class CollectionMatcher
  include Enumerable

  def initialize(history)
    @history = history
    @operations = {}
  end

  def to_s
    @operations.map{|m,ops| "#{m} (#{m.class}): {#{ops * ", "}}"} * "\n"
  end

  def each(&block)
    if block_given?
      @operations.each(&block)
      self
    else
      to_enum
    end
  end

  def add?(id) @history.method_name(id) =~ /add|push|enqueue/ end
  def rem?(id) @history.method_name(id) =~ /rm|remove|pop|dequeue/ end
  def value?(m)
    @operations[m].find do |id|
      add?(id) || @history.completed?(id) && @history.returns(id).first != :empty
    end
  end

  def operations(m) @operations[m] end
  def add(m) @operations[m].find(&method(:add?)) end
  def rem(m) @operations[m].find(&method(:rem?)) end

  def match(id)
    m = if add?(id) then @history.arguments(id).first
        elsif rem?(id) && @history.completed?(id) && @history.returns(id).first != :empty
          then @history.returns(id).first
        else id
        end
    @operations[m] ||= []
    m
  end

  def complete?(m)
    @operations[m].all?(&@history.method(:completed?)) &&
    (add(m) && rem(m) || !value?(m))
  end

  def update(msg, id, *values)
    case msg
    when :start
      if add?(id)
        @operations[match(id)] << id
      end      
    when :complete
      if rem?(id)
        @operations[match(id)] << id
      end
    when :remove
      @operations.values.each {|ids| ids.delete id}
      @operations.reject! {|_,ids| ids.empty?}
    end
  end
end

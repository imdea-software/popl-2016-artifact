require 'set'

class Matcher
  include Enumerable

  def self.get(object, history)
    case object
    when /stack|queue/
      CollectionMatcher.new(history)
    else
      log.warn('Matcher') {"I don't know about #{object || "unknown"}'s operations."}
      log.warn('Matcher') {"operation matching disabled."}
      nil
    end
  end

  def initialize(history)
    @group = {}   # id -> group
    @groups = {}  # group -> ids
    @history = history
    @history.each {|id| members(group_of(id)) << id}
  end

  def classify(id)
    log.fatal('Matcher') {"classify method must be overridden."}
    exit
  end

  def source?(id)
    log.fatal('Matcher') {"source method must be overridden."}
    exit
  end

  def complete?(g)
    log.fatal('Matcher') {"complete? method must be overridden."}
    exit
  end

  def each(&block)
    if block_given?
      @groups.each(&block)
      self
    else
      to_enum
    end
  end

  def to_s; @groups.map{|g,ids| "#{g}: #{ids.to_a * ", "}"} * "\n" end

  def group_of(id)
    @group[id] ||= classify(id)
  end

  def groups
    @groups.keys
  end

  def members(g)
    @groups[g] ||= Set.new
  end

  def remove(id)
    @groups.values.each {|ids| ids.delete id}
    @groups.reject! {|_,ids| ids.empty?}
    @group.delete id
  end

  def update(msg, id, *values)
    case msg
    when :start
      members(group_of(id)) << id
    when :complete
      remove(id) # *RE*CLASSIFY
      members(group_of(id)) << id
    when :remove
      remove(id)
    end
  end

end

class CollectionMatcher < Matcher
  def initialize(history)
    @values = {}
    @empties = {}
    @unknown = {}
    @unique_id = 0
    super(history)
  end

  def add?(id) @history.method_name(id) =~ /add|push|enqueue/ end
  def rem?(id) @history.method_name(id) =~ /rm|remove|pop|dequeue/ end
  def value?(g)
    members(g).any? do |id|
      add?(id) || @history.returns(id) && @history.returns(id).first != :empty
    end
  end
  
  def add(g) @groups[g].find {|id| add?(id)} end
  def rem(g) @groups[g].find {|id| rem?(id)} end

  def classify(id)
    if add?(id)
      @values[@history.arguments(id).first] ||= (@unique_id += 1)
      
    elsif rem?(id) && @history.returns(id) && @history.returns(id).first != :empty
      @unknown.delete id
      @values[@history.returns(id).first] ||= (@unique_id += 1)
      
    elsif rem?(id) && @history.returns(id)
      @unknown.delete id
      @empties[id] ||= (@unique_id += 1)

    else
      @unknown[id] ||= (@unique_id += 1)
    end
  end

  def source?(id)
    add?(id)
  end

  def complete?(g)
    @groups[g].all? {|id| @history.completed?(id)} &&
    (@groups[g].all? {|id| @empties[id]} || add(g) && rem(g))
  end

  def update(msg, id, *values)
    super(msg, id, *values)
    case msg
    when :remove
      @empties.delete id
      @unknown.delete id
    end
  end
end

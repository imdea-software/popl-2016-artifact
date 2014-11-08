module ObsoleteRemover
  def self.get(object, history)
    case object
    when /stack|queue/
      CollectionObsoleteRemover.new(history)
    else
      # log.warn "Defaulting to the UNSOUND generic remover."
      # GenericObsoleteRemover.new(history)
      log.warn "I don't know how to remove obsolete operations for #{object} objects."
      log.warn "Disabling obsolete-removal."
      nil
    end
  end
end

class GenericObsoleteRemover
  def initialize(history)
    @history = history
    @dependencies = {}
  end

  def update(msg, id, *values)
    case msg
    when :complete
      on_completion(id)
    end
  end

  def on_completion(id)
    log.info('generic-op-remover') {"checking for obsolete operations..."}
    @dependencies[id] = @history.pending.clone
    @dependencies.values.each {|ids| ids.delete id}
    obsolete = @dependencies.select{|_,ids| ids.empty?}.keys
    return if obsolete.empty?
    log.info('generic-op-remover') {"removing: #{obsolete * ", "}"}
    obsolete.each do |id|
      @history.remove! id
      @dependencies.delete id
    end
  end
end

class CollectionObsoleteRemover < GenericObsoleteRemover
  def initialize(history)
    super(history)
    @ops_for_elem = {}
    @deps_for_elem = {}
  end

  def add?(id)    @history.method_name(id) =~ /add|push|enqueue/ end
  def remove?(id) @history.method_name(id) =~ /remove|pop|dequeue/ end

  def matched?(elem)
    @ops_for_elem[elem].any? {|id| add?(id)} && @ops_for_elem[elem].any? {|id| remove?(id)}
  end

  def get_element(id)
    if add?(id);        @history.arguments(id).first
    elsif remove?(id);  @history.returns(id).first
    else                fail "Unexpected method #{@history.method_name(id)}."
    end
  end

  def on_completion(id)
    log.info('collection-elem-remover') {"Checking for obsolete operations..."}
    elem = get_element(id)
    if elem == :empty
      @dependencies[id] = @history.pending.clone
    else
      @ops_for_elem[elem] ||= []
      @ops_for_elem[elem] << id
      @deps_for_elem[elem] ||= []
      @deps_for_elem[elem] |= @history.pending
    end
    @dependencies.values.each {|ids| ids.delete id}
    @deps_for_elem.values.each {|ids| ids.delete id}
    obsolete_ids = @dependencies.select{|_,ids| ids.empty?}.keys
    obsolete_elems = @deps_for_elem.select{|elem, ids| matched?(elem) && ids.empty?}.keys
    obsolete_ids += obsolete_elems.map{|elem| @ops_for_elem[elem]}.flatten
    return if obsolete_ids.empty?
    log.info('collection-elem-remover') {"removing: #{obsolete_ids * ", "}"}
    obsolete_ids.each do |id|
      @history.remove! id
      @dependencies.delete id
    end
    obsolete_elems.each do |elem|
      @deps_for_elem.delete elem
      @ops_for_elem.delete elem
    end
  end
end

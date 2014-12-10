class ObsoleteRemover
  def initialize(history)
    @history = history
    @dependencies = {}
  end

  def group_of(id)
    val = (@history.arguments(id) + (@history.returns(id)||[])).first
    val == :empty ? {empty: id} : val ? {value: val} : nil
  end

  def complete?(g)
    if g[:empty]
      @history.completed?(g[:empty]) || !@history.include?(g[:empty])
    else
      @history.any? {|id| @history.arguments(id).include?(g[:value])} &&
      @history.any? {|id| (@history.returns(id)||[]).include?(g[:value])}
    end
  end

  def members(g)
    return [g[:empty]] if g[:empty]
    @history.select{|id| (@history.arguments(id) + (@history.returns(id)||[])).include?(g[:value])}
  end

  def update(msg, id, *values)
    case msg
    when :complete
      log.info('operation-remover') {"checking for obsolete operations..."}

      g = group_of(id)
      return unless g

      @dependencies[g] = @history.pending.clone
      @dependencies.values.each{|ids| ids.delete id}

      obsolete = @dependencies.select {|g,ids| complete?(g) && ids.empty?}.keys

      return if obsolete.empty?
      log.info('operation-remover') {"removing #{obsolete.map{|g| members(g)}.flatten * ", "}"}
      obsolete.each do |g|
        ids = members(g).clone
        ids.each{|id| @history.remove! id}
        @dependencies.delete g
      end
    end
  end
end

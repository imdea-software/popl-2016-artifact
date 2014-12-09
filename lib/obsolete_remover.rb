class ObsoleteRemover
  def initialize(history)
    @history = history
    @dependencies = {}
  end

  def update(msg, id, *values)
    case msg
    when :complete
      log.info('operation-remover') {"checking for obsolete operations..."}

      # TODO REWORK THIS WITH NEW MATCHING SCHEME

      g = @matcher.group_of(id)
      @dependencies[g] = @history.pending.clone
      @dependencies.values.each{|ids| ids.delete id}
      obsolete = @dependencies.select {|g,ids| @matcher.complete?(g) && ids.empty?}.keys
      return if obsolete.empty?
      log.info('operation-remover') {
        "removing #{obsolete.map{|g| @matcher.members(g)}.flatten * ", "}"
      }
      obsolete.each do |g|
        ids = @matcher.members(g).clone
        ids.each{|id| @history.remove! id}
        @dependencies.delete g
      end
    end
  end
end

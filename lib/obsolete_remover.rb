class ObsoleteRemover
  def initialize(history, matcher)
    @history = history
    @matcher = matcher
    @dependencies = {}
  end

  def update(msg, id, *values)
    case msg
    when :complete
      log.info('operation-remover') {"checking for obsolete operations..."}
      m = @matcher.match(id)
      @dependencies[m] = @history.pending.clone
      @dependencies.values.each{|ids| ids.delete id}
      obsolete = @dependencies.select {|m,ids| @matcher.complete?(m) && ids.empty?}.keys
      return if obsolete.empty?
      log.info('operation-remover') {
        "removing #{obsolete.map(&@matcher.method(:operations)).flatten * ", "}"
      }
      obsolete.each do |m|
        ids = @matcher.operations(m).clone
        ids.each{|id| @history.remove! id}
        @dependencies.delete m
      end
    end
  end
end

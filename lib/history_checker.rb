class HistoryChecker
  def initialize(object, history, incremental)
    @object = object
    @history = history
    @incremental = incremental
    @num_checks = 0
    @violation = false
  end

  def name; "none" end
  def to_s; "#{name}, #{"non-" unless @incremental}incremental" end

  def num_checks; @num_checks end

  def flag_violation; @violation = true end
  def violation?; @violation end

  def check()
    @num_checks += 1
  end

  def invalidate()
  end

  def update(msg)
    case msg
    when :complete; check()
    when :remove;   invalidate()
    end
  end
end

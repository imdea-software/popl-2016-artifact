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

  def removed!(id) end
  def started!(m, *values) end
  def completed!(id, *values) end

  def update(msg, m_or_id, *values)
    case msg
    when :start;    started!(m_or_id, *values)
    when :complete; completed!(m_or_id, *values); check()
    when :remove;   removed!(m_or_id)
    end
  end
end

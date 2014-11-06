class HistoryChecker
  def initialize(object, incremental)
    @object = object
    @incremental = incremental
    @num_checks = 0
  end

  def name; "none" end
  def to_s; "#{name}, #{"non-" unless @incremental}incremental" end
  def num_checks; @num_checks end

  def check(history)
    @num_checks += 1
    true
  end
end

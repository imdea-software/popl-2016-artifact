require_relative 'history'
require_relative 'history_checker'

class SaturationChecker < HistoryChecker
  def initialize(object, incremental)
    super(object, incremental)
  end

  def name; "Saturation checker" end

  def check(history)
    super(history)
    true
  end
end

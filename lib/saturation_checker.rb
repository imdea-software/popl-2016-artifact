require_relative 'history'
require_relative 'history_checker'

class SaturationChecker < HistoryChecker
  def initialize(object, history, incremental)
    super(object, history, incremental)
  end

  def name; "Saturation checker" end

  def check()
    super()
    # flag_violation unless ...
  end
end

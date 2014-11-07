require_relative 'history'
require_relative 'history_checker'

class SaturationChecker < HistoryChecker
  def initialize(object, history, completion, incremental)
    super(object, history, completion, incremental)
  end

  def name; "Saturation checker" end

  def check()
    super()
    # flag_violation unless ...
  end
end

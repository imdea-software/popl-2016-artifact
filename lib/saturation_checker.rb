require_relative 'history'
require_relative 'history_checker'

class SaturationChecker < HistoryChecker
  def initialize(object, history, completion, incremental)
    super(object, history, completion, incremental)
  end

  def name; "Saturation checker" end

  def check()
    super()
    log.info('saturation-checker') {"checking history\n#{@history}"}
    ok = true
    log.info('saturation-checker') {"result: #{ok ? "OK" : "violation"}"}
    flag_violation unless ok
  end
end

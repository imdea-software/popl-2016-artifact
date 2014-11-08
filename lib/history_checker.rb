class HistoryChecker
  def initialize(object, history, completion, incremental)
    @object = object
    @history = history
    @completion = completion
    @incremental = incremental
    @num_checks = 0
    @violation = false
  end

  def name; "none" end
  def to_s; "#{name}, #{"non-" unless @incremental}incremental, w/#{"o" unless @completion} completion" end

  def num_checks; @num_checks end

  def flag_violation; @violation = true end
  def violation?; @violation end

  def check()
    @num_checks += 1
  end

  def started!(id, method_name, *arguments) end
  def completed!(id, *returns) end
  def removed!(id) end

  def update(msg, id, *args)
    case msg
    when :start;    started!(id, *args)
    when :complete; completed!(id, *args); check()
    when :remove;   removed!(id)
    end
  end
end

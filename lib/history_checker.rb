class HistoryChecker
  attr_reader :object, :matcher, :history, :completion, :incremental, :removal

  def self.get(options = {})
    case options[:checker]
    when :enumerate;  EnumerateChecker.new(options)
    when :symbolic;   SymbolicChecker.new(options)
    when :saturate;   SaturateChecker.get(options)
    when :counting;   CountingChecker.new(options)
    else              self.new(options)
    end
  end

  def initialize(options = {})
    options.each do |k,v|
      instance_variable_set("@#{k}",v) if respond_to?("#{k}")
    end
    @num_checks = 0
    @violation = false
  end

  def name; "none" end
  def to_s; "#{name}#{"+R" if @removal}" end

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

require_relative 'enumerate_checker'
require_relative 'symbolic_checker'
require_relative 'saturate_checker'
require_relative 'counting_checker'

class HistoryChecker
  attr_reader :adt, :matcher, :history, :completion, :incremental, :removal

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
  def to_s; "#{name}#{"+I" if @incremental}#{"+C" if @completion}#{"+R" if @removal}" end

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

require_relative 'theories'
require_relative 'z3'

Dir.glob(File.join(File.dirname(__FILE__),"checkers","*")).each do |checker|
  name = File.basename(checker,'.rb')
  require_relative checker
end

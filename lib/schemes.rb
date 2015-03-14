class Scheme
  def name
    self.class.to_s.underscore.split("_")[0..-2].join.to_sym
  end
  def match(history, id)
    history.find {|m| match?(history,m,id)}
  end
  def method_missing(m, *args, &block)
    if [:adt_methods, :match?, :generate_arguments, :generate_returns].include?(m)
      fail "#{self.class} does not implement '#{m}'."
    else
      super
    end
  end
end

module Schemes
  @schemes = {}
  Dir.glob(File.join(File.dirname(__FILE__),"schemes","*")).each do |scheme|
    name = File.basename(scheme,'.rb')
    require_relative scheme
    @schemes[name.split('_')[0..-2].join.to_sym] = Object.const_get(name.classify)
  end

  def self.get(name)
    @schemes[name.to_sym] || fail("Cannot find scheme '#{name}'")
  end
end

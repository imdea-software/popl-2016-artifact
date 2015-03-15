require_relative 'prelude'

module Implementations
  @implementations = {}
  Dir.glob(File.join(File.dirname(__FILE__),"implementations","*")).each do |impl|
    name = File.basename(impl,'.rb')
    require_relative impl
    @implementations[name.to_sym] = Object.const_get(name.classify)
  end

  def self.get(name)
    @implementations[name.to_sym] || fail("Unknown implementation '#{name}'")
  end

end

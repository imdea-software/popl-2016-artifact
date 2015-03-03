require_relative 'prelude'

module Implementations
  name = File.basename(__FILE__,'.rb')
  @options = YAML.load_file(File.join('config',"#{name}.yaml")).symbolize
  
  @options[:requires].each do |r|
    require_relative r
  end

  def self.get(id, num_threads: 7)
    obj = @options[:implementations].find{|obj| obj[:id] == id}
    if obj
      klass = Object.const_get(obj[:class])
      klass.initialize(num_threads) if klass.methods.include?(:initialize)
      Proc.new do
        if klass.methods.include?(:create)
          klass.create(*obj[:args])
        else
          klass.new(*obj[:args])
        end
      end
    else
      fail "Unknown implementation: #{id}"
    end
  end
end

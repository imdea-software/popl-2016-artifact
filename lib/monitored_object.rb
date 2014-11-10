class MonitoredObject
  attr_accessor :object
  attr_accessor :mutex
  def initialize(object, *observers)
    @object = object
    @mutex = Mutex.new
    @observers = observers
    @observers.each do |o|
      fail "XXX: #{o.class}" unless o.respond_to?(:update)
    end
    @unique_id = 0
    object.methods.each do |m|
      next if Object.instance_methods.include? m
      next if object.methods.include?("#{m.to_s.chomp('=')}=".to_sym)
      (class << self; self; end).class_eval do
        case object.method(m).arity
        when 0
          define_method(m) do
            id = @mutex.synchronize do
              uid = (@unique_id += 1)
              @observers.each {|o| o.update(:start, uid, m)}
              uid
            end
            rets = @object.send(m)
            @mutex.synchronize do
              @observers.each {|o| o.update(:complete, id, *rets)}
            end
            rets
          end
        when 1
          define_method(m) do |arg|
            id = @mutex.synchronize do
              uid = (@unique_id += 1)
              @observers.each {|o| o.update(:start, uid, m, arg)}
              uid
            end
            rets = @object.send(m,arg)
            @mutex.synchronize do
              @observers.each {|o| o.update(:complete, id, *rets)}
            end
            rets
          end
        else fail "Unexpected arity for method #{m}."
        end
      end
    end
  end
end

module ConcurrentObject

  class Operation
    @@unique_id = 0
    attr_accessor :id
    attr_accessor :method_name, :arg_value, :return_value
    attr_accessor :start_time, :end_time
    attr_accessor :min_time, :max_time
    attr_accessor :dependencies

    def initialize(method, *args, time)
      @id = (@@unique_id += 1)
      start!(method, *args, time)
    end

    def start!(method, *args, time)
      @method_name = method
      @arg_value = *args.compact
      @min_time = @start_time = time
    end

    def complete!(*vals, time, pending_ops)
      fail "#{self} already completed!" if completed?
      @return_value = *vals.compact
      @max_time = @end_time = time
      @dependencies = pending_ops
    end

    def refresh!
      @dependencies.reject!(&:completed?) if @dependencies
    end

    def to_s
      arg = @arg_value == [] ? "" : "(#{@arg_value * ", "})"
      ret = case @return_value
        when nil; "..."
        when []; ""
        else " => #{@return_value * ", "}"
      end
      str = ""
      str << "#{@id}: "
      str << "#{@method_name}#{arg}#{ret}"
      # str << " (#{@start_time},#{@min_time},#{@max_time || "_"},#{@end_time || "_"})"
      str
    end

    def pending?; @end_time.nil? end
    def completed?; !pending? end
    def obsolete?; completed? && @dependencies.empty? end
    def impossible?; @end_time && @end_time < @start_time end

    def before?(op) completed? && (op.nil? || @end_time < op.start_time) end

    def before!(op)
      updated = false
      if completed? && op && op.completed? && @max_time > op.max_time
        @max_time = op.max_time
        updated = true
      end
      if op && op.min_time < @min_time
        op.min_time = @min_time
        updated = true
      end
      updated
    end
  end

  class Monitor
    attr_accessor :operations
    attr_accessor :time
    attr_accessor :mutex

    def initialize
      @operations = []
      @time = 0
      @mutex = Mutex.new
    end

    def create_op(method, *args)
      Operation.new(method, *args, @time)
    end

    def on_call(method, *args)
      op = nil
      @mutex.synchronize do
        op = create_op(method, *args)
        @operations << op
        @time += 1
        on_start! op
      end
      return op
    end

    def on_return(op, val)
      @mutex.synchronize do
        op.complete!(val, @time, @operations.select(&:pending?))
        @time += 1
        on_completed! op
        fail "Found a contradiction\n#{to_s}" if contradiction?
        cleanup!
      end
    end

    def on_start!(op)
      # nothing to do in the default case
    end

    def on_completed!(op)
      # nothing to do in the default case
    end

    def contradiction?
      @operations.any?(&:impossible?)
    end

    def cleanup!
      @operations.each(&:refresh!)
      @operations.reject!(&:obsolete?)
    end

    def stats; {
      time: @time,
      ops: @operations.count,
      pending: @operations.select(&:pending?).count
      }
    end

    def interval_s(op, relative_time: 0)
      bracket = {true => '|', false => ':'}
      mark = {tick: '-', empty: ' ', pending: '*', invalid: 'X'}

      i = op.start_time - relative_time
      ii = op.min_time - relative_time
      jj = op.max_time
      j = op.end_time
      jj -= relative_time if jj
      j -= relative_time if j
      k = @time - relative_time

      str = ""
      str << " " * i
      if jj && ii > jj
        str << mark[:invalid] * (j-i+1)
        str << " " * (k-j)
      else
        str << mark[:empty] * (ii-i)
        if j
          str << mark[:tick] * (jj-ii+1)
          str << mark[:empty] * (j-jj)
          str << " " * (k-j)
        else
          str << mark[:tick] * (k-ii)
          str << mark[:pending]
        end
      end
      str[i] = bracket[i==ii]
      str[j] = bracket[j==jj] if j
      str
    end

    def interval_ss(ops: @operations, relative_time: ops.map(&:start_time).min)
      intervals = ops.map{|op| interval_s(op, relative_time: relative_time) + "  #{op}"}
      # TODO cut out the voids for better display?
      # filled_positions = intervals.map{|i| i.length.times.select{|p| i[p] != ' '}}.reduce(:|)
      # intervals.each{|i| (i.length-1).downto(0) {|p| i[p] = '' unless filled_positions.include?(p)}}
      intervals
    end

    def debug_before_and_after(msg, focused_ops)
      t0 = @operations.map(&:start_time).min
      focused_before = interval_ss(ops: focused_ops.compact, relative_time: t0)
      if yield then
        intervals = interval_ss
        focused_after = interval_ss(ops: focused_ops.compact, relative_time: t0)
        info = stats.map{|k,v| "#{k}: #{v}"} * ", "
        width = (intervals.map(&:length) + [info.length]).max
        puts "-" * width
        puts msg, info
        puts "-" * width
        puts intervals
        puts "-" * width
        puts "BEFORE", focused_before
        puts "-" * width
        puts "AFTER", focused_after
        puts "-" * width
      end
    end

    def to_s
      intervals = interval_ss
      title = "History | " + stats.map{|k,v| "#{k}: #{v}"} * ", "
      width = (intervals.map(&:length) + [title.length]).max
      str = ""
      str << '-' * width << "\n"
      str << title << "\n"
      str << '-' * width << "\n"
      str << intervals * "\n" << "\n"
      str << '-' * width
      str
    end
  end

  class MonitoredObject
    attr_accessor :object, :monitor
    def initialize(object, monitor)
      @object = object
      @monitor = monitor
      object.methods.each do |m|
        next if Object.instance_methods.include? m
        next if object.methods.include?("#{m.to_s.chomp('=')}=".to_sym)
        (class << self; self; end).class_eval do
          case object.method(m).arity
          when 0
            define_method(m) do
              op = @monitor.on_call(m)
              ret = @object.send(m)
              @monitor.on_return(op, ret)
              ret
            end
          when 1
            define_method(m) do |a|
              op = @monitor.on_call(m, a)
              ret = @object.send(m, a)
              @monitor.on_return(op, ret)
              ret
            end
          else
            fail "Unexpected number of arguments for method #{m}"
          end
        end
      end
    end
  end

end

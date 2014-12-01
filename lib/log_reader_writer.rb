class LogReaderWriter

  def initialize(file, object)
    @queue = Queue.new
    Thread.new do
      File.open(file,'w') do |f|
        f.puts "# @object #{object}"
        loop do
          line = @queue.pop
          break unless line
          f.puts line
        end
      end
    end
    yield self
    @queue << nil
  end

  def update(msg, *args)
    case msg
    when :start;    @queue << self.class.call!(*args)
    when :complete; @queue << self.class.return!(*args)
    end
  end

  def self.extract_metadata(key, file)
    File.open(file) do |f|
      f.each do |line|
        line.match(/@#{key} (?'obj'.*)/) do |m|
          return m[:obj].strip
        end
      end
    end
    return nil
  end

  def self.object(file); extract_metadata(:object, file) end

  def self.call!(id, method_name, *values)
    "[#{id}] call #{method_name}#{"(#{values * ", "})" unless values.empty?}"
  end

  def self.return!(id, *values)
    "[#{id}] return#{" #{values * ", "}" unless values.empty?}"
  end

  def self.call?(str)
    str.match(/\A\[(?'id'\d+)\]\s*call \s*(?'method'\w+)(\((?'values'\w+(\s*,\s*\w+)*)?\))?\Z/) do |m|
      yield(
        m[:id].to_i,
        m[:method].to_sym,
        (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)) if block_given?
      return true
    end
    false
  end

  def self.return?(str)
    str.match(/\A\[(?'id'\d+)\]\s*ret(urn)?\s*(?'values' \w+(\s*,\s*\w+)*)?\Z/) do |m|
      yield(
        m[:id].to_i,
        (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)) if block_given?
      return true
    end
    false
  end

  def self.read(file)
    ids = {}
    File.open(file) do |f|
      f.each do |line|

        # strip comments and whitespace
        str = (line.split('#').first || "").strip
        next if str.empty?

        next if call?(str) do |id, method, values|
          fail "Duplicate operation identifier #{id}" if ids.include?(id)
          ids[id] = yield :call, method, *values
        end

        next if return?(str) do |id, values|
          fail "Unexpected operation identifier #{id}" unless ids.include?(id)
          yield :return, ids[id], *values
        end
        
        fail "Unexpected action '#{line}'"

      end
    end
  end
end

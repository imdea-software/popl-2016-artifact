class LogReaderWriter
  def initialize(file, object: nil)
    @file = file
    @object = object
  end

  def extract_metadata(name)
    File.open(@file) do |f|
      f.each do |line|
        line.match(/@#{name} (?'obj'.*)/) do |m|
          return m[:obj].strip
        end
      end
    end
    return nil
  end

  def object; extract_metadata(:object) end

  def call!(id, method_name, *values)
    "[#{id}] call #{method_name}#{"(#{values * ", "})" unless values.empty?}"
  end

  def return!(id, *values)
    "[#{id}] return#{" #{values * ", "}" unless values.empty?}"
  end

  def call?(str)
    str.match(/\A\[(?'id'\d+)\]\s*call \s*(?'method'\w+)(\((?'values'\w+(\s*,\s*\w+)*)?\))?\Z/) do |m|
      yield(
        m[:id].to_i,
        m[:method].to_sym,
        (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)) if block_given?
      return true
    end
    false
  end

  def return?(str)
    str.match(/\A\[(?'id'\d+)\]\s*ret(urn)?\s*(?'values' \w+(\s*,\s*\w+)*)?\Z/) do |m|
      yield(
        m[:id].to_i,
        (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)) if block_given?
      return true
    end
    false
  end

  def update(msg, *args)
    unless @file.is_a?(IO)
      @file = File.open(@file, 'w', autoclose: true)
      @file.puts "# @object #{@object}"
    end
    case msg
    when :start;    @file.puts call!(*args)
    when :complete; @file.puts return!(*args)
    end
  end

  def read
    ids = {}
    File.open(@file) do |f|
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

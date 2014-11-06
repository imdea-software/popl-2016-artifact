require_relative 'history'

class ExecutionLogParser
  def initialize(file)
    @input_file = file
  end

  def extract_metadata(name)
    File.open(@input_file) do |f|
      f.each do |line|
        line.match(/@#{name} (?'obj'.*)/) do |m|
          return m[:obj].strip
        end
      end
    end
  end

  def object; extract_metadata(:object) end

  def parse!
    h = History.new
    ids = {}
    File.open(@input_file) do |f|
      f.each do |line|

        # strip comments and whitespace
        line = (line.split('#').first || "").strip
        next if line.empty?

        if line.match(/\A\[(?'id'\d+)\]\s*call \s*(?'method'\w+)(\((?'values'\w+(\s*,\s*\w+)*)?\))?\Z/) do |m|
          id = m[:id].to_i
          fail "Duplicate operation identifier #{id}" if ids.include?(id)
          method = m[:method].to_sym
          values = (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)
          ids[id] = h.start!(method,*values)
          true
        end

        elsif line.match(/\A\[(?'id'\d+)\]\s*ret(urn)?\s*(?'values' \w+(\s*,\s*\w+)*)?\Z/) do |m|
          id = m[:id].to_i
          values = (m[:values] || "").split(/\s*,\s*/).map(&:strip).map(&:to_sym)
          h.complete!(ids[id],*values)
          ids.delete id
          true
        end
        else
          fail "Unexpected action '#{line}'"
        end
        yield h if block_given?
      end
    end
    h
  end
end

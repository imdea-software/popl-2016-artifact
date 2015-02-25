#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'yaml'

FIELDS = [:sources, :algorithms, :timeouts]
FIELDS.each {|f| self.class.const_set("DEFAULT_#{f.upcase}", [])}

DEFAULT_SOURCES << "data/histories/simple/*.log"
DEFAULT_SOURCES << "data/histories/generated/my-sync-stack.*.log"
DEFAULT_SOURCES << "data/histories/generated/my-unsafe-stack/*.log"
DEFAULT_SOURCES << "data/histories/generated/big/ScalObject-msq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-bkq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-dq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-fcq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-lbq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-msq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-rdq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-sl/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-ts/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-ukq/*.log"
DEFAULT_SOURCES << "data/histories/generated/small/ScalObject-wfq11/*.log"

DEFAULT_ALGORITHMS << "saturate"
DEFAULT_ALGORITHMS << "saturate -r"
DEFAULT_ALGORITHMS << "counting -b 0"
DEFAULT_ALGORITHMS << "counting -b 0 -r"
# DEFAULT_ALGORITHMS << "counting -b 1"
# DEFAULT_ALGORITHMS << "counting -b 1 -r"
DEFAULT_ALGORITHMS << "counting -b 2"
DEFAULT_ALGORITHMS << "counting -b 2 -r"
# DEFAULT_ALGORITHMS << "counting -b 3"
# DEFAULT_ALGORITHMS << "counting -b 3 -r"
DEFAULT_ALGORITHMS << "counting -b 4"
DEFAULT_ALGORITHMS << "counting -b 4 -r"
DEFAULT_ALGORITHMS << "symbolic"
DEFAULT_ALGORITHMS << "symbolic -r"
# DEFAULT_ALGORITHMS << "symbolic -c"
# DEFAULT_ALGORITHMS << "symbolic -i"
# DEFAULT_ALGORITHMS << "symbolic -i -r" # TODO this one is buggy
# DEFAULT_ALGORITHMS << "enumerate"
DEFAULT_ALGORITHMS << "enumerate -c"
DEFAULT_ALGORITHMS << "enumerate -c -r"

DEFAULT_TIMEOUTS << 5

DISPLAY = { history: 1, algorithm: 9, removal: 1, steps: 3, checks: 3, width: 4, weight: 4, time: 7, violation: 1 }

def flatten_hash(hash, path=[])
  result = hash.map do |key, value|
    case value
    when Hash then flatten_hash(value, path+[key])
    else [[path+[key], value]]
    end
  end.flatten(1)
  if path.empty? then
    result.map{|keys, value| [keys * ".", value]}.to_h
  else
    result
  end
end

def display(rec)
  DISPLAY.map do |key,width|
    val = rec[key.to_s]
    case val
    when Float; val.round(4).to_s
    when true;  "√"
    when false; "-"
    when /\?/;    "?"
    when Hash
      val['mean'].round(1).to_s
    else          val.to_s
    end.ljust(width)
  end * " | "
end

def separator(sym: "-", joint: "+")
  DISPLAY.map {|_,width| sym * width} * "#{sym}#{joint}#{sym}"
end

class DataWriter
  def initialize(file)
    @file = file
    @hit = false
  end

  def notify(data)
    data = flatten_hash(data)
    File.open(@file,'w') {|f| f.puts(data.keys * "\t")} unless @hit
    File.open(@file,'a') {|f| f.puts(data.values * "\t")}
    @hit ||= true
  end
end

def parse_options
  options = OpenStruct.new
  options.data_file = nil
  FIELDS.each {|f| options.send("#{f}=",[])}

  OptionParser.new do |opts|

    opts.banner = "Usage: #{File.basename $0} [options]"

    opts.separator ""

    opts.on("-h", "--help", "Show this message.") do
      puts opts
      exit
    end

    opts.on("-s", "--source S", "Add a source, e.g. 'data/histories/simple/*.log'") do |s|
      options.sources << s
    end

    opts.on("-a", "--algorithm A", "Add an algorithm, e.g. 'symbolic -r'") do |a|
      options.algorithms << a
    end

    opts.on("-t", "--timeout N", Integer, "Add a timeout.") do |n|
      options.timeouts << n
    end

    opts.on("-f", "--data-file FILE", "Write data to file.") do |f|
      options.data_file = f
    end
  end.parse!

  FIELDS.each do |f|
    list = options.method(f).call
    list.push(*self.class.const_get("DEFAULT_#{f.upcase}")) if list.empty?
  end

  options
end

begin
  @options = parse_options

  puts "Generating reports for #{@options.sources * ", "}"
  writer = DataWriter.new(@options.data_file) if @options.data_file

  @options.sources.each do |source|
    DISPLAY[:history] = Dir.glob(source).map{|f| File.basename(f).length}.max || 1

    @options.timeouts.each do |timeout|
      puts separator(joint: "-")
      puts "#{source} (timeout #{timeout || "-"}s)".center(separator.length)
      puts separator(joint: "-")
      puts DISPLAY.map {|key,width| key.to_s[0,width].ljust(width)} * " | "
      puts separator
  
      Dir.glob(source) do |history|
        @options.algorithms.each do |algorithm|
          cmd = "#{File.dirname(__FILE__)}/logchecker.rb \"#{history}\" -a #{algorithm}"
          cmd << " -t #{timeout}" if timeout
          output = `#{cmd}`
          data = YAML.load(output.split("---")[1])
          puts display(data)
          writer.notify(data) if writer
        end
        puts separator
      end
    end
  end

rescue SystemExit, Interrupt

ensure

end

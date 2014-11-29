#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

FIELDS = [:sources, :algorithms, :timeouts]
FIELDS.each {|f| self.class.const_set("DEFAULT_#{f.upcase}", [])}

DEFAULT_SOURCES << "examples/simple/*.log"
DEFAULT_SOURCES << "examples/generated/my-sync-stack.*.log"
DEFAULT_SOURCES << "examples/generated/my-unsafe-stack/*.log"
DEFAULT_SOURCES << "examples/generated/bkq-very-concurrent/*.log"
DEFAULT_SOURCES << "examples/generated/msq-very-concurrent/*.log"
DEFAULT_SOURCES << "examples/generated/bkq-almost-sequential/*.log"
DEFAULT_SOURCES << "examples/generated/msq-almost-sequential/*.log"

DEFAULT_ALGORITHMS << "saturate"
DEFAULT_ALGORITHMS << "saturate -r"
DEFAULT_ALGORITHMS << "counting -b 0"
DEFAULT_ALGORITHMS << "counting -b 0 -r"
DEFAULT_ALGORITHMS << "counting -b 1"
DEFAULT_ALGORITHMS << "counting -b 1 -r"
DEFAULT_ALGORITHMS << "counting -b 2"
DEFAULT_ALGORITHMS << "counting -b 2 -r"
DEFAULT_ALGORITHMS << "counting -b 3"
DEFAULT_ALGORITHMS << "counting -b 3 -r"
DEFAULT_ALGORITHMS << "counting -b 4"
DEFAULT_ALGORITHMS << "counting -b 4 -r"
DEFAULT_ALGORITHMS << "symbolic"
DEFAULT_ALGORITHMS << "symbolic -r"
DEFAULT_ALGORITHMS << "symbolic -c"
DEFAULT_ALGORITHMS << "symbolic -i"
DEFAULT_ALGORITHMS << "symbolic -i -r"
DEFAULT_ALGORITHMS << "enumerate"
DEFAULT_ALGORITHMS << "enumerate -c"
DEFAULT_ALGORITHMS << "enumerate -r"

DEFAULT_TIMEOUTS << 5

COLUMNS = [:history, :object, :algorithm, :steps, :time, :violation]
DISPLAY = { history: 1, algorithm: 13, steps: 5, time: 10, violation: 1 }

def extract_record(output)
  rec = {}
  COLUMNS.map do |key|
    m = output.match(/#{key.upcase}:\s+(.*)/)
    rec[key] = m ? m[1].strip : "?"
  end
  rec
end

def display_record(rec)
  DISPLAY.map do |key,width|
    case rec[key]
    when /true/;  "√"
    when /false/; "-"
    when /\?/;    "?"
    else          rec[key]
    end.ljust(width)
  end * " | "
end

def separator(sym: "-", joint: "+")
  DISPLAY.map {|_,width| sym * width} * "#{sym}#{joint}#{sym}"
end

class DataWriter
  def initialize(file)
    @file = file
    File.open(@file,'w') {|f| f.puts(COLUMNS * "\t")}
  end

  def notify(record)
    File.open(@file,'a') {|f| f.puts(COLUMNS.map{|k| record[k]} * "\t")}
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

    opts.on("-s", "--source S", "Add a source, e.g. 'examples/simple/*.log'") do |s|
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
  data = DataWriter.new(@options.data_file) if @options.data_file

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
          rec = extract_record(output)
          rec[:history] = File.basename(rec[:history])
          puts display_record(rec)
          data.notify(rec) if data
        end
        puts separator
      end
    end
  end
end

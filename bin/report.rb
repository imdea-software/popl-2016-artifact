#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

FIELDS = [:sources, :algorithms, :timeouts, :data_observers]
FIELDS.each {|f| self.class.const_set("DEFAULT_#{f.upcase}", [])}

DEFAULT_SOURCES << "examples/generated/ScalObject-bkq/*.log"
DEFAULT_SOURCES << "examples/generated/ScalObject-msq/*.log"
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
DEFAULT_ALGORITHMS << "symbolic -r -r"
DEFAULT_ALGORITHMS << "symbolic -i"
DEFAULT_ALGORITHMS << "symbolic -i -r"
DEFAULT_ALGORITHMS << "enumerate"
DEFAULT_ALGORITHMS << "enumerate -c"
DEFAULT_ALGORITHMS << "enumerate -r"

DEFAULT_TIMEOUTS << 5

COLUMNS = { example: 1, algorithm: 1, step: 4, viol: 4, time: 10 }

def stats(example, timeout, algorithm, output)
  v = (output.match(/VIOLATION: (.*)/) || ["","?"])[1].strip == "true"
  s = (output.match(/STEPS: (.*)/) || ["","?"])[1].strip
  t = (output.match(/TIME: (.*)/) || ["","?"])[1].strip

  # filter out the CHEATERS who exceeded the timeout substantially
  v = s = t = "?" if timeout && t != "?" && (t.chomp("s").to_f - timeout > 1)

  { example: example,
    timeout: timeout,
    algorithm: algorithm,
    step: s,
    viol: v && s,
    time: t
  }
end

def format(stats)
  COLUMNS.map {|title,width| (stats[title] || "-").ljust(width)} * " | "
end

def sep(sym: "-", joint: "+")
  COLUMNS.map {|_,width| sym * width} * "#{sym}#{joint}#{sym}"
end

class DataObserver
  def initialize(file)
    @data = {}
    @file = file
  end
  def to_s; name    end
  def notify(stat)  end
  def write;        end  

  def self.get(d,file)
    case d
    when /steps-until-timeout/
      AverageStepsUntilTimeoutDataObserver.new(file)
    else fail "Unexpected data observer: #{d}"
    end
  end
end

class AverageStepsUntilTimeoutDataObserver < DataObserver
  def initialize(file)
    super(file || "avg-steps-until-timeout.csv")
  end
  def name; "Average Steps Until Timeout" end

  def notify(stat)
    @data[stat[:timeout]] ||= {}
    @data[stat[:timeout]][stat[:algorithm]] ||= []
    @data[stat[:timeout]][stat[:algorithm]] << stat[:step].chomp("*")
  end

  def write
    algorithms = @data[@data.keys.first].keys
    @data.each do |timeout, algs|
      algs.each do |algorithm, step_counts|
        @data[timeout][algorithm] = 
          (step_counts.map{|c| c.to_i if c =~ /\A\d+\z/}.reduce(:+).to_f /
          step_counts.count).round(1)
      end
    end
    File.open(@file,'w') do |f|
      f.puts "timeout, #{algorithms * ", "}"
      @data.each do |timeout, algs|
        f.puts "#{timeout}, #{algorithms.map{|a| algs[a]} * ", "}"
      end
    end
  end
end

def parse_options
  options = OpenStruct.new
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

    opts.on("-d", "--data-observer D,FILE", Array, "Add a data observer, e.g. 'steps-until-timeout'") do |d,f|
      options.data_observers << DataObserver.get(d,f)
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

  @options.sources.each do |source|
    COLUMNS[:example] = Dir.glob(source).map{|f| File.basename(f).length}.max
    COLUMNS[:algorithm] = @options.algorithms.map(&:length).max

    @options.timeouts.each do |timeout|
      puts sep(joint: "-")
      puts "#{source} (timeout #{timeout || "-"}s)".center(sep.length)
      puts sep(joint: "-")
      puts COLUMNS.map {|title,width| title.to_s.ljust(width)} * " | "
      puts sep
  
      Dir.glob(source) do |example|
        @options.algorithms.each do |algorithm|
          cmd = "#{File.dirname(__FILE__)}/logchecker.rb \"#{example}\" -a #{algorithm}"
          cmd << " -t #{timeout}" if timeout
          output = `#{cmd}`
          puts format(s = stats(File.basename(example), timeout, algorithm, output))
          @options.data_observers.each {|d| d.notify s}
        end
        puts sep
      end
    end
  end

  @options.data_observers.each do |d|
    puts "Writing data from observer: #{d}."
    d.write
  end

end

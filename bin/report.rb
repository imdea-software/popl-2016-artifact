#!/usr/bin/env ruby

require 'optparse'
require 'yaml'

class DataDisplay
  def initialize(header, column_spec)
    @column_spec = column_spec
    puts separator(joint: "-")
    puts header.center(separator.length)
    puts separator(joint: "-")
    puts @column_spec.map {|key,width| key.to_s[0,width].ljust(width)} * " | "
    puts separator
  end

  def next
    puts separator
  end

  def notify(data)
    puts column(data)
  end

  def separator(sym: "-", joint: "+")
    @column_spec.map {|_,width| sym * width} * "#{sym}#{joint}#{sym}"
  end

  def cell(val)
    case val
    when Float; val.round(4)
    when true;  "√"
    when false; "-"
    when /\?/;  "?"
    when Hash;  val['mean'].round(1)
    else        val
    end.to_s
  end

  def column(data)
    @column_spec.map {|key,width| cell(data[key.to_s]).ljust(width)} * " | "
  end
end

class DataWriter
  def initialize(file)
    @file = file
    @hit = false
    @sep = case file when /.csv/; "," else "\t" end
  end

  def notify(data)
    data = flatten_hash(data)
    File.open(@file,'w') {|f| f.puts(data.keys * @sep)} unless @hit
    File.open(@file,'a') {|f| f.puts(data.values * @sep)}
    @hit ||= true
  end

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
end

def parse_options
  options = {}
  OptionParser.new do |opts|

    opts.banner = "Usage: #{File.basename $0} [options]"

    opts.separator ""

    opts.on("-h", "--help", "Show this message.") do
      puts opts
      exit
    end

    opts.on("-s", "--source S", "Add a source, e.g. 'data/histories/simple/*.log'") do |s|
      options['sources'] ||= []
      options['sources'] << s
    end

    opts.on("-a", "--algorithm A", "Add an algorithm, e.g. 'symbolic -r'") do |a|
      options['algorithms'] ||= []
      options['algorithms'] << a
    end

    opts.on("-t", "--timeout N", Integer, "Add a timeout.") do |n|
      options['timeouts'] ||= []
      options['timeouts'] << n
    end

    opts.on("-f", "--data-file FILE", "Write data to file.") do |f|
      options['data_file'] = f
    end
  end.parse!

  options
end

begin
  name = File.basename(__FILE__,'.rb')
  options = YAML.load_file(File.join('config',"#{name}.yaml")).merge(parse_options)
  checker = File.join('bin', 'logchecker.rb')

  puts "Generating reports for #{options['sources'] * ", "}"
  writer = DataWriter.new(options['data_file']) if options['data_file']

  options['sources'].each do |source|
    length = Dir.glob(source).map{|f| File.basename(f).length}.max || 1

    options['timeouts'].each do |timeout|
      display = DataDisplay.new("#{source} (timeout #{timeout || "-"}s)", options['display'].merge({"history" => length}))

      Dir.glob(source) do |history|
        options['algorithms'].each do |algorithm|
          cmd = "#{checker} \"#{history}\" -a #{algorithm}"
          cmd << " -t #{timeout}" if timeout
          output = `#{cmd}`
          data = YAML.load(output.split("---")[1])
          display.notify(data)
          writer.notify(data) if writer
        end
        display.next
      end
    end
  end

rescue SystemExit, Interrupt

ensure

end

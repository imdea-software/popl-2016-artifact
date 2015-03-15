#!/usr/bin/env ruby

require_relative '../lib/prelude.rb'

def parse_options
  options = {}
  OptionParser.new do |opts|

    opts.banner = "Usage: #{File.basename $0} [options]"

    opts.separator ""

    opts.on("-h", "--help", "Show this message.") do
      puts opts
      exit
    end

    opts.on("-i", "--implementation I", "Add an implementation, e.g. 'scal_object -x id=msq'") do |i|
      options[:implementations] ||= []
      options[:implementations] << i
    end

    opts.on("-f", "--data-file FILE", "Write data to file.") do |f|
      options[:data_file] = f
    end

  end.parse!

  options
end

begin
  name = File.basename(__FILE__,'.rb')
  options = YAML.load_file(File.join('config',"#{name}.yaml")).symbolize.merge(parse_options)
  pattern_finder = File.join('lib', 'pattern_finder.rb')

  puts "#{"-" * 80}"
  puts "PATTERN REPORT"
  puts "#{"-" * 80}"

  options[:implementations].each do |impl|
    cmd = "#{pattern_finder} #{impl}"
    system(cmd)
    puts "#{"-" * 80}"
  end

rescue SystemExit, Interrupt

ensure

end

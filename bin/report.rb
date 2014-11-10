#!/usr/bin/env ruby

SOURCES = []
FLAGSS = []
COLUMNS = { example: 1, flags: 1, step: 4, viol: 4, time: 10 }
TIMEOUT = 5

SOURCES << "examples/generated/*"
SOURCES << "examples/simple/*"
FLAGSS << "-a saturation"
FLAGSS << "-a saturation -r"
FLAGSS << "-a smt"
FLAGSS << "-a smt -r"
FLAGSS << "-a smt -i"
FLAGSS << "-a smt -c"
FLAGSS << "-a smt -c -i"
FLAGSS << "-a lineup"
FLAGSS << "-a lineup -c"

def stats(example, flags, output)
  v = output.match(/VIOLATION: (.*)/)[1].strip == "true"
  s = output.match(/STEPS: (.*)/)[1].strip
  t = output.match(/TIME: (.*)/)[1].strip
  { example: example,
    flags: flags,
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

SOURCES.each do |source|
  COLUMNS[:example] = Dir.glob(source).map{|f| File.basename(f).length}.max
  COLUMNS[:flags] = FLAGSS.map(&:length).max

  puts sep(joint: "-")
  puts "Report for #{source}"
  puts sep(joint: "-")
  puts COLUMNS.map {|title,width| title.to_s.ljust(width)} * " | "
  puts sep
  
  Dir.glob(source) do |example|
    FLAGSS.each do |flags|
      cmd = "#{File.dirname(__FILE__)}/logchecker.rb \"#{example}\" #{flags}"
      cmd << " -t #{TIMEOUT}" if TIMEOUT
      output = `#{cmd}`
      puts format(stats(File.basename(example), flags, output))
    end
    puts sep
  end
end

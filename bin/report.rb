#!/usr/bin/env ruby

SOURCES = []
FLAGSS = []
COLUMNS = { example: 1, flags: 1, step: 4, viol: 4, time: 10 }
TIMEOUT = 5

SOURCES << "examples/simple/*.log"
SOURCES << "examples/generated/my-sync-stack.*.log"
SOURCES << "examples/generated/my-unsafe-stack/*.log"
SOURCES << "examples/generated/bkq-very-concurrent/*.log"
SOURCES << "examples/generated/msq-very-concurrent/*.log"
SOURCES << "examples/generated/bkq-almost-sequential/*.log"
SOURCES << "examples/generated/msq-almost-sequential/*.log"

FLAGSS << "-a saturate"
FLAGSS << "-a saturate -r"
FLAGSS << "-a symbolic"
FLAGSS << "-a symbolic -r"
FLAGSS << "-a symbolic -i"
FLAGSS << "-a symbolic -c"
FLAGSS << "-a symbolic -c -i"
FLAGSS << "-a enumerate"
FLAGSS << "-a enumerate -c"

def stats(example, flags, output)
  v = (output.match(/VIOLATION: (.*)/) || ["","?"])[1].strip == "true"
  s = (output.match(/STEPS: (.*)/) || ["","?"])[1].strip
  t = (output.match(/TIME: (.*)/) || ["","?"])[1].strip
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

puts "Generating reports for #{SOURCES * ", "}"
puts "Algorithm timeout for each example set to #{TIMEOUT}s." if TIMEOUT

SOURCES.each do |source|
  COLUMNS[:example] = Dir.glob(source).map{|f| File.basename(f).length}.max
  COLUMNS[:flags] = FLAGSS.map(&:length).max

  puts sep(joint: "-")
  puts source.center(sep.length)
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

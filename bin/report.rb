#!/usr/bin/env ruby

SOURCES = [
  "examples/simple/*"
]

FLAGSS = [
  "-a saturation",
  "-a saturation -r",
  "-a smt",
  "-a smt -r",
  "-a smt -i",
  "-a smt -c",
  "-a smt -c -i",
  "-a lineup",
  "-a lineup -c"
]

COLUMNS = {
  example: 1,
  flags: 20,
  step: 4,
  time: 10
}

def stats(example, flags, output)
  v = output.match(/VIOLATION: (.*)/)[1].strip == "true"
  s = output.match(/STEPS: (.*)/)[1].strip
  t = output.match(/TIME: (.*)/)[1].strip
  { example: example,
    flags: flags,
    step: v && s,
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
      output = `#{File.dirname(__FILE__)}/logchecker.rb #{example} #{flags}`
      puts format(stats(File.basename(example), flags, output))
    end
    puts sep
  end
end

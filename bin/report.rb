#!/usr/bin/env ruby

FLAGSS = [
  "-a saturation",
  "-a smt",
  "-a smt -i",
  "-a smt -c",
  "-a smt -c -i",
  "-a lineup",
  "-a lineup -c"
]

COLUMNS = {
  example: 20,
  flags: 20,
  step: 5,
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

def sep
  COLUMNS.map {|_,width| "-" * width} * "-+-"
end

["examples/simple/*"].each do |source|
  puts "-" * 80
  puts "Report for #{source}"
  puts "-" * 80
  puts COLUMNS.map {|title,width| title.to_s.ljust(width)} * " | "
  puts sep

  Dir.glob(source) do |example|
    FLAGSS.each do |flags|
      puts format(stats(File.basename(example), flags,`#{File.dirname(__FILE__)}/logchecker.rb #{example} #{flags}`))
    end
    puts sep
  end
  puts "-" * 80
end

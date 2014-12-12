require 'optparse'
require 'ostruct'
require 'logger'

module Kernel
  def log
    @@logger ||= (
      l = Logger.new(STDOUT,'daily')
      l.formatter = proc do |severity, datetime, progname, msg|
        "[#{progname || severity}] #{msg}\n"
      end
      l
    )
  end
end

log.level = Logger::WARN

module Enumerable
  def mean
    inject(&:+) / length.to_f
  end
  def sample_variance
    m = mean
    inject(0){|sum,i| sum + (i-m)**2} / (length-1).to_f
  end
  def standard_deviation
    Math.sqrt(sample_variance)
  end
end

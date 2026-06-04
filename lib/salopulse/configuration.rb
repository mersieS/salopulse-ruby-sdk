require "logger"

module Salopulse
  class Configuration
    attr_accessor :dsn, :release, :environment, :sample_rate,
                  :flush_interval, :flush_batch_size, :n1_threshold,
                  :before_send, :logger, :enabled, :max_buffer_size

    def initialize
      @release = nil
      @environment = nil
      @sample_rate = 1.0
      @flush_interval = 5
      @flush_batch_size = 100
      @n1_threshold = 10
      @before_send = nil
      @logger = Logger.new($stdout, level: Logger::WARN)
      @enabled = true
      @max_buffer_size = 10_000
    end
  end
end

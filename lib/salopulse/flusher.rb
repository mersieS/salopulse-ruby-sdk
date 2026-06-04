module Salopulse
  class Flusher
    def initialize(buffer:, transport:, interval:, batch_size:, logger:)
      @buffer = buffer
      @transport = transport
      @interval = interval
      @batch_size = batch_size
      @logger = logger
      @stop = false
      @thread = nil
    end

    def start
      return if @thread&.alive?
      @stop = false
      @thread = Thread.new do
        Thread.current.name = "salopulse-flusher" if Thread.current.respond_to?(:name=)
        loop do
          break if @stop
          begin
            flush_once
          rescue StandardError => e
            @logger.error("[Salopulse] flusher error: #{e.class}: #{e.message}")
          end
          sleep_with_interrupt(@interval)
        end
      end
    end

    def flush_once
      events = @buffer.drain(max: @batch_size)
      return 0 if events.empty?
      @transport.send_batch(events)
      events.size
    end

    def flush_all(timeout: 5)
      deadline = monotonic_now + timeout
      total = 0
      while !@buffer.empty? && monotonic_now < deadline
        total += flush_once
      end
      total
    end

    def stop(timeout: 5)
      @stop = true
      flush_all(timeout: timeout)
      @thread&.join(timeout)
    end

    def alive?
      @thread&.alive? || false
    end

    private

    def sleep_with_interrupt(seconds)
      slept = 0.0
      step = 0.2
      while slept < seconds && !@stop
        sleep step
        slept += step
      end
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

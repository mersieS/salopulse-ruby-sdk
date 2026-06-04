require "thread"

module Salopulse
  class Buffer
    DEFAULT_MAX_SIZE = 10_000

    def initialize(max_size: DEFAULT_MAX_SIZE)
      @queue = Queue.new
      @max_size = max_size
      @mutex = Mutex.new
      @dropped = 0
    end

    def push(event)
      if @queue.size >= @max_size
        @mutex.synchronize { @dropped += 1 }
        return false
      end
      @queue.push(event)
      true
    end

    def push_many(events)
      events.each { |e| push(e) }
    end

    def drain(max: 100)
      events = []
      max.times do
        break if @queue.empty?
        begin
          events << @queue.pop(true)
        rescue ThreadError
          break
        end
      end
      events
    end

    def size
      @queue.size
    end

    def empty?
      @queue.empty?
    end

    def dropped_count
      @mutex.synchronize { @dropped }
    end

    def reset_dropped!
      @mutex.synchronize { @dropped = 0 }
    end
  end
end

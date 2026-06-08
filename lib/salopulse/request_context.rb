require "securerandom"

module Salopulse
  module RequestContext
    KEY = :salopulse_request_context
    SUPPRESS_KEY = :salopulse_suppressed

    module_function

    def start(endpoint:, http_method:, source: :http, request_id: nil, parent_request_id: nil)
      Thread.current[KEY] = {
        request_id: request_id || SecureRandom.uuid,
        parent_request_id: parent_request_id,
        endpoint: endpoint,
        http_method: http_method,
        source: source,
        sql_events: [],
        sql_fingerprint_counts: Hash.new(0),
        started_at: monotonic_now,
        user: nil,
        tags: {},
        suppressed: false
      }
    end

    def current
      Thread.current[KEY]
    end

    def active?
      !current.nil?
    end

    def clear
      Thread.current[KEY] = nil
    end

    def set_user(attrs)
      current[:user] = attrs if current
    end

    def set_tag(key, value)
      current[:tags][key] = value if current
    end

    def record_sql_event(event, fingerprint)
      ctx = current
      return false unless ctx
      ctx[:sql_events] << [event, fingerprint]
      ctx[:sql_fingerprint_counts][fingerprint] += 1
      true
    end

    def elapsed_ms
      return 0 unless current
      ((monotonic_now - current[:started_at]) * 1000).to_i
    end

    def suppressed?
      Thread.current[SUPPRESS_KEY] == true
    end

    def with_suppression
      previous_ctx = Thread.current[KEY]
      previous_suppress = Thread.current[SUPPRESS_KEY]
      Thread.current[KEY] = nil
      Thread.current[SUPPRESS_KEY] = true
      yield
    ensure
      Thread.current[KEY] = previous_ctx
      Thread.current[SUPPRESS_KEY] = previous_suppress
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

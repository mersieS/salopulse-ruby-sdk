require_relative "../request_context"

module Salopulse
  module Instrumentation
    class SidekiqClientMiddleware
      PARENT_REQUEST_ID_KEY = "salopulse_parent_request_id".freeze

      def call(_worker_class, job, _queue, _redis_pool)
        ctx = Salopulse::RequestContext.current
        job[PARENT_REQUEST_ID_KEY] = ctx[:request_id] if ctx && !job.key?(PARENT_REQUEST_ID_KEY)
        yield
      end
    end
  end
end

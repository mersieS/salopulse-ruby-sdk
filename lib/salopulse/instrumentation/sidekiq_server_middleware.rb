require_relative "../request_context"

module Salopulse
  module Instrumentation
    class SidekiqServerMiddleware
      PARENT_REQUEST_ID_KEY = "salopulse_parent_request_id".freeze

      def initialize(client = Salopulse::Client.instance)
        @client = client
      end

      def call(worker, job, _queue)
        return yield if @client.disabled?

        endpoint = derive_endpoint(worker, job)
        parent_request_id = job[PARENT_REQUEST_ID_KEY]
        Salopulse::RequestContext.start(
          endpoint: endpoint,
          http_method: "JOB",
          source: :sidekiq,
          parent_request_id: parent_request_id
        )

        status = 200
        begin
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          status = 500
          @client.capture_exception(e)
          raise
        ensure
          begin
            @client.capture_performance(
              endpoint: endpoint,
              http_method: "JOB",
              duration_ms: Salopulse::RequestContext.elapsed_ms,
              status_code: status
            )
            @client.flush_request_scope_events
          rescue StandardError
          end
          Salopulse::RequestContext.clear
        end
      end

      private

      def derive_endpoint(worker, job)
        wrapped = job["wrapped"] || job["class"]
        return wrapped.to_s if wrapped && !wrapped.to_s.empty?

        worker.class.name.to_s
      end
    end
  end
end

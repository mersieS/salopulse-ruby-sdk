require_relative "../request_context"
require_relative "../sanitizer"

module Salopulse
  module Instrumentation
    class RackMiddleware
      def initialize(app, client = Salopulse::Client.instance)
        @app = app
        @client = client
      end

      def call(env)
        return @app.call(env) if @client.disabled?

        endpoint = derive_endpoint(env)
        http_method = env["REQUEST_METHOD"]
        Salopulse::RequestContext.start(endpoint: endpoint, http_method: http_method)

        status = 500
        begin
          status, headers, body = @app.call(env)
          [status, headers, body]
        rescue Exception => e # rubocop:disable Lint/RescueException
          @client.capture_exception(e, environment_data: env_snapshot(env))
          raise
        ensure
          begin
            @client.capture_performance(
              endpoint: endpoint,
              http_method: http_method,
              duration_ms: Salopulse::RequestContext.elapsed_ms,
              status_code: status
            )
            @client.flush_request_scope_events
          rescue StandardError
            # never let SDK errors propagate
          end
          Salopulse::RequestContext.clear
        end
      end

      private

      def derive_endpoint(env)
        if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
          begin
            route = Rails.application.routes.recognize_path(env["PATH_INFO"], method: env["REQUEST_METHOD"])
            return "#{route[:controller]}##{route[:action]}" if route
          rescue StandardError
          end
        end
        env["PATH_INFO"]
      end

      def env_snapshot(env)
        params = env["action_dispatch.request.parameters"] || env["rack.request.form_hash"] || {}
        headers = env.each_with_object({}) do |(k, v), acc|
          next unless k.is_a?(String) && k.start_with?("HTTP_")
          acc[k.sub(/^HTTP_/, "").split("_").map(&:capitalize).join("-")] = v
        end
        {
          "ip" => env["REMOTE_ADDR"],
          "params" => Salopulse::Sanitizer.scrub_hash(params),
          "headers" => Salopulse::Sanitizer.scrub_headers(headers)
        }
      end
    end
  end
end

require_relative "sidekiq_server_middleware"
require_relative "sidekiq_client_middleware"

module Salopulse
  module Instrumentation
    module Sidekiq
      module_function

      def install!
        return false unless defined?(::Sidekiq)

        ::Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add(Salopulse::Instrumentation::SidekiqServerMiddleware) unless chain.exists?(Salopulse::Instrumentation::SidekiqServerMiddleware)
          end
          config.client_middleware do |chain|
            chain.add(Salopulse::Instrumentation::SidekiqClientMiddleware) unless chain.exists?(Salopulse::Instrumentation::SidekiqClientMiddleware)
          end
        end

        ::Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add(Salopulse::Instrumentation::SidekiqClientMiddleware) unless chain.exists?(Salopulse::Instrumentation::SidekiqClientMiddleware)
          end
        end

        true
      end
    end
  end
end

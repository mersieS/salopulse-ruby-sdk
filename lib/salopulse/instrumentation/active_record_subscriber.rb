module Salopulse
  module Instrumentation
    class ActiveRecordSubscriber
      INTERNAL_NAMES = %w[SCHEMA TRANSACTION].freeze

      def self.subscribe(client)
        require "active_support/notifications"
        @subscriber ||= ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          next if internal?(event)
          next if Salopulse::RequestContext.suppressed?

          client.capture_sql(
            query: event.payload[:sql],
            duration_ms: event.duration,
            rows_returned: event.payload[:row_count]
          )
        end
      end

      def self.unsubscribe
        return unless @subscriber
        require "active_support/notifications"
        ActiveSupport::Notifications.unsubscribe(@subscriber)
        @subscriber = nil
      end

      def self.internal?(event)
        name = event.payload[:name].to_s
        return true if INTERNAL_NAMES.include?(name)
        return true if event.payload[:cached]
        sql = event.payload[:sql].to_s
        sql.start_with?("SHOW ", "EXPLAIN ", "PRAGMA ")
      end
    end
  end
end

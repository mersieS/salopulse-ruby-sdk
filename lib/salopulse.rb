require_relative "salopulse/version"
require_relative "salopulse/error/base"
require_relative "salopulse/error/invalid_dsn"
require_relative "salopulse/configuration"
require_relative "salopulse/dsn"
require_relative "salopulse/buffer"
require_relative "salopulse/sanitizer"
require_relative "salopulse/local_fingerprint"
require_relative "salopulse/request_context"
require_relative "salopulse/stack_frame_builder"
require_relative "salopulse/transport"
require_relative "salopulse/flusher"
require_relative "salopulse/client"
require_relative "salopulse/instrumentation/active_record_subscriber"
require_relative "salopulse/instrumentation/rack_middleware"

module Salopulse
  class << self
    def init(**options)
      Client.instance.init(options)
    end

    def capture_exception(error, **opts)
      Client.instance.capture_exception(error, **opts)
    end

    def capture_message(message, level: :info)
      Client.instance.capture_message(message, level: level)
    end

    def flush(timeout: 5)
      Client.instance.flush(timeout: timeout)
    end

    def close
      Client.instance.close
    end

    def set_user(attrs)
      Client.instance.set_user(attrs)
    end

    def set_tag(key, value)
      Client.instance.set_tag(key, value)
    end

    def disabled?
      Client.instance.disabled?
    end

    def configuration
      Client.instance.configuration
    end
  end
end

require_relative "salopulse/railtie" if defined?(Rails::Railtie)

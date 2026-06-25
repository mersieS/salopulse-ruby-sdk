require "time"
require "socket"
require "singleton"
require_relative "version"
require_relative "configuration"
require_relative "dsn"
require_relative "buffer"
require_relative "transport"
require_relative "flusher"
require_relative "sanitizer"
require_relative "local_fingerprint"
require_relative "request_context"
require_relative "stack_frame_builder"

module Salopulse
  class Client
    include Singleton

    attr_reader :configuration, :buffer, :transport, :flusher, :dsn

    def initialize
      @initialized = false
      @mutex = Mutex.new
      @pid = nil
    end

    def init(options = {})
      @mutex.synchronize do
        if @initialized
          build_runtime!(reset_buffer: forked_process?) unless runtime_ready?
          return self
        end

        @configuration = Configuration.new
        options.each { |k, v| @configuration.public_send("#{k}=", v) if @configuration.respond_to?("#{k}=") }

        return self unless @configuration.enabled

        @dsn = DSN.new(@configuration.dsn)
        build_runtime!(reset_buffer: true)

        install_at_exit_hook

        @initialized = true
        announce_deploy!
        self
      end
    end

    def initialized?
      @initialized
    end

    def uninitialized?
      !@initialized
    end

    def disabled?
      !@initialized || !@configuration&.enabled
    end


    def capture_sql(query:, duration_ms:, rows_returned: nil)
      return if disabled?
      return if RequestContext.suppressed?
      return unless sample?

      ctx = RequestContext.current
      fingerprint = LocalFingerprint.for(query)

      event = build_event(
        type: "sql",
        data: {
          "query" => query,
          "duration_ms" => duration_ms.to_i,
          "endpoint" => ctx&.dig(:endpoint),
          "http_method" => ctx&.dig(:http_method),
          "rows_returned" => rows_returned,
          "n1_detected" => false
        }.compact,
        ctx: ctx,
        extra_envelope: { "database_dialect" => detect_dialect }
      )

      if ctx
        RequestContext.record_sql_event(event, fingerprint)
      else
        enqueue(event)
      end
    end

    def capture_exception(error, user_context: nil, environment_data: nil)
      return if disabled?
      return unless sample?

      ctx = RequestContext.current
      backtrace = Array(error.backtrace)
      data = {
        "error_class" => error.class.name,
        "message" => error.message.to_s,
        "stack_trace" => backtrace.join("\n"),
        "stack_frames" => StackFrameBuilder.call(backtrace, app_root: configuration&.app_root),
        "endpoint" => ctx&.dig(:endpoint),
        "http_method" => ctx&.dig(:http_method)
      }
      user = user_context || ctx&.dig(:user)
      data["user_context"] = Sanitizer.scrub_hash(user) if user
      data["environment_data"] = Sanitizer.scrub_hash(environment_data) if environment_data

      enqueue(build_event(type: "error", data: data.compact, ctx: ctx))
    end

    def capture_message(message, level: :info)
      return if disabled?
      return unless sample?

      ctx = RequestContext.current
      data = {
        "error_class" => "Salopulse::Message",
        "message" => message.to_s,
        "stack_trace" => "",
        "endpoint" => ctx&.dig(:endpoint),
        "http_method" => ctx&.dig(:http_method),
        "level" => level.to_s
      }.compact
      enqueue(build_event(type: "error", data: data, ctx: ctx))
    end

    def capture_performance(endpoint:, http_method:, duration_ms:, status_code:, cpu_usage: nil, memory_usage: nil,
                            ip: nil, request_headers: nil, request_params: nil)
      return if disabled?
      return unless sample?

      ctx = RequestContext.current
      data = {
        "endpoint" => endpoint,
        "http_method" => http_method,
        "duration_ms" => duration_ms.to_i,
        "status_code" => status_code.to_i
      }
      data["cpu_usage"] = cpu_usage if cpu_usage
      data["memory_usage"] = memory_usage if memory_usage
      data["ip"] = ip if ip
      data["request_headers"] = request_headers if request_headers
      data["request_params"] = request_params if request_params
      data["span_count"] = ctx[:sql_events].length + 1 if ctx

      enqueue(build_event(type: "performance", data: data, ctx: ctx))
    end


    def flush_request_scope_events
      ctx = RequestContext.current
      return unless ctx

      threshold = @configuration.n1_threshold
      counts = ctx[:sql_fingerprint_counts]

      ctx[:sql_events].each do |event, fingerprint|
        if counts[fingerprint] >= threshold
          event[:data]["n1_detected"] = true
        end
        enqueue(event)
      end
    end


    def set_user(attrs)
      RequestContext.set_user(attrs)
    end

    def set_tag(key, value)
      RequestContext.set_tag(key, value)
    end


    def flush(timeout: 5)
      return 0 if disabled?
      ensure_runtime_ready!
      @flusher.flush_all(timeout: timeout)
    end

    def close
      return unless @initialized
      ensure_runtime_ready!
      @flusher&.stop(timeout: 5)
      @pid = nil
      @initialized = false
    end

    def reset!
      close if @initialized
      @configuration = nil
      @buffer = nil
      @transport = nil
      @flusher = nil
      @dsn = nil
      @pid = nil
      @initialized = false
      @deploy_announced = false
    end

    private

    KNOWN_RELEASE_META = %w[sha deployed_by previous_release].freeze

    def announce_deploy!
      return if @deploy_announced
      return unless @configuration&.deploys
      return if @configuration.release.to_s.empty?

      meta = (@configuration.release_metadata || {}).each_with_object({}) { |(k, v), h| h[k.to_s] = v }
      extras = meta.reject { |k, _| KNOWN_RELEASE_META.include?(k) }

      data = {
        "release"          => @configuration.release,
        "deployed_at"      => Time.now.utc.iso8601(3),
        "runtime"          => "ruby #{RUBY_VERSION}",
        "framework"        => detect_framework,
        "host"             => detect_host,
        "sha"              => meta["sha"],
        "deployed_by"      => meta["deployed_by"],
        "previous_release" => meta["previous_release"],
        "metadata"         => extras.empty? ? nil : extras
      }.compact

      enqueue(build_event(type: "deploy", data: data, ctx: nil))
      @deploy_announced = true
    rescue StandardError => e
      @configuration&.logger&.warn("[Salopulse] deploy announce failed: #{e.class}: #{e.message}")
    end

    def detect_framework
      return "rails #{Rails::VERSION::STRING}" if defined?(Rails) && defined?(Rails::VERSION)
      nil
    end

    def detect_host
      Socket.gethostname
    rescue StandardError
      nil
    end

    def enqueue(event)
      return false unless ensure_runtime_ready!
      return false unless @buffer
      if @configuration.before_send
        event = @configuration.before_send.call(event)
        return false if event.nil?
      end
      @buffer.push(event)
    end

    def build_event(type:, data:, ctx:, extra_envelope: {})
      envelope = {
        "request_id" => ctx&.dig(:request_id),
        "release" => @configuration.release,
        "service" => @configuration.service_name,
        "sdk" => { "version" => Salopulse::VERSION, "platform" => "ruby" },
        "timestamp" => Time.now.utc.iso8601(3)
      }.merge(extra_envelope).compact

      { type: type, data: data, envelope: envelope }
    end

    def sample?
      rate = @configuration.sample_rate.to_f
      return true if rate >= 1.0
      return false if rate <= 0.0
      rand < rate
    end

    def ensure_runtime_ready!
      return false if !@initialized || !@configuration&.enabled
      return true if runtime_ready?

      @mutex.synchronize do
        return false if !@initialized || !@configuration&.enabled
        return true if runtime_ready?

        build_runtime!(reset_buffer: forked_process?)
      end
      true
    end

    def build_runtime!(reset_buffer:)
      @buffer = Buffer.new(max_size: @configuration.max_buffer_size) if reset_buffer || @buffer.nil?
      @transport = Transport.new(
        dsn: @dsn,
        sdk_version: Salopulse::VERSION,
        logger: @configuration.logger
      )
      @flusher = Flusher.new(
        buffer: @buffer,
        transport: @transport,
        interval: @configuration.flush_interval,
        batch_size: @configuration.flush_batch_size,
        logger: @configuration.logger
      )
      @flusher.start
      @pid = Process.pid
    end

    def runtime_ready?
      @pid == Process.pid && @flusher&.alive?
    end

    def forked_process?
      !@pid.nil? && @pid != Process.pid
    end

    def detect_dialect
      return "unknown" unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
      adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
      case adapter
      when /postgres/ then "postgres"
      when /mysql/    then "mysql"
      when /sqlite/   then "sqlite"
      when /sqlserver|mssql/ then "mssql"
      else "unknown"
      end
    rescue StandardError
      "unknown"
    end

    def install_at_exit_hook
      return if @at_exit_installed
      @at_exit_installed = true
      at_exit { close rescue nil }
    end
  end
end

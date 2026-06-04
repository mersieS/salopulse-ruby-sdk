require "net/http"
require "json"
require "uri"
require_relative "request_context"

module Salopulse
  class Transport
    MAX_RETRIES = 3
    BACKOFF_BASE = 0.5

    Response = Struct.new(:code, :body, keyword_init: true)

    def initialize(dsn:, sdk_version:, logger:, open_timeout: 5, read_timeout: 10)
      @dsn = dsn
      @sdk_version = sdk_version
      @logger = logger
      @uri = URI.parse(dsn.ingest_url)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def send_batch(events)
      return true if events.nil? || events.empty?

      body = JSON.dump(events: events)

      RequestContext.with_suppression do
        attempt = 0
        loop do
          response = post(body)
          code = response.code.to_i
          return true if success?(code)
          return false if non_retryable?(code)

          attempt += 1
          if attempt >= MAX_RETRIES
            @logger.warn("[Salopulse] giving up after #{attempt} attempts, last code=#{code}")
            return false
          end
          sleep(BACKOFF_BASE * (2**(attempt - 1)))
        end
      end
    end

    private

    def post(body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = (@uri.scheme == "https")
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      request = Net::HTTP::Post.new(@uri.request_uri)
      request["Content-Type"] = "application/json"
      request["X-Api-Key"] = @dsn.api_key
      request["User-Agent"] = "salopulse-ruby/#{@sdk_version}"
      request.body = body

      http.request(request)
    rescue StandardError => e
      @logger.warn("[Salopulse] transport error: #{e.class}: #{e.message}")
      Response.new(code: "0", body: nil)
    end

    def success?(code)
      code == 202
    end

    def non_retryable?(code)
      code >= 400 && code < 500 && code != 429
    end
  end
end

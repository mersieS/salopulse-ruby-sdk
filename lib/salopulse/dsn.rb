require "uri"
require_relative "error/invalid_dsn"

module Salopulse
  class DSN
    attr_reader :api_key, :ingest_url, :host, :scheme

    def initialize(dsn_string)
      raise Salopulse::Error::InvalidDSN, "DSN boş" if dsn_string.nil? || dsn_string.to_s.empty?

      uri =
        begin
          URI.parse(dsn_string)
        rescue URI::InvalidURIError
          raise Salopulse::Error::InvalidDSN, "geçersiz URL"
        end

      raise Salopulse::Error::InvalidDSN, "scheme http veya https olmalı" unless %w[http https].include?(uri.scheme)
      raise Salopulse::Error::InvalidDSN, "api_key eksik" if uri.userinfo.nil? || uri.userinfo.empty?
      raise Salopulse::Error::InvalidDSN, "host eksik" if uri.host.nil? || uri.host.empty?

      @scheme = uri.scheme
      @api_key = uri.userinfo
      @host = uri.host

      default_port = uri.scheme == "https" ? 443 : 80
      port_part = (uri.port && uri.port != default_port) ? ":#{uri.port}" : ""
      @ingest_url = "#{uri.scheme}://#{uri.host}#{port_part}/api/v1/ingest"
    end
  end
end

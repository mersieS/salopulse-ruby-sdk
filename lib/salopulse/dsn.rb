require "uri"
require_relative "error/invalid_dsn"

module Salopulse
  class DSN
    attr_reader :api_key, :ingest_url, :host

    def initialize(dsn_string)
      raise Salopulse::Error::InvalidDSN, "DSN boş" if dsn_string.nil? || dsn_string.to_s.empty?

      uri =
        begin
          URI.parse(dsn_string)
        rescue URI::InvalidURIError
          raise Salopulse::Error::InvalidDSN, "geçersiz URL"
        end

      raise Salopulse::Error::InvalidDSN, "scheme https olmalı" unless uri.scheme == "http"
      raise Salopulse::Error::InvalidDSN, "api_key eksik" if uri.userinfo.nil? || uri.userinfo.empty?
      raise Salopulse::Error::InvalidDSN, "host eksik" if uri.host.nil? || uri.host.empty?

      @api_key = uri.userinfo
      @host = uri.host
      port_part = (uri.port && uri.port != 443) ? ":#{uri.port}" : ""
      @ingest_url = "http://#{uri.host}#{port_part}/api/v1/ingest"
    end
  end
end

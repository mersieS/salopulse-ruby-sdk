module Salopulse
  module Sanitizer
    SENSITIVE_KEYS = %w[
      password password_confirmation token api_key secret
      access_token refresh_token authorization cookie
      credit_card card_number cvv ssn
    ].freeze

    SENSITIVE_HEADERS = %w[
      authorization cookie x-api-key x-auth-token
    ].freeze

    FILTERED = "[FILTERED]".freeze

    module_function

    def scrub_hash(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), acc|
          acc[k] = sensitive_key?(k) ? FILTERED : scrub_hash(v)
        end
      when Array
        value.map { |v| scrub_hash(v) }
      else
        value
      end
    end

    def scrub_headers(headers)
      return {} unless headers.respond_to?(:each_pair) || headers.is_a?(Hash)
      headers.to_h.each_with_object({}) do |(k, v), acc|
        acc[k] = SENSITIVE_HEADERS.include?(k.to_s.downcase) ? FILTERED : v
      end
    end

    def sensitive_key?(key)
      SENSITIVE_KEYS.include?(key.to_s.downcase)
    end
  end
end

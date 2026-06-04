require "webmock/rspec"
require "salopulse"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.before(:each) do
    Salopulse::Client.instance.reset!
  end
  config.after(:each) do
    Salopulse::Client.instance.reset!
    Salopulse::RequestContext.clear
  end
end

VALID_DSN = "https://sp_test_abc123@ingest.example.com".freeze
INGEST_URL = "https://ingest.example.com/api/v1/ingest".freeze

require "spec_helper"

RSpec.describe Salopulse::Transport do
  let(:dsn) { Salopulse::DSN.new(VALID_DSN) }
  let(:logger) { Logger.new(IO::NULL) }
  subject(:transport) { described_class.new(dsn: dsn, sdk_version: "0.1.0", logger: logger) }

  before { stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0) }

  it "returns true on 202 with correct headers" do
    stub = stub_request(:post, INGEST_URL)
      .with(
        headers: { "X-Api-Key" => "sp_test_abc123", "Content-Type" => "application/json" },
        body: hash_including("events" => [{ "type" => "sql" }])
      )
      .to_return(status: 202, body: '{"accepted":1}')
    expect(transport.send_batch([{ "type" => "sql" }])).to be(true)
    expect(stub).to have_been_requested
  end

  it "does not retry 4xx (non-429)" do
    stub = stub_request(:post, INGEST_URL).to_return(status: 401)
    expect(transport.send_batch([{}])).to be(false)
    expect(stub).to have_been_requested.once
  end

  it "retries on 429" do
    stub = stub_request(:post, INGEST_URL)
      .to_return({ status: 429 }, { status: 429 }, { status: 202 })
    expect(transport.send_batch([{}])).to be(true)
    expect(stub).to have_been_requested.times(3)
  end

  it "retries on 5xx up to MAX_RETRIES and returns false" do
    stub = stub_request(:post, INGEST_URL).to_return(status: 500)
    expect(transport.send_batch([{}])).to be(false)
    expect(stub).to have_been_requested.times(Salopulse::Transport::MAX_RETRIES)
  end

  it "treats network errors as retryable" do
    stub = stub_request(:post, INGEST_URL).to_raise(Errno::ECONNREFUSED)
    expect(transport.send_batch([{}])).to be(false)
    expect(stub).to have_been_requested.times(Salopulse::Transport::MAX_RETRIES)
  end

  it "returns true and skips request for empty events" do
    expect(transport.send_batch([])).to be(true)
  end

  it "sends User-Agent with version" do
    stub = stub_request(:post, INGEST_URL)
      .with(headers: { "User-Agent" => "salopulse-ruby/0.1.0" })
      .to_return(status: 202)
    transport.send_batch([{}])
    expect(stub).to have_been_requested
  end
end

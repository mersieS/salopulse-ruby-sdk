require "spec_helper"

RSpec.describe Salopulse::Client do
  let(:client) { described_class.instance }

  before { stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0) }
  before { stub_request(:post, INGEST_URL).to_return(status: 202) }

  it "raises on invalid DSN" do
    expect { client.init(dsn: "bogus") }.to raise_error(Salopulse::Error::InvalidDSN)
  end

  it "init is idempotent" do
    client.init(dsn: VALID_DSN)
    first_buffer = client.buffer
    client.init(dsn: VALID_DSN)
    expect(client.buffer).to be(first_buffer)
  end

  it "rebuilds runtime after a forked process changes pid" do
    current_pid = 10_001
    allow(Process).to receive(:pid) { current_pid }

    client.init(dsn: VALID_DSN, flush_interval: 0.1, flush_batch_size: 10)
    parent_buffer = client.buffer

    current_pid = 10_002

    client.capture_message("hello from child")

    expect(client.buffer).not_to be(parent_buffer)
    expect(client.flusher.alive?).to be(true)

    client.flush(timeout: 2)
    expect(WebMock).to have_requested(:post, INGEST_URL).at_least_once
  end

  it "no-ops when enabled: false" do
    client.init(dsn: VALID_DSN, enabled: false)
    expect(client.disabled?).to be(true)
    client.capture_message("hi")
    expect(client.buffer).to be_nil
  end

  it "sends a manual capture_message end-to-end" do
    client.init(dsn: VALID_DSN, flush_interval: 0.1, flush_batch_size: 10)
    client.capture_message("hello")
    client.flush(timeout: 2)
    expect(WebMock).to have_requested(:post, INGEST_URL).at_least_once
  end

  it "captures exceptions with sanitized environment_data" do
    client.init(dsn: VALID_DSN)
    err = begin; raise StandardError, "boom"; rescue => e; e; end
    captured = nil
    client.configuration.before_send = ->(e) { captured = e; e }
    client.capture_exception(err, environment_data: { "password" => "x", "ip" => "1.2.3.4" })
    expect(captured[:data]["environment_data"]["password"]).to eq("[FILTERED]")
    expect(captured[:data]["environment_data"]["ip"]).to eq("1.2.3.4")
    expect(captured[:data]["error_class"]).to eq("StandardError")
  end

  it "before_send returning nil drops the event" do
    client.init(dsn: VALID_DSN, before_send: ->(_e) { nil })
    client.capture_message("drop me")
    expect(client.buffer.size).to eq(0)
  end

  it "sample_rate=0 drops all events" do
    client.init(dsn: VALID_DSN, sample_rate: 0.0)
    client.capture_message("nope")
    expect(client.buffer.size).to eq(0)
  end

  it "N+1: flush_request_scope_events marks repeated SQL with n1_detected" do
    client.init(dsn: VALID_DSN, n1_threshold: 3)
    Salopulse::RequestContext.start(endpoint: "/orders", http_method: "GET")
    5.times { |i| client.capture_sql(query: "SELECT * FROM items WHERE id = #{i}", duration_ms: 1) }
    client.capture_sql(query: "SELECT * FROM orders WHERE id = 1", duration_ms: 1)
    expect(client.buffer.size).to eq(0) # buffered in request scope
    client.flush_request_scope_events
    drained = client.buffer.drain(max: 100)
    n1 = drained.select { |e| e[:data]["query"].include?("items") }
    other = drained.find { |e| e[:data]["query"].include?("orders") }
    expect(n1.size).to eq(5)
    expect(n1.all? { |e| e[:data]["n1_detected"] == true }).to be(true)
    expect(other[:data]["n1_detected"]).to be(false)
    Salopulse::RequestContext.clear
  end

  it "SQL events get database_dialect envelope (unknown without AR)" do
    client.init(dsn: VALID_DSN)
    Salopulse::RequestContext.start(endpoint: "/", http_method: "GET")
    client.capture_sql(query: "SELECT 1", duration_ms: 1)
    client.flush_request_scope_events
    event = client.buffer.drain(max: 10).first
    expect(event[:envelope]["database_dialect"]).to eq("unknown")
    expect(event[:envelope]["sdk"]).to eq({ "version" => Salopulse::VERSION, "platform" => "ruby" })
    Salopulse::RequestContext.clear
  end
end

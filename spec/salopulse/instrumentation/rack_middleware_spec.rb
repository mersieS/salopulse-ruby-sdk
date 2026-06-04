require "spec_helper"

RSpec.describe Salopulse::Instrumentation::RackMiddleware do
  let(:client) { Salopulse::Client.instance }

  before do
    stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0)
    stub_request(:post, INGEST_URL).to_return(status: 202)
    client.init(dsn: VALID_DSN)
  end

  def env_for(path: "/x", method: "GET")
    { "PATH_INFO" => path, "REQUEST_METHOD" => method, "REMOTE_ADDR" => "1.2.3.4" }
  end

  it "starts and clears request context" do
    inner = ->(_e) do
      expect(Salopulse::RequestContext.current).not_to be_nil
      [200, {}, ["ok"]]
    end
    described_class.new(inner, client).call(env_for)
    expect(Salopulse::RequestContext.current).to be_nil
  end

  it "captures a performance event for the request" do
    inner = ->(_e) { [200, {}, ["ok"]] }
    described_class.new(inner, client).call(env_for)
    perf = client.buffer.drain(max: 100).find { |e| e[:type] == "performance" }
    expect(perf).not_to be_nil
    expect(perf[:data]["status_code"]).to eq(200)
    expect(perf[:data]["http_method"]).to eq("GET")
  end

  it "captures exceptions and re-raises" do
    inner = ->(_e) { raise StandardError, "boom" }
    mw = described_class.new(inner, client)
    expect { mw.call(env_for) }.to raise_error(StandardError, "boom")
    events = client.buffer.drain(max: 100)
    expect(events.any? { |e| e[:type] == "error" }).to be(true)
  end

  it "uses one request_id for all events in a request" do
    inner = ->(_e) do
      client.capture_message("inside")
      [200, {}, ["ok"]]
    end
    described_class.new(inner, client).call(env_for)
    events = client.buffer.drain(max: 100)
    ids = events.map { |e| e[:envelope]["request_id"] }.compact.uniq
    expect(ids.size).to eq(1)
  end
end

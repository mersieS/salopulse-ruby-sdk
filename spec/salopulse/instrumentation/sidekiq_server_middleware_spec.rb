require "spec_helper"
require "salopulse/instrumentation/sidekiq_server_middleware"

RSpec.describe Salopulse::Instrumentation::SidekiqServerMiddleware do
  let(:client) { Salopulse::Client.instance }
  let(:worker) { Class.new { def self.name; "Foo::BarJob"; end }.new }

  before do
    stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0)
    stub_request(:post, INGEST_URL).to_return(status: 202)
    client.init(dsn: VALID_DSN)
  end

  def job_hash(extra = {})
    { "class" => "Foo::BarJob", "args" => [] }.merge(extra)
  end

  it "starts and clears request context around the job" do
    seen = nil
    described_class.new(client).call(worker, job_hash, "default") do
      seen = Salopulse::RequestContext.current
    end
    expect(seen).not_to be_nil
    expect(seen[:endpoint]).to eq("Foo::BarJob")
    expect(seen[:http_method]).to eq("JOB")
    expect(seen[:source]).to eq(:sidekiq)
    expect(Salopulse::RequestContext.current).to be_nil
  end

  it "captures a performance event with status_code 200 on success" do
    described_class.new(client).call(worker, job_hash, "default") { :ok }
    perf = client.buffer.drain(max: 100).find { |e| e[:type] == "performance" }
    expect(perf).not_to be_nil
    expect(perf[:data]["endpoint"]).to eq("Foo::BarJob")
    expect(perf[:data]["http_method"]).to eq("JOB")
    expect(perf[:data]["status_code"]).to eq(200)
  end

  it "captures exception, re-raises, and reports status_code 500" do
    mw = described_class.new(client)
    expect {
      mw.call(worker, job_hash, "default") { raise StandardError, "boom" }
    }.to raise_error(StandardError, "boom")

    events = client.buffer.drain(max: 100)
    expect(events.any? { |e| e[:type] == "error" }).to be(true)
    perf = events.find { |e| e[:type] == "performance" }
    expect(perf[:data]["status_code"]).to eq(500)
  end

  it "uses the wrapped ActiveJob class name when present" do
    job = job_hash(
      "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
      "wrapped" => "Mailer::DeliveryJob"
    )
    described_class.new(client).call(worker, job, "default") { :ok }
    perf = client.buffer.drain(max: 100).find { |e| e[:type] == "performance" }
    expect(perf[:data]["endpoint"]).to eq("Mailer::DeliveryJob")
  end

  it "adopts parent_request_id from job payload" do
    parent = "00000000-0000-0000-0000-000000000abc"
    job = job_hash("salopulse_parent_request_id" => parent)

    seen = nil
    described_class.new(client).call(worker, job, "default") do
      seen = Salopulse::RequestContext.current
    end
    expect(seen[:parent_request_id]).to eq(parent)
  end

  it "shares one request_id across all events in the job" do
    described_class.new(client).call(worker, job_hash, "default") do
      client.capture_message("inside job")
    end
    ids = client.buffer.drain(max: 100).map { |e| e[:envelope]["request_id"] }.compact.uniq
    expect(ids.size).to eq(1)
  end
end

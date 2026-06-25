require "spec_helper"
require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"

RSpec.describe Salopulse::Instrumentation::ActiveRecordSubscriber do
  let(:client) { Salopulse::Client.instance }

  before do
    stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0)
    stub_request(:post, INGEST_URL).to_return(status: 202)
    client.init(dsn: VALID_DSN)
    described_class.subscribe(client)
  end

  after { described_class.unsubscribe }

  def emit(sql:, name: "User Load", duration: 0.005, cached: false, row_count: 1)
    ActiveSupport::Notifications.instrument(
      "sql.active_record",
      sql: sql, name: name, cached: cached, row_count: row_count
    ) { sleep duration }
  end

  it "captures normal queries" do
    Salopulse::RequestContext.start(endpoint: "/", http_method: "GET")
    emit(sql: "SELECT * FROM users WHERE id = 1")
    client.flush_request_scope_events
    events = client.buffer.drain(max: 10)
    expect(events.size).to eq(1)
    expect(events.first[:type]).to eq("sql")
    Salopulse::RequestContext.clear
  end

  it "skips SCHEMA / TRANSACTION / cached / SHOW queries" do
    Salopulse::RequestContext.start(endpoint: "/", http_method: "GET")
    emit(sql: "SELECT 1", name: "SCHEMA")
    emit(sql: "BEGIN", name: "TRANSACTION")
    emit(sql: "SELECT * FROM x", cached: true)
    emit(sql: "SHOW TABLES")
    client.flush_request_scope_events
    expect(client.buffer.size).to eq(0)
    Salopulse::RequestContext.clear
  end

  it "ignores queries while transport is suppressed" do
    Salopulse::RequestContext.start(endpoint: "/", http_method: "GET")
    Salopulse::RequestContext.with_suppression do
      emit(sql: "SELECT 1")
    end
    client.flush_request_scope_events
    expect(client.buffer.size).to eq(0)
    Salopulse::RequestContext.clear
  end
end

require "spec_helper"

RSpec.describe Salopulse::RequestContext do
  after { described_class.clear }

  it "isolates context across threads" do
    described_class.start(endpoint: "/main", http_method: "GET")
    main_id = described_class.current[:request_id]

    other_id = nil
    Thread.new do
      expect(described_class.current).to be_nil
      described_class.start(endpoint: "/other", http_method: "POST")
      other_id = described_class.current[:request_id]
      described_class.clear
    end.join

    expect(described_class.current[:request_id]).to eq(main_id)
    expect(other_id).not_to eq(main_id)
  end

  it "generates unique request_ids" do
    ids = 100.times.map do
      described_class.start(endpoint: "/", http_method: "GET")
      id = described_class.current[:request_id]
      described_class.clear
      id
    end
    expect(ids.uniq.size).to eq(100)
  end

  it "with_suppression hides context for block" do
    described_class.start(endpoint: "/", http_method: "GET")
    expect(described_class.current).not_to be_nil
    described_class.with_suppression do
      expect(described_class.current).to be_nil
    end
    expect(described_class.current).not_to be_nil
  end

  it "counts SQL events per fingerprint" do
    described_class.start(endpoint: "/", http_method: "GET")
    3.times { described_class.record_sql_event({ type: "sql" }, "fp_a") }
    described_class.record_sql_event({ type: "sql" }, "fp_b")
    ctx = described_class.current
    expect(ctx[:sql_fingerprint_counts]["fp_a"]).to eq(3)
    expect(ctx[:sql_fingerprint_counts]["fp_b"]).to eq(1)
    expect(ctx[:sql_events].size).to eq(4)
  end
end

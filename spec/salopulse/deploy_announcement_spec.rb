require "spec_helper"

RSpec.describe "deploy announcement" do
  let(:client) { Salopulse::Client.instance }

  before { stub_const("Salopulse::Transport::BACKOFF_BASE", 0.0) }
  before { stub_request(:post, INGEST_URL).to_return(status: 202) }

  def init_and_capture(**opts)
    captured = []
    client.init(dsn: VALID_DSN, before_send: ->(e) { captured << e; e }, **opts)
    captured
  end

  it "emits a deploy event on init when release is set" do
    events = init_and_capture(release: "v2.18.0", environment: "production")
    expect(events.map { |e| e[:type] }).to include("deploy")
  end

  it "does not emit a deploy event when release is missing" do
    events = init_and_capture(environment: "production")
    expect(events.map { |e| e[:type] }).not_to include("deploy")
  end

  it "does not emit a deploy event when deploys: false" do
    events = init_and_capture(release: "v2.18.0", deploys: false)
    expect(events.map { |e| e[:type] }).not_to include("deploy")
  end

  it "fires only once per process even if init is called twice" do
    events = init_and_capture(release: "v2.18.0")
    client.init(dsn: VALID_DSN, release: "v2.18.0")
    expect(events.count { |e| e[:type] == "deploy" }).to eq(1)
  end

  it "splits release_metadata into known top-level fields and free-form metadata" do
    events = init_and_capture(
      release: "v2.18.0",
      release_metadata: {
        sha: "a3f8c41d",
        deployed_by: "sbuker",
        previous_release: "v2.17.4",
        branch: "main",
        pr_url: "https://example.com/pr/1"
      }
    )
    deploy = events.find { |e| e[:type] == "deploy" }

    expect(deploy[:data]["release"]).to eq("v2.18.0")
    expect(deploy[:data]["sha"]).to eq("a3f8c41d")
    expect(deploy[:data]["deployed_by"]).to eq("sbuker")
    expect(deploy[:data]["previous_release"]).to eq("v2.17.4")
    expect(deploy[:data]["metadata"]).to eq({ "branch" => "main", "pr_url" => "https://example.com/pr/1" })
    expect(deploy[:data]["runtime"]).to start_with("ruby ")
    expect(deploy[:data]["deployed_at"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "omits the metadata field when no extra keys are given" do
    events = init_and_capture(release: "v2.18.0", release_metadata: { sha: "abc" })
    deploy = events.find { |e| e[:type] == "deploy" }
    expect(deploy[:data]).not_to have_key("metadata")
  end

  it "carries sdk envelope with version and platform" do
    events = init_and_capture(release: "v2.18.0")
    deploy = events.find { |e| e[:type] == "deploy" }
    expect(deploy[:envelope]["sdk"]).to eq("version" => Salopulse::VERSION, "platform" => "ruby")
    expect(deploy[:envelope]["release"]).to eq("v2.18.0")
  end
end

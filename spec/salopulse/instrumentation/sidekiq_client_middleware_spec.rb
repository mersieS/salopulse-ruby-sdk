require "spec_helper"
require "salopulse/instrumentation/sidekiq_client_middleware"

RSpec.describe Salopulse::Instrumentation::SidekiqClientMiddleware do
  it "injects salopulse_parent_request_id from the current request context" do
    Salopulse::RequestContext.start(endpoint: "users#show", http_method: "GET")
    parent = Salopulse::RequestContext.current[:request_id]

    job = { "class" => "Foo::BarJob" }
    described_class.new.call("Foo::BarJob", job, "default", nil) { :enqueued }

    expect(job["salopulse_parent_request_id"]).to eq(parent)
  end

  it "is a no-op when there is no active request context" do
    job = { "class" => "Foo::BarJob" }
    described_class.new.call("Foo::BarJob", job, "default", nil) { :enqueued }
    expect(job).not_to have_key("salopulse_parent_request_id")
  end

  it "does not overwrite an existing parent_request_id" do
    Salopulse::RequestContext.start(endpoint: "x", http_method: "GET")
    job = { "class" => "Foo::BarJob", "salopulse_parent_request_id" => "preset" }
    described_class.new.call("Foo::BarJob", job, "default", nil) { :enqueued }
    expect(job["salopulse_parent_request_id"]).to eq("preset")
  end
end

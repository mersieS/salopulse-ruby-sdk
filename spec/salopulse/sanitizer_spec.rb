require "spec_helper"

RSpec.describe Salopulse::Sanitizer do
  it "filters sensitive top-level keys" do
    result = described_class.scrub_hash("password" => "secret", "name" => "Alice")
    expect(result["password"]).to eq("[FILTERED]")
    expect(result["name"]).to eq("Alice")
  end

  it "filters case-insensitively and by symbol" do
    result = described_class.scrub_hash(Password: "x", "API_KEY" => "y")
    expect(result[:Password]).to eq("[FILTERED]")
    expect(result["API_KEY"]).to eq("[FILTERED]")
  end

  it "filters nested hash keys" do
    result = described_class.scrub_hash("user" => { "token" => "abc", "name" => "Bob" })
    expect(result["user"]["token"]).to eq("[FILTERED]")
    expect(result["user"]["name"]).to eq("Bob")
  end

  it "filters within arrays of hashes" do
    result = described_class.scrub_hash("items" => [{ "secret" => "s", "k" => 1 }])
    expect(result["items"][0]["secret"]).to eq("[FILTERED]")
    expect(result["items"][0]["k"]).to eq(1)
  end

  it "scrubs sensitive headers" do
    result = described_class.scrub_headers("Authorization" => "Bearer x", "X-Request-Id" => "r")
    expect(result["Authorization"]).to eq("[FILTERED]")
    expect(result["X-Request-Id"]).to eq("r")
  end
end

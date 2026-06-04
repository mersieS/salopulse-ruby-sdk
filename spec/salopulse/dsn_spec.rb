require "spec_helper"

RSpec.describe Salopulse::DSN do
  it "parses a valid DSN" do
    dsn = described_class.new("https://sp_live_abc123@ingest.salopulse.com")
    expect(dsn.scheme).to eq("https")
    expect(dsn.api_key).to eq("sp_live_abc123")
    expect(dsn.host).to eq("ingest.salopulse.com")
    expect(dsn.ingest_url).to eq("https://ingest.salopulse.com/api/v1/ingest")
  end

  it "rejects nil DSN" do
    expect { described_class.new(nil) }.to raise_error(Salopulse::Error::InvalidDSN)
  end

  it "rejects empty DSN" do
    expect { described_class.new("") }.to raise_error(Salopulse::Error::InvalidDSN)
  end

  it "accepts http DSN" do
    dsn = described_class.new("http://key@localhost:3000")
    expect(dsn.scheme).to eq("http")
    expect(dsn.ingest_url).to eq("http://localhost:3000/api/v1/ingest")
  end

  it "rejects unsupported scheme" do
    expect { described_class.new("ftp://key@host.com") }.to raise_error(Salopulse::Error::InvalidDSN, /http veya https/)
  end

  it "rejects missing api_key" do
    expect { described_class.new("https://host.com") }.to raise_error(Salopulse::Error::InvalidDSN, /api_key/)
  end

  it "rejects malformed URL" do
    expect { described_class.new("not a url://") }.to raise_error(Salopulse::Error::InvalidDSN)
  end

  it "preserves non-default ports" do
    dsn = described_class.new("https://key@host.com:8443")
    expect(dsn.ingest_url).to eq("https://host.com:8443/api/v1/ingest")
  end

  it "omits default http port" do
    dsn = described_class.new("http://key@host.com:80")
    expect(dsn.ingest_url).to eq("http://host.com/api/v1/ingest")
  end
end

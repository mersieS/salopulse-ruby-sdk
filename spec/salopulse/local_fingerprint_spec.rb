require "spec_helper"

RSpec.describe Salopulse::LocalFingerprint do
  it "replaces integers with placeholders" do
    a = described_class.for("SELECT * FROM users WHERE id = 5")
    b = described_class.for("SELECT * FROM users WHERE id = 9999")
    expect(a).to eq(b)
  end

  it "replaces string literals" do
    a = described_class.for("SELECT * FROM x WHERE name = 'alice'")
    b = described_class.for("SELECT * FROM x WHERE name = 'bob'")
    expect(a).to eq(b)
  end

  it "normalizes IN clauses" do
    a = described_class.for("SELECT * FROM x WHERE id IN (1, 2, 3)")
    b = described_class.for("SELECT * FROM x WHERE id IN (7, 8)")
    expect(a).to eq(b)
  end
end

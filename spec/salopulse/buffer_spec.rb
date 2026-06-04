require "spec_helper"

RSpec.describe Salopulse::Buffer do
  it "pushes and drains events" do
    buffer = described_class.new(max_size: 100)
    10.times { |i| buffer.push({ id: i }) }
    expect(buffer.size).to eq(10)
    drained = buffer.drain(max: 5)
    expect(drained.size).to eq(5)
    expect(buffer.size).to eq(5)
  end

  it "drops events when full and tracks dropped count" do
    buffer = described_class.new(max_size: 3)
    3.times { |i| expect(buffer.push(i)).to be(true) }
    expect(buffer.push("overflow")).to be(false)
    expect(buffer.push("overflow2")).to be(false)
    expect(buffer.dropped_count).to eq(2)
  end

  it "is thread-safe under concurrent push" do
    buffer = described_class.new(max_size: 10_000)
    threads = 10.times.map do |t|
      Thread.new do
        100.times { |i| buffer.push([t, i]) }
      end
    end
    threads.each(&:join)
    expect(buffer.size).to eq(1000)
  end

  it "drain returns empty array when buffer is empty" do
    buffer = described_class.new
    expect(buffer.drain(max: 10)).to eq([])
  end
end

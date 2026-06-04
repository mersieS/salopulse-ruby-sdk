require "spec_helper"

RSpec.describe Salopulse::Flusher do
  let(:buffer) { Salopulse::Buffer.new }
  let(:transport) { instance_double(Salopulse::Transport, send_batch: true) }
  let(:logger) { Logger.new(IO::NULL) }

  subject(:flusher) do
    described_class.new(buffer: buffer, transport: transport, interval: 0.2, batch_size: 50, logger: logger)
  end

  after { flusher.stop(timeout: 1) }

  it "drains buffer in background and sends batches" do
    20.times { |i| buffer.push({ i: i }) }
    flusher.start
    sleep 0.5
    expect(transport).to have_received(:send_batch).with(satisfy { |evts| evts.size == 20 }).at_least(:once)
  end

  it "flush_all drains synchronously" do
    50.times { |i| buffer.push({ i: i }) }
    flusher.flush_all(timeout: 1)
    expect(buffer.size).to eq(0)
    expect(transport).to have_received(:send_batch).at_least(:once)
  end

  it "survives transport exceptions" do
    allow(transport).to receive(:send_batch).and_raise(StandardError, "boom")
    buffer.push({})
    flusher.start
    sleep 0.4
    expect { flusher.flush_once }.not_to raise_error
  end
end

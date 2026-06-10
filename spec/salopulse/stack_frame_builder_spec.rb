require "spec_helper"
require "tmpdir"

RSpec.describe Salopulse::StackFrameBuilder do
  let(:tmpdir) { Dir.mktmpdir("salopulse-sfb") }
  let(:app_file) { File.join(tmpdir, "app/services/charge_processor.rb") }

  before do
    FileUtils.mkdir_p(File.dirname(app_file))
    File.write(app_file, (1..20).map { |i| "line #{i}" }.join("\n") + "\n")
  end

  after { FileUtils.remove_entry(tmpdir) }

  it "returns [] for nil or empty backtrace" do
    expect(described_class.call(nil)).to eq([])
    expect(described_class.call([])).to eq([])
  end

  it "parses backtrace lines into structured frames" do
    bt = [ "#{app_file}:10:in `call'" ]

    frames = described_class.call(bt, app_root: tmpdir)
    expect(frames.size).to eq(1)
    frame = frames.first

    expect(frame["file"]).to eq("app/services/charge_processor.rb")
    expect(frame["abs_path"]).to eq(app_file)
    expect(frame["line"]).to eq(10)
    expect(frame["method"]).to eq("call")
    expect(frame["in_app"]).to be(true)
    expect(frame["package"]).to be_nil
  end

  it "attaches pre/context/post source lines for in-app frames" do
    bt = [ "#{app_file}:10:in `call'" ]

    frame = described_class.call(bt, app_root: tmpdir).first

    expect(frame["context_line"]).to eq("line 10")
    expect(frame["pre_context"]).to eq([ "line 5", "line 6", "line 7", "line 8", "line 9" ])
    expect(frame["post_context"]).to eq([ "line 11", "line 12", "line 13", "line 14", "line 15" ])
  end

  it "marks gem paths as not in_app and extracts the package name" do
    bt = [ "/usr/local/bundle/ruby/3.3.0/gems/actionpack-8.0.5/lib/action_controller/metal.rb:252:in `dispatch'" ]

    frame = described_class.call(bt, app_root: tmpdir).first

    expect(frame["in_app"]).to be(false)
    expect(frame["package"]).to eq("actionpack-8.0.5")
    expect(frame).not_to have_key("context_line")
  end

  it "skips backtrace lines that do not match the expected format" do
    bt = [ "not a valid backtrace line", "#{app_file}:5:in `boom'" ]

    frames = described_class.call(bt, app_root: tmpdir)
    expect(frames.size).to eq(1)
    expect(frames.first["line"]).to eq(5)
  end

  it "tolerates source files that cannot be read" do
    bt = [ "#{tmpdir}/missing.rb:3:in `gone'" ]

    frame = described_class.call(bt, app_root: tmpdir).first
    expect(frame["in_app"]).to be(true)
    expect(frame).not_to have_key("context_line")
  end

  it "caps the number of frames" do
    bt = Array.new(described_class::MAX_FRAMES + 10) { |i| "#{app_file}:#{(i % 19) + 1}:in `m#{i}'" }

    frames = described_class.call(bt, app_root: tmpdir)
    expect(frames.size).to eq(described_class::MAX_FRAMES)
  end
end

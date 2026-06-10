module Salopulse
  class StackFrameBuilder
    BACKTRACE_LINE = /\A(?<file>.+?):(?<line>\d+):in\s+[`'](?<method>.+?)['`]\z/
    CONTEXT_LINES = 5
    MAX_FRAMES = 50
    FRAMEWORK_MARKERS = [ "/gems/", "/rubygems/", "/bundle/" ].freeze

    SOURCE_CACHE = {}
    SOURCE_CACHE_MUTEX = Mutex.new
    SOURCE_CACHE_LIMIT = 512

    def self.call(backtrace, app_root: nil)
      new(backtrace, app_root: app_root).call
    end

    def initialize(backtrace, app_root:)
      @backtrace = Array(backtrace)
      @app_root = app_root && File.expand_path(app_root.to_s)
    end

    def call
      frames = @backtrace.first(MAX_FRAMES).filter_map { |line| build_frame(line.to_s) }
      dedupe_consecutive(frames)
    end

    private

    def dedupe_consecutive(frames)
      frames.each_with_object([]) do |frame, acc|
        previous = acc.last
        if previous && previous["abs_path"] == frame["abs_path"] && previous["line"] == frame["line"]
          acc[-1] = frame
        else
          acc << frame
        end
      end
    end

    def build_frame(raw)
      match = BACKTRACE_LINE.match(raw)
      return nil unless match

      abs_path = match[:file]
      lineno   = match[:line].to_i
      in_app   = in_app?(abs_path)

      frame = {
        "file"     => relative_file(abs_path),
        "abs_path" => abs_path,
        "line"     => lineno,
        "method"   => match[:method],
        "in_app"   => in_app,
        "package"  => detect_package(abs_path)
      }

      attach_source_context(frame, abs_path, lineno) if in_app
      frame
    end

    def in_app?(file)
      return false if FRAMEWORK_MARKERS.any? { |marker| file.include?(marker) }
      return true unless @app_root

      File.expand_path(file).start_with?(@app_root)
    end

    def detect_package(file)
      match = file.match(%r{/gems/(?<package>[^/]+)/})
      match && match[:package]
    end

    def relative_file(file)
      return file unless @app_root

      expanded = File.expand_path(file)
      return file unless expanded.start_with?(@app_root)

      expanded.sub(/\A#{Regexp.escape(@app_root)}\/?/, "")
    end

    def attach_source_context(frame, file, lineno)
      lines = read_source(file)
      return if lines.empty?

      idx = lineno - 1
      return if idx.negative? || idx >= lines.length

      pre_start = [ idx - CONTEXT_LINES, 0 ].max
      post_end  = [ idx + CONTEXT_LINES, lines.length - 1 ].min

      frame["pre_context"]  = lines[pre_start...idx].map { |l| l.to_s.chomp }
      frame["context_line"] = lines[idx].to_s.chomp
      frame["post_context"] = lines[(idx + 1)..post_end].to_a.map { |l| l.to_s.chomp }
    end

    def read_source(file)
      SOURCE_CACHE_MUTEX.synchronize do
        return SOURCE_CACHE[file] if SOURCE_CACHE.key?(file)

        SOURCE_CACHE.shift if SOURCE_CACHE.size >= SOURCE_CACHE_LIMIT
        SOURCE_CACHE[file] = begin
          File.readlines(file)
        rescue StandardError
          []
        end
      end
    end
  end
end

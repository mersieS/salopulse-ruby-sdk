# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.6.0] - 2026-06-11

### Added
- Performance events now carry request context the backend's request-trace view
  needs: client `ip`, scrubbed `request_headers` and `request_params` (reusing
  the same sanitizer as exception capture), and a `span_count` (captured SQL
  queries plus the request span).
- SQL events now carry a 1-based `sequence` recording capture order, so the
  backend can reconstruct a request's query order (a single enqueue timestamp
  is shared across the batch and can't disambiguate it).
- New `config.service_name` is emitted as `envelope["service"]` on every event.

## [0.5.1] - 2026-06-10

### Changed
- `StackFrameBuilder` now dedupes consecutive frames that share the same
  `(file, line)` pair, keeping the outer frame. Ruby 3.3+ enhanced
  backtraces emit a separate frame for the raising operator (e.g.
  `'/'`) on the same line as the calling method (e.g. `'divide_by_zero'`);
  the dashboard previously rendered two cards with identical source
  context. The kept frame's method name is the more descriptive caller

## [0.5.0] - 2026-06-10

### Added
- Deploy tracking: when `release` is configured, the SDK now emits a one-shot
  `"deploy"` event on `init` (process-scoped, idempotent on the backend by
  `(project_environment_id, release)`). Captures runtime, framework, and host
  automatically; users can enrich via the new `release_metadata` config
  (known keys `sha`, `deployed_by`, `previous_release` are promoted, everything
  else flows into a free-form metadata hash). Toggle off with `deploys: false`

## [0.4.0] - 2026-06-10

### Added
- `StackFrameBuilder` parses exception backtraces into structured frames and
  attaches `pre_context`, `context_line`, and `post_context` source lines for
  in-app frames. `capture_exception` now sends a `stack_frames` array
  alongside the existing `stack_trace` string, enabling source-snippet
  rendering in the dashboard
- `Configuration#app_root` controls which paths are treated as in-app; defaults
  to `Rails.root` when Rails is loaded and `Dir.pwd` otherwise

## [0.3.0] - 2026-06-08

### Added
- Sidekiq instrumentation with auto-install via Railtie
  - `SidekiqServerMiddleware` opens a `RequestContext` for each job
    (`endpoint: "Foo::BarJob"`, `http_method: "JOB"`, `source: :sidekiq`),
    captures exceptions, emits a `capture_performance` event with the job
    duration, and flushes request-scoped SQL events
  - `SidekiqClientMiddleware` propagates `parent_request_id` from the
    enqueueing request into the job payload so background work can be
    correlated back to the originating HTTP request
- `Salopulse::RequestContext.start` now accepts `source:`,
  `request_id:`, and `parent_request_id:` keyword arguments

## [0.2.3] - 2026-06-04

First public release of the rewritten Salopulse APM SDK. Bumped past the
legacy `salopulse` 0.1.x line on RubyGems.

### Added (since legacy 0.1.x)

### Added
- DSN parsing (`Salopulse::DSN`) with strict validation
- Thread-safe `Buffer` with drop-on-overflow
- `Transport` with retry/backoff (5xx + 429, max 3 attempts)
- Background `Flusher` thread with interval + batch_size flushing
- `RequestContext` (thread-local) for request_id correlation
- ActiveRecord SQL subscriber with schema/transaction/cached filtering
- Rack middleware for performance + exception capture
- N+1 detection within request scope (`n1_threshold`)
- PII `Sanitizer` for hash + header scrubbing
- `before_send` and `sample_rate` hooks
- Rails `Railtie` for automatic install
- Graceful `at_exit` shutdown with final flush

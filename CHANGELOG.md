# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

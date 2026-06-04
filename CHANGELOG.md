# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

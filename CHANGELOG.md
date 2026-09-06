# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.1 - 2026-09-06

### Changed

- Removed `subscription.addPublicStream()`/`removePublicStream()`; `addStream()` now accepts either a signed token or a plain string, falling back to a public stream when the token doesn't resolve.

## 2.0.0 - 2026-09-06

### Changed

- `DexieCable` is now a mixin: create your own `DexieChannel` with `include DexieCable`, then add custom actions and a `subscribed_to(record, params)` hook for initial data. The client `subscribe()` defaults to `"DexieChannel"` and accepts an optional channel name.
- Renamed `streams_via` to `syncs_to_dexie`, dropped the channel class argument, and renamed the `to:` option to `via:`.
- The client now uses Rails' own `@rails/actioncable` package instead of a bundled copy.

### Added

- Private streams: `DexieChannel.stream_token_for(target)` issues Rails signed IDs (configurable expiry, never expires by default); clients subscribe with `subscription.addStream(token)`.
- Public streams: string `via:` targets (e.g. `syncs_to_dexie via: "feed"`) are public and namespaced under `public:`; clients subscribe with `subscription.addStream("feed")` — a plain string falls back to a public stream.
- `subscription.addStream()` returns a function that removes the stream; `removeAllStreams()` stops every current stream.

### Removed

- Removed the bundled ActionCable client copy (`src/actioncable.js`).

## 1.0.0 - 2026-08-15

### Changed

- Renamed `streams_to_dexie` to `streams_via` and made the channel class a positional argument instead of the `via:` keyword.
- Made the `to` option optional — it now defaults to the record itself.

## 0.2.0

### Changed

- Renamed `syncs_to_dexie` to `streams_to_dexie`, reserving `syncs_to_dexie` for a future event-stream-based syncing method.

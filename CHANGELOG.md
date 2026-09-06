# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0.alpha5 - 2026-09-06

### Changed

- Stream tokens now use Rails' signed IDs (`SignedGlobalID`) instead of a custom verifier; expiry is configurable (`expires_in:`/`expires_at:`) and defaults to never expiring.

## 2.0.0.alpha4 - 2026-09-06

### Changed

- `DexieCable` is now a mixin: create your own `DexieChannel` and `include DexieCable`, then add custom actions and a `subscribed_to(record, params)` hook for initial data. The client `subscribe()` defaults to `"DexieChannel"` and accepts an optional channel name.

## 2.0.0.alpha3 - 2026-09-06

### Changed

- Replaced the `on_subscribe` callback with reopening `DexieChannel` to add custom actions and a `subscribed_to(record, params)` hook for initial data. `subscription.addStream()` now accepts extra params, forwarded to the hook.

## 2.0.0.alpha2 - 2026-09-06

### Added

- Added `DexieChannel.on_subscribe`, a callback invoked when a private stream is added, so the server can push initial data.

## 2.0.0.alpha1 - 2026-09-06

### Changed

- Renamed `streams_via` to `syncs_to_dexie`, dropped the channel class argument, and renamed the `to:` option to `via:`.
- Removed the `DexieCable` mixin — the gem now ships a single `DexieChannel` through which all Dexie transfer happens.
- The client `subscribe()` always subscribes to `DexieChannel`; streams are added and removed dynamically via `subscription.addStream()`/`removeStream()` using a signed token from `DexieChannel.stream_token_for(target)`.
- Added public streams: string `via:` targets (e.g. `syncs_to_dexie via: "feed"`) are public and namespaced under `public:`; clients subscribe with `subscription.addPublicStream()`/`removePublicStream()` and stop everything with `removeAllStreams()`.
- The client now uses Rails' own `@rails/actioncable` package instead of a bundled copy.

### Removed

- Removed the bundled ActionCable client copy (`src/actioncable.js`).

## 1.0.0 - 2026-08-15

### Changed

- Renamed `streams_to_dexie` to `streams_via` and made the channel class a positional argument instead of the `via:` keyword.
- Made the `to` option optional — it now defaults to the record itself.

## 0.2.0

### Changed

- Renamed `syncs_to_dexie` to `streams_to_dexie`, reserving `syncs_to_dexie` for a future event-stream-based syncing method.

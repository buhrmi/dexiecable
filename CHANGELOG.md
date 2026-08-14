# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 - 2026-08-15

### Changed

- Renamed `streams_to_dexie` to `streams_via` and made the channel class a positional argument instead of the `via:` keyword.
- Made the `to` option optional — it now defaults to the record itself.

## 0.2.0

### Changed

- Renamed `syncs_to_dexie` to `streams_to_dexie`, reserving `syncs_to_dexie` for a future event-stream-based syncing method.

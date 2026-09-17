# Zstd decompression gate (SPEC-004 Task 0)

**Date:** 2026-09-17  
**Decision:** use the [`zstandard`](https://pub.dev/packages/zstandard) Flutter plugin (v1.5.0) for in-app decompression of `.isb` and `catalog.sqlite.zst`.

## Candidates evaluated

| Package | Result |
|---|---|
| `zstandard` 1.5.0 | **Selected.** Embeds facebook/zstd C sources via FFI per platform plugin (`zstandard_{android,ios,macos,windows,linux}`). `flutter build macos` succeeds and links the plugin. Platform matrix: Android, iOS, macOS, Windows (Linux also; web present but web is out of scope). |
| `es_compression` 2.0.15 | Rejected for our fleet: ships only `eszstd-mac64.dylib` (**x86_64**). Dev machine is **arm64**; Android requires manually vendoring `.so` files. |
| `just_zstd` | Rejected: requires Dart SDK ≥3.11; project is on Flutter 3.32 / Dart 3.8.1. |

## Level-19 frame compatibility

SPEC-002 compresses with Python `zstandard` at **level 19**. Confirmed on macOS arm64 by decompressing `data/dist/book_1.isb` with system `libzstd` (Homebrew) via a thin FFI smoke (`app/tool/zstd_ffi_smoke.dart`): output starts with `SQLite format 3`, length 315392.

**App note:** `Zstandard().decompress` (plugin helper) sizes the output as `compressed × 20`. Level-19 catalog frames without a pledged content size expand more than 20× (e.g. 1521 → 49152), so that helper returns `null`. The app therefore calls `ZSTD_decompress` via FFI on the same embedded `zstandard_*` library with a growing buffer (`PluginZstdDecompressor` in `lib/core/compress/zstd.dart`). Pipeline compressors also pass `size=` / `write_content_size=True` so new frames embed content size.

Unit tests run in the Dart VM **without** the Flutter plugin’s native framework loaded. Production code uses the FFI wrapper above; tests inject a `ZstdDecompressor` fake or system `zstd` when available.

## Escalation

No gzip fallback needed. If a target fails to link `zstandard` in CI, escalate before changing SPEC-002 compression.

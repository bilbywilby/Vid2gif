# Changelog

## [0.1.0-beta] - 2026-08-08

### Added
- Single-pass `filter_complex` palette generation (replaces earlier two-pass
  file-based palette approach).
- `-d` flag for configurable dither algorithm (default `sierra2_4a`).
- `-n` dry-run flag to print the ffmpeg/gifsicle commands without executing.
- `-v` verbose flag to surface ffmpeg's own progress output.
- `-V` version flag.
- Input validation: readable-file check, positive-integer checks on `-f`/`-w`,
  output extension warning, overwrite warning.
- `set -euo pipefail` and `die`/`log` helpers for consistent error handling.

### Changed
- Compression now uses `gifsicle -O3 --batch` (in-place) instead of a
  temp-file swap.
- Output size reporting uses `numfmt` when available, falling back to `du -h`.

### Notes
- No external dependencies beyond `ffmpeg` (required) and `gifsicle`
  (optional, `-c` only).

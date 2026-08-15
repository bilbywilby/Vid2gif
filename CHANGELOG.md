# Changelog

All notable changes to `vid2gif` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-08-15

### Fixed
- Stale `port.py` invocation in CI smoke test replaced with `vid2gif` CLI entry point.
- Corrected author metadata and remote repository tracking to `bilbywilby/Vid2gif`.

### Cleanup
- Removed duplicate `.github/workflows/ci.yml` in favor of consolidated `main.yml`.
- Purged stale shell backup files (`vid2gif.sh.backup`, `vid2gif.sh.fixed_backup`, `vid2gif.sh.v0.3.0.backup`).

## [0.4.0b1] - 2026-08-11

### Added
- Native Python conversion pipeline (`converter.py`) utilizing `ConversionConfig` data structures.
- Automated GIF quality metrics calculation and odd-width aspect ratio scaling handling.
- `pyproject.toml` setup with direct CLI console script entry point.

### Changed
- Deprecated legacy shell-script wrapper (`vid2gif.sh`) in favor of unified Python module.

## [0.3.0] - 2026-08-09

### Added
- Single-pass `ffmpeg` filtergraph using `split`, `palettegen`, `paletteuse`
- Encoding presets via `-p`: `web`, `social`, `quality`, `minimal`
- Color control via `-m` (2-256 colors)
- Loop count via `-l` (0 = infinite)
- Dither algorithms: `bayer`, `floyd_steinberg`, `sierra2`, `sierra2_4a`, `sierra3`, `burkes`, `atkinson`, `none`
- Dry-run mode (`-n`, `--dry-run`)
- Human-readable file sizing via `numfmt`

### Changed
- `-r` replaces `-f` for framerate (POSIX alignment)
- Structured `log()` / `die()` error handling
- In-memory filter graph (no temp palette files)

### Removed
- `vid2gif-1.sh`, `vid2gif-2.sh`, `README-3.md`, `vid2gif.pdf`

## [0.1.0] - 2026-08-09
- Initial release with two-stage palette generation

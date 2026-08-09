# Changelog

All notable changes to `vid2gif` will be documented in this file.

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

# vid2gif

POSIX-compliant Bash script for converting video containers to optimized animated GIFs using `ffmpeg` and optional `gifsicle`.

## Features

- **Single-Pass Filtergraph**: Palettes generated in memory, no disk I/O
- **Dither Control**: 8 spatial dither algorithms supported
- **Preset Profiles**: `web`, `social`, `quality`, `minimal`
- **Dry-Run Inspection**: Preview execution commands with `-n`
- **Zero Temp Files**: No residual filesystem artifacts

## Dependencies

| Tool | Required? | Purpose |
|------|-----------|---------|
| `ffmpeg` | Yes | Core conversion engine |
| `gifsicle` | No | Post-processing optimization (`-O`) |

## Usage
I see the issue — the heredoc content is getting truncated in the terminal. Let me provide a cleaner solution using smaller chunks:Solution: Write Documentation in Smaller Chunkscd ~/pixel-terminal-master/Vid2gif

# 1. Clean up backup file first
rm -f vid2gif.sh.backup

# 2. Write CHANGELOG.md in one chunk (smaller)
cat > CHANGELOG.md << 'ENDCHANGELOG'
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
ENDCHANGELOG

# 3. Write README.md in two parts
cat > README.md << 'ENDREADME'
# vid2gif

POSIX-compliant Bash script for converting video containers to optimized animated GIFs using `ffmpeg` and optional `gifsicle`.

## Features

- **Single-Pass Filtergraph**: Palettes generated in memory, no disk I/O
- **Dither Control**: 8 spatial dither algorithms supported
- **Preset Profiles**: `web`, `social`, `quality`, `minimal`
- **Dry-Run Inspection**: Preview execution commands with `-n`
- **Zero Temp Files**: No residual filesystem artifacts

## Dependencies

| Tool | Required? | Purpose |
|------|-----------|---------|
| `ffmpeg` | Yes | Core conversion engine |
| `gifsicle` | No | Post-processing optimization (`-O`) |

## Usagebash
./vid2gif.sh -i <input_video> [OPTIONS]

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

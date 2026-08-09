# vid2gif

A small, dependency-light Bash script for converting video files (or terminal
screen recordings) into optimized animated GIFs using `ffmpeg`'s two-color-pass
palette technique, done in a single ffmpeg invocation.

> **Status:** beta (`v0.1.0-beta`). Interface may still change before v1.0.0.

## Why

`ffmpeg`'s default GIF encoder is limited to a global 256-color palette and
tends to produce banding/dithering artifacts on text-heavy or high-detail
footage. This script generates a custom palette per-clip and applies it with
configurable dithering, producing noticeably cleaner output — especially for
terminal recordings — without needing extra Python/Node tooling.

## Requirements

- `ffmpeg` (required)
- `gifsicle` (optional, only needed for `-c` compression)

No other dependencies.

## Install

```bash
git clone https://github.com/<you>/vid2gif.git
cd vid2gif
chmod +x vid2gif.sh
# optionally symlink onto your PATH
ln -s "$(pwd)/vid2gif.sh" /usr/local/bin/vid2gif
```

## Usage

```
vid2gif.sh -i input.mp4 [-o output.gif] [-f fps] [-w width]
           [-s start] [-t duration] [-d dither] [-c] [-n] [-v] [-h] [-V]
```

| Flag | Meaning | Default |
|------|---------|---------|
| `-i` | Input video file (required) | — |
| `-o` | Output GIF path | `<input_basename>.gif` |
| `-f` | Frames per second | `15` |
| `-w` | Output width in px (height auto-scaled) | `800` |
| `-s` | Start time (`00:00:05` or `5`) | none |
| `-t` | Duration to encode | full remaining clip |
| `-d` | Dither algorithm for `paletteuse` | `sierra2_4a` |
| `-c` | Compress output with `gifsicle -O3` | off |
| `-n` | Dry run — print the ffmpeg command, don't execute | off |
| `-v` | Verbose ffmpeg output | off |
| `-V` | Print version and exit | — |
| `-h` | Show help | — |

### Examples

Basic conversion:

```bash
./vid2gif.sh -i demo.mp4
```

Trim to an 8-second clip starting at 3s, 900px wide, 12fps, compressed:

```bash
./vid2gif.sh -i demo.mp4 -o demo.gif -f 12 -w 900 -s 3 -t 8 -c
```

Preview the ffmpeg command without running it:

```bash
./vid2gif.sh -i demo.mp4 -n
```

## How it works

The script builds a single `ffmpeg` `filter_complex` graph that:

1. Applies `fps`/`scale` to the input stream.
2. Splits the stream into two copies.
3. Runs `palettegen` on one copy to build an optimal 256-color palette for
   that specific clip.
4. Runs `paletteuse` on the other copy against that palette, with a
   configurable dither algorithm.

This avoids writing an intermediate palette PNG to disk and keeps everything
in one process.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. This is a beta release; please report edge cases
around unusual input codecs, container formats, or filter option interactions.

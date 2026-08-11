# vid2gif

Video-to-GIF converter utilizing two-pass FFmpeg palette generation and SSIM/PSNR benchmarking.

## Installation bash pip install vid2gif


## Usage

### Command Line

Basic:

bash vid2gif input.mp4 -o output.gif


With benchmarking:

bash vid2gif input.mp4 -o output.gif --fps 20 --width 600 --benchmark


### Python API

python from vid2gif.converter import GifConverter

converter = GifConverter("input.mp4", "output.gif") result = converter.convert(fps=15, width=480) print(f"Generated in {result['elapsed_seconds']}s")

metrics = converter.compute_quality_metrics() print(f"PSNR: {metrics['psnr']} dB | SSIM: {metrics['ssim']}")


## Features

- Two-pass palette generation for optimal colors
- Configurable FPS and resolution (`-2` scaling ensures even dimensions)
- PSNR/SSIM quality metrics (dimension-mismatch safe via `scale2ref`)
- Clean CLI interface
- Reproducible Docker benchmarking environments

## License

MIT

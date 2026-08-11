# vid2gif

Video-to-GIF converter utilizing two-pass FFmpeg palette generation and SSIM/PSNR benchmarking.

## Installationbash
pip install vid2gif
## Usage

### Command Line

Basic conversion:bash
vid2gif input.mp4 -o output.gif
With quality benchmarking:bash
vid2gif input.mp4 -o output.gif --fps 20 --width 600 --benchmark
### Python APIpython
from vid2gif.converter import GifConverter
converter = GifConverter("input.mp4", "output.gif")
result = converter.convert(fps=15, width=480)
print(f"Generated in {result['elapsed_seconds']}s")
Quality metrics (PSNR/SSIM)
metrics = converter.compute_quality_metrics()
print(f"PSNR: {metrics['psnr']} dB | SSIM: {metrics['ssim']}")
## Features

- Two-pass palette generation for optimal colors
- Configurable FPS and resolution (`-2` ensures even heights)
- PSNR/SSIM quality benchmarking (`scale2ref` safe)
- Clean CLI interface
- Reproducible Docker environments

## License

MIT

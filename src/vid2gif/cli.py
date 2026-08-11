import argparse
import sys
from pathlib import Path
from vid2gif.converter import GifConverter

def main():
    parser = argparse.ArgumentParser(
        description="CLI utility for video-to-GIF conversion with quality benchmarking."
    )
    parser.add_argument("input", help="Path to input video file")
    parser.add_argument("-o", "--output", default="output.gif", help="Path to destination GIF file")
    parser.add_argument("--fps", type=int, default=15, help="Frame rate setting (default: 15)")
    parser.add_argument("--width", type=int, default=480, help="Width in pixels (default: 480)")
    parser.add_argument("--benchmark", "-b", action="store_true", help="Calculate PSNR and SSIM quality scores")
    parser.add_argument("--no-palette", action="store_true", help="Disable two-pass palette optimization")

    args = parser.parse_args()

    if not Path(args.input).exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    try:
        converter = GifConverter(args.input, args.output)
        stats = converter.convert(fps=args.fps, width=args.width, optimize_palette=not args.no_palette)
        
        print(f"Converted: {args.output} ({stats['size_bytes']/1024:.1f} KB, {stats['elapsed_seconds']}s)")
        
        if args.benchmark:
            metrics = converter.compute_quality_metrics()
            if metrics["psnr"] > 0:
                print(f"PSNR: {metrics['psnr']:.2f} dB | SSIM: {metrics['ssim']:.4f}")
            else:
                print("Could not compute metrics (video too short)")
                
    except Exception as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

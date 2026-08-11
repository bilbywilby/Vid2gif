import argparse
import sys
from pathlib import Path
from vid2gif.converter import GifConverter

def main():
    """CLI entry point for vid2gif."""
    parser = argparse.ArgumentParser(
        prog="vid2gif",
        description="Video-to-GIF converter with quality benchmarking."
    )
    parser.add_argument("input", help="Path to input video file")
    parser.add_argument("-o", "--output", default="output.gif", help="Output GIF path")
    parser.add_argument("--fps", type=int, default=15, help="Frames per second (default: 15)")
    parser.add_argument("--width", type=int, default=480, help="Width in pixels (default: 480)")
    parser.add_argument("--benchmark", "-b", action="store_true", help="Compute PSNR/SSIM")
    parser.add_argument("--no-palette", action="store_true", help="Skip two-pass optimization")
    parser.add_argument("--version", action="version", version="vid2gif 0.5.1")

    args = parser.parse_args()

    # Validate input exists
    if not Path(args.input).exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    try:
        converter = GifConverter(args.input, args.output)
        stats = converter.convert(
            fps=args.fps,
            width=args.width,
            optimize_palette=not args.no_palette
        )

        # Print summary
        print(f"✓ Converted: {Path(args.output).name}")
        print(f"  Size: {stats['size_bytes']/1024:.1f} KB")
        print(f"  Time: {stats['elapsed_seconds']}s")
        print(f"  Settings: {stats['fps']} FPS | {stats['width']}px")

        # Optional benchmarking
        if args.benchmark:
            print("\nComputing quality metrics...")
            metrics = converter.compute_quality_metrics()

            if metrics["psnr"] > 0:
                print(f"  PSNR: {metrics['psnr']:.2f} dB")
                print(f"  SSIM: {metrics['ssim']:.4f}")

                # Quality interpretation
                if metrics["psnr"] > 30:
                    print("  ✅ Excellent quality")
                elif metrics["psnr"] > 25:
                    print("  ✅ Good quality")
                else:
                    print("  ⚠️ Moderate quality")
            else:
                print("  ⚠️ Metrics unavailable (video may be too short)")

    except FileNotFoundError as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)
    except Exception as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

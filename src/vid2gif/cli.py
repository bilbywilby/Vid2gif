import argparse
import sys
import vid2gif.converter as converter

# Resolve conversion function and config class dynamically from module exports
convert_fn = (
    getattr(converter, "convert_video", None)
    or getattr(converter, "convert", None)
    or getattr(converter, "convert_video_to_gif", None)
)
config_cls = (
    getattr(converter, "ConversionConfig", None)
    or getattr(converter, "Config", None)
    or getattr(converter, "GifConfig", None)
)

def main():
    parser = argparse.ArgumentParser(
        description="Convert video files to optimized animated GIFs using FFmpeg."
    )
    
    parser.add_argument(
        "positional_input",
        nargs="?",
        default=None,
        help="Path to input video file"
    )
    parser.add_argument(
        "-i", "--input",
        dest="flag_input",
        default=None,
        help="Path to input video file"
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Path to output GIF file"
    )
    parser.add_argument(
        "-w", "--width",
        type=int,
        default=480,
        help="Width in pixels (default: 480)"
    )
    parser.add_argument(
        "-f", "--fps",
        type=int,
        default=15,
        help="Frames per second (default: 15)"
    )
    parser.add_argument(
        "-b", "--benchmark",
        action="store_true",
        help="Compute PSNR/SSIM quality metrics"
    )
    parser.add_argument(
        "--no-palette",
        action="store_true",
        help="Skip two-pass palette optimization"
    )
    parser.add_argument(
        "-v", "--version",
        action="version",
        version="vid2gif 0.5.1"
    )

    args = parser.parse_args()

    input_file = args.flag_input or args.positional_input
    if not input_file:
        parser.error("An input video path is required (pass as positional argument or -i/--input).")

    output_file = args.output
    if not output_file:
        output_file = f"{input_file.rsplit('.', 1)[0]}.gif"

    if convert_fn is None:
        print("Error: No valid conversion function found in vid2gif.converter module.", file=sys.stderr)
        sys.exit(1)

    try:
        if config_cls:
            cfg = config_cls(
                input_path=input_file,
                output_path=output_file,
                width=args.width,
                fps=args.fps,
                benchmark=args.benchmark,
                optimize_palette=not args.no_palette
            )
            convert_fn(cfg)
        else:
            convert_fn(
                input_path=input_file,
                output_path=output_file,
                width=args.width,
                fps=args.fps,
                benchmark=args.benchmark,
                optimize_palette=not args.no_palette
            )
        print(f"Successfully generated: {output_file}")
    except Exception as e:
        print(f"Error converting video: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

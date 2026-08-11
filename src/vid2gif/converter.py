#!/usr/bin/env python3
"""vid2gif - Video to GIF Converter using FFmpeg."""

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

__version__ = "0.4.0b1"
__author__ = "bilbywilby"
__license__ = "MIT"

PRESETS: Dict[str, Dict[str, Any]] = {
    "web": {"width": 480, "fps": 12, "max_colors": 128, "dither": "floyd_steinberg"},
    "social": {"width": 480, "fps": 10, "max_colors": 96, "dither": "sierra2_4a"},
    "quality": {"width": 800, "fps": 15, "max_colors": 256, "dither": "sierra2_4a"},
    "minimal": {"width": 320, "fps": 8, "max_colors": 64, "dither": "atkinson"},
}

VALID_DITHERS: List[str] = [
    "bayer", "floyd_steinberg", "sierra2", "sierra2_4a",
    "sierra3", "burkes", "atkinson", "none",
]


class Vid2GifError(Exception):
    """Base exception for vid2gif errors."""


class FFmpegNotFoundError(Vid2GifError):
    """Raised when ffmpeg is not found on PATH."""


class InputFileError(Vid2GifError):
    """Raised when input file validation fails."""


class ConversionError(Vid2GifError):
    """Raised when conversion fails."""


class OutputFileError(Vid2GifError):
    """Raised when output file operations fail."""


class TargetSizeUnreachableError(Vid2GifError):
    """Raised when target size limit not reached within constraints."""


def _human_size(bytes_val: float) -> str:
    """Convert bytes to human-readable format."""
    for unit in ["B", "KB", "MB", "GB"]:
        if abs(bytes_val) < 1024.0:
            return f"{bytes_val:.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} TB"


def probe_width(input_path: Union[str, Path]) -> int:
    """Extract video width using ffprobe."""
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width",
            "-of", "csv=p=0",
            str(input_path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ConversionError(f"Could not probe video width: {result.stderr}")
    try:
        return int(result.stdout.strip())
    except ValueError:
        raise ConversionError(f"Invalid width from ffprobe: {result.stdout}")


@dataclass
class ConversionConfig:
    """Holds and validates conversion parameters. Validation is deferred: call .validate() explicitly."""

    input_path: Path
    output_path: Optional[Path] = None
    width: int = 480
    fps: int = 15
    max_colors: int = 256
    dither: str = "sierra2_4a"
    loop_count: int = 0
    start_time: Optional[str] = None
    duration: Optional[str] = None
    auto_crop: bool = False
    dry_run: bool = False

    def __post_init__(self) -> None:
        self.input_path = Path(self.input_path)
        if self.output_path is None:
            self.output_path = self.input_path.with_suffix(".gif")
        else:
            self.output_path = Path(self.output_path)

    def validate(self) -> None:
        """Validate parameter ranges. Raises ValueError on the first invalid field found."""
        if not (64 <= self.width <= 3840):
            raise ValueError(f"Width must be between 64 and 3840, got {self.width}")
        if not (1 <= self.fps <= 60):
            raise ValueError(f"FPS must be between 1 and 60, got {self.fps}")
        if not (2 <= self.max_colors <= 256):
            raise ValueError(f"max_colors must be between 2 and 256, got {self.max_colors}")
        if self.dither not in VALID_DITHERS:
            raise ValueError(f"Invalid dither: {self.dither}. Valid options: {', '.join(VALID_DITHERS)}")
        if self.loop_count < 0:
            raise ValueError(f"loop_count must be non-negative, got {self.loop_count}")


class Vid2GifConverter:
    """Main converter class for video to GIF conversion."""

    def __init__(
        self,
        input_path: Union[str, Path],
        output_path: Optional[Union[str, Path]] = None,
        width: int = 480,
        fps: int = 15,
        max_colors: int = 256,
        dither: str = "sierra2_4a",
        loop_count: int = 0,
        start_time: Optional[str] = None,
        duration: Optional[str] = None,
        auto_crop: bool = False,
        dry_run: bool = False,
        optimize: bool = False,
        verbose: bool = False,
    ):
        self.config = ConversionConfig(
            input_path=input_path,
            output_path=output_path,
            width=width,
            fps=fps,
            max_colors=max_colors,
            dither=dither,
            loop_count=loop_count,
            start_time=start_time,
            duration=duration,
            auto_crop=auto_crop,
            dry_run=dry_run,
        )
        self.optimize = optimize
        self.verbose = verbose

    def _validate_environment(self) -> None:
        if shutil.which("ffmpeg") is None:
            raise FFmpegNotFoundError(
                "ffmpeg binary not found on PATH. Install with: sudo apt install ffmpeg"
            )

    def _build_base_filters(self) -> str:
        filters: List[str] = []
        if self.config.auto_crop:
            filters.append("cropdetect=24:16:0")
        if self.config.fps:
            filters.append(f"fps={self.config.fps}")
        if self.config.width:
            filters.append(f"scale={self.config.width}:-2:flags=lanczos")
        return ",".join(filters)

    def _build_ffmpeg_cmd(self, filter_graph: str, output_path: Path) -> List[str]:
        cmd = ["ffmpeg", "-y", "-v", "error"]
        if self.config.start_time:
            cmd.extend(["-ss", str(self.config.start_time)])
        if self.config.duration:
            cmd.extend(["-t", str(self.config.duration)])
        cmd.extend(["-i", str(self.config.input_path)])
        if filter_graph:
            cmd.extend(["-lavfi", filter_graph])
        cmd.extend(["-loop", str(self.config.loop_count), str(output_path)])
        return cmd

    def _build_commands(self) -> List[Tuple[str, List[str]]]:
        filter_graph = self._build_base_filters()
        cmd = self._build_ffmpeg_cmd(filter_graph, self.config.output_path)
        return [("convert", cmd)]

    def convert(self) -> Path:
        if self.config.dry_run:
            if self.verbose:
                print("[Dry Run] Conversion skipped.")
            return self.config.output_path

        self._validate_environment()
        self.config.validate()

        if not self.config.input_path.exists():
            raise InputFileError(f"Input file does not exist: {self.config.input_path}")

        for label, cmd in self._build_commands():
            if self.verbose:
                print(f"Running {label}: {' '.join(cmd)}")
            try:
                subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                stderr = e.stderr.decode("utf-8", errors="ignore") if e.stderr else ""
                raise ConversionError(f"{label} failed: {stderr}")

        return self.config.output_path


def convert_video_to_gif(
    input_path: str,
    output_path: Optional[str] = None,
    **kwargs: Any,
) -> Path:
    """Helper function to convert a video to GIF programmatically."""
    converter = Vid2GifConverter(input_path=input_path, output_path=output_path, **kwargs)
    return converter.convert()


def main() -> None:
    """CLI entrypoint."""
    parser = argparse.ArgumentParser(
        description="Convert video files to optimized animated GIFs using FFmpeg."
    )
    parser.add_argument("-i", "--input", required=True, help="Path to input video file")
    parser.add_argument("-o", "--output", help="Path to output GIF file")
    parser.add_argument("-w", "--width", type=int, default=480)
    parser.add_argument("-f", "--fps", type=int, default=15)
    parser.add_argument("-c", "--colors", type=int, default=256)
    parser.add_argument("-l", "--loop", type=int, default=0)
    parser.add_argument("-d", "--dither", default="sierra2_4a", choices=VALID_DITHERS)
    parser.add_argument("-s", "--start")
    parser.add_argument("-t", "--duration")
    parser.add_argument("--preset", choices=list(PRESETS.keys()))
    parser.add_argument("--auto-crop", action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    args = parser.parse_args()

    config: Dict[str, Any] = PRESETS[args.preset] if args.preset else {}

    try:
        converter = Vid2GifConverter(
            input_path=args.input,
            output_path=args.output,
            width=config.get("width", args.width),
            fps=config.get("fps", args.fps),
            max_colors=config.get("max_colors", args.colors),
            dither=config.get("dither", args.dither),
            loop_count=args.loop,
            start_time=args.start,
            duration=args.duration,
            auto_crop=args.auto_crop,
            dry_run=args.dry_run,
            verbose=args.verbose,
        )
        out = converter.convert()
        print(f"Successfully converted to: {out}")
    except Vid2GifError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nOperation cancelled by user.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

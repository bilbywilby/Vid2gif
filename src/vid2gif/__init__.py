"""vid2gif — Convert video files to optimized animated GIFs using FFmpeg."""

from vid2gif.converter import (
    ConversionConfig,
    ConversionError,
    FFmpegNotFoundError,
    InputFileError,
    OutputFileError,
    PRESETS,
    TargetSizeUnreachableError,
    VALID_DITHERS,
    Vid2GifConverter,
    Vid2GifError,
    _human_size,
    convert_video_to_gif,
    probe_width,
)

__version__ = "0.4.0b1"
__author__ = "bilbywilby"
__license__ = "MIT"

__all__ = [
    "ConversionConfig",
    "Vid2GifConverter",
    "convert_video_to_gif",
    "Vid2GifError",
    "FFmpegNotFoundError",
    "InputFileError",
    "ConversionError",
    "OutputFileError",
    "TargetSizeUnreachableError",
    "PRESETS",
    "VALID_DITHERS",
    "_human_size",
    "probe_width",
]

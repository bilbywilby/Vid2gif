"""vid2gif — Convert video files to optimized animated GIFs using FFmpeg."""

from vid2gif.converter import (
    Vid2GifConverter,
    convert_video_to_gif,
    Vid2GifError,
    FFmpegNotFoundError,
    InputFileError,
    ConversionError,
    OutputFileError,
    TargetSizeUnreachableError,
    PRESETS,
    VALID_DITHERS,
)

__version__ = "0.4.0b1"
__author__ = "bilbywilby"
__license__ = "MIT"

__all__ = [
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
    "__version__",
]

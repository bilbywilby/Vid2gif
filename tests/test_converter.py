"""Test suite for vid2gif converter."""

from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest

from vid2gif.converter import (
    PRESETS,
    VALID_DITHERS,
    ConversionError,
    FFmpegNotFoundError,
    InputFileError,
    OutputFileError,
    TargetSizeUnreachableError,
    Vid2GifConverter,
    Vid2GifError,
    _human_size,
    probe_width,
)


class TestHumanSize:
    @pytest.mark.parametrize("bytes_val,expected", [
        (512, "512.0 B"),
        (1024, "1.0 KB"),
        (1536, "1.5 KB"),
        (1048576, "1.0 MB"),
        (1073741824, "1.0 GB"),
    ])
    def test_sizes(self, bytes_val, expected):
        assert _human_size(bytes_val) == expected


class TestConversionConfigValidation:
    def test_valid_config(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00" * 100)
        c = Vid2GifConverter(input_path=str(inp))
        c.config.validate()

    @pytest.mark.parametrize("width", [10, 50, 5000])
    def test_invalid_width(self, tmp_path, width):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), width=width)
        with pytest.raises(ValueError, match="Width"):
            c.config.validate()

    @pytest.mark.parametrize("fps", [0, -1, 61, 120])
    def test_invalid_fps(self, tmp_path, fps):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), fps=fps)
        with pytest.raises(ValueError, match="FPS"):
            c.config.validate()

    @pytest.mark.parametrize("colors", [1, 257, 0, -5])
    def test_invalid_colors(self, tmp_path, colors):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), max_colors=colors)
        with pytest.raises(ValueError, match="max_colors"):
            c.config.validate()

    def test_invalid_dither(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), dither="nonexistent")
        with pytest.raises(ValueError, match="dither"):
            c.config.validate()

    @pytest.mark.parametrize("loop", [-1, -10])
    def test_negative_loop(self, tmp_path, loop):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), loop_count=loop)
        with pytest.raises(ValueError, match="loop"):
            c.config.validate()


class TestConverterExecution:
    @patch("vid2gif.converter.subprocess.run")
    def test_dry_run_mode(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(returncode=0)
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00" * 100)
        c = Vid2GifConverter(input_path=str(inp), dry_run=True)
        result = c.convert()
        assert result == c.config.output_path
        mock_run.assert_not_called()

    @patch("vid2gif.converter.shutil.which")
    def test_validate_environment_missing_ffmpeg(self, mock_which, tmp_path):
        mock_which.return_value = None
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp))
        with pytest.raises(FFmpegNotFoundError, match="ffmpeg"):
            c._validate_environment()


class TestProbeWidth:
    @patch("vid2gif.converter.subprocess.run")
    def test_probe_width_success(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(returncode=0, stdout="1920\n", stderr="")
        width = probe_width(tmp_path / "test.mp4")
        assert width == 1920

    @patch("vid2gif.converter.subprocess.run")
    def test_probe_width_failure(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
        with pytest.raises(ConversionError, match="Could not probe"):
            probe_width(tmp_path / "test.mp4")


class TestFilterBuilding:
    def test_build_base_filters_default(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp))
        filters = c._build_base_filters()
        assert "fps=15" in filters
        assert "scale=480:-2" in filters

    def test_build_base_filters_with_auto_crop(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), auto_crop=True)
        filters = c._build_base_filters()
        assert "cropdetect=24:16:0" in filters


class TestPresetIntegration:
    def test_all_presets_exist(self):
        for name in ["web", "social", "quality", "minimal"]:
            assert name in PRESETS

    def test_web_preset_values(self):
        web = PRESETS["web"]
        assert web["width"] == 480
        assert web["fps"] == 12
        assert web["max_colors"] == 128
        assert web["dither"] == "floyd_steinberg"


class TestExceptionHierarchy:
    def test_specific_exceptions_extend_base(self):
        assert issubclass(FFmpegNotFoundError, Vid2GifError)
        assert issubclass(InputFileError, Vid2GifError)
        assert issubclass(ConversionError, Vid2GifError)
        assert issubclass(OutputFileError, Vid2GifError)
        assert issubclass(TargetSizeUnreachableError, Vid2GifError)

    def test_catch_all_via_base(self):
        try:
            raise ConversionError("test")
        except Vid2GifError:
            pass


class TestCommandBuilding:
    def test_build_ffmpeg_cmd_includes_loop(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), loop_count=5)
        cmd = c._build_ffmpeg_cmd("test_graph", tmp_path / "output.gif")
        assert "-loop" in cmd
        assert "5" in cmd

    def test_dry_run_commands_structure(self, tmp_path):
        inp = tmp_path / "input.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), dry_run=True)
        cmds = c._build_commands()
        assert len(cmds) > 0
        for label, cmd in cmds:
            assert isinstance(label, str)
            assert isinstance(cmd, list)
            assert cmd[0] == "ffmpeg"


class TestOutputPathHandling:
    def test_default_output_suffix(self, tmp_path):
        inp = tmp_path / "video.mp4"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp))
        assert c.config.output_path.suffix == ".gif"

    def test_custom_output_path(self, tmp_path):
        inp = tmp_path / "video.mp4"
        out = tmp_path / "custom.gif"
        inp.write_bytes(b"\x00")
        c = Vid2GifConverter(input_path=str(inp), output_path=str(out))
        assert c.config.output_path == out

if __name__ == "__main__":
    pytest.main([__file__, "-v"])

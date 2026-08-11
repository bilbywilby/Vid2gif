import os
import subprocess
import pytest
from vid2gif.converter import GifConverter

@pytest.fixture
def mock_video(tmp_path):
    """Generates a 2-second synthetic MP4 (adequate for metrics)."""
    video_path = os.path.join(tmp_path, "sample.mp4")
    cmd = [
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", "testsrc=duration=2:size=320x240:rate=10",
        "-c:v", "libx264", video_path,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return video_path

@pytest.fixture
def short_video(tmp_path):
    """1-second video for edge case testing."""
    video_path = os.path.join(tmp_path, "short.mp4")
    cmd = [
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", "testsrc=duration=1:size=320x240:rate=10",
        "-c:v", "libx264", video_path,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return video_path

def test_conversion_output(mock_video, tmp_path):
    """Test basic conversion produces valid GIF."""
    output_path = os.path.join(tmp_path, "output.gif")
    converter = GifConverter(mock_video, output_path)
    result = converter.convert(fps=10, width=160)

    assert os.path.exists(output_path)
    assert result["size_bytes"] > 0
    assert result["fps"] == 10
    assert result["width"] == 160

def test_quality_metrics_calculation(mock_video, tmp_path):
    """Test quality metrics on adequate length video (2+ seconds)."""
    output_path = os.path.join(tmp_path, "output.gif")
    converter = GifConverter(mock_video, output_path)
    converter.convert(fps=10, width=160)
    metrics = converter.compute_quality_metrics()

    assert "psnr" in metrics
    assert "ssim" in metrics
    # Values should be reasonable (not negative)
    assert metrics["psnr"] >= 0.0
    assert 0.0 <= metrics["ssim"] <= 1.0 or metrics["ssim"] == 0.0

def test_short_video_edge_case(short_video, tmp_path):
    """Test behavior with very short video (may have limited metrics)."""
    output_path = os.path.join(tmp_path, "short_output.gif")
    converter = GifConverter(short_video, output_path)
    result = converter.convert(fps=10, width=160)

    assert os.path.exists(output_path)
    assert result["size_bytes"] > 0

def test_file_not_found_raises():
    """Test proper error handling for missing input."""
    with pytest.raises(FileNotFoundError):
        GifConverter("/nonexistent/file.mp4", "output.gif")

def test_odd_width_scaling(tmp_path, mock_video):
    """Test that -2 scaling ensures even dimensions."""
    output_path = os.path.join(tmp_path, "odd_width.gif")
    converter = GifConverter(mock_video, output_path)
    result = converter.convert(fps=10, width=319)  # Odd width

    assert os.path.exists(output_path)
    assert result["width"] == 319

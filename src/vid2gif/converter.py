import os
import re
import subprocess
import tempfile
import time
from typing import Any, Dict

class GifConverter:
    """Handles FFmpeg video-to-GIF conversion using 2-pass palette generation."""

    def __init__(self, input_path: str, output_path: str):
        self.input_path = os.path.abspath(input_path)
        self.output_path = os.path.abspath(output_path)

        if not os.path.exists(self.input_path):
            raise FileNotFoundError(f"Input file not found: {self.input_path}")

    def convert(
        self,
        fps: int = 15,
        width: int = 480,
        optimize_palette: bool = True,
        stats_mode: str = "full",
    ) -> Dict[str, Any]:
        """Executes conversion using FFmpeg palette generation."""
        start_time = time.time()

        tmp_dir = tempfile.gettempdir()
        palette_path = os.path.join(
            tmp_dir, f"palette_{os.getpid()}_{int(time.time()*1000)}.png"
        )

        fps_str = str(fps)
        scale_str = f"scale={width}:-2:flags=lanczos"

        try:
            if optimize_palette:
                palette_filter = (
                    f"fps={fps_str},{scale_str},palettegen=stats_mode={stats_mode}"
                )
                use_filter = (
                    f"fps={fps_str},{scale_str} [x]; [x][1:v] paletteuse=dither=sierra2_4a"
                )

                cmd_pass1 = [
                    "ffmpeg", "-y", "-i", self.input_path,
                    "-vf", palette_filter, palette_path,
                ]
                subprocess.run(cmd_pass1, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                cmd_pass2 = [
                    "ffmpeg", "-y", "-i", self.input_path, "-i", palette_path,
                    "-filter_complex", use_filter, self.output_path,
                ]
                subprocess.run(cmd_pass2, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                cmd_single = [
                    "ffmpeg", "-y", "-i", self.input_path,
                    "-vf", f"fps={fps_str},{scale_str}", self.output_path,
                ]
                subprocess.run(cmd_single, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        finally:
            if os.path.exists(palette_path):
                os.remove(palette_path)

        elapsed_time = time.time() - start_time
        file_size = os.path.getsize(self.output_path) if os.path.exists(self.output_path) else 0

        return {
            "input": self.input_path,
            "output": self.output_path,
            "elapsed_seconds": round(elapsed_time, 3),
            "size_bytes": file_size,
            "fps": fps,
            "width": width,
        }

    def compute_quality_metrics(self) -> Dict[str, float]:
        """Calculates PSNR and SSIM quality metrics against the source video."""
        filter_str = (
            "[0:v][1:v]scale2ref[ref_scaled][gif_scaled];"
            "[ref_scaled]split[ref1][ref2];"
            "[gif_scaled]split[gif1][gif2];"
            "[gif1][ref1]psnr;[gif2][ref2]ssim"
        )

        cmd_metrics = [
            "ffmpeg", "-i", self.input_path, "-i", self.output_path,
            "-filter_complex", filter_str, "-f", "null", "-",
        ]

        result = subprocess.run(
            cmd_metrics, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True, 
            check=True
        )
        
        metrics = {"psnr": 0.0, "ssim": 0.0}
        stderr_out = result.stderr

        # More flexible regex patterns for FFmpeg output
        # Pattern 1: PSNR average: XX.XX (dB)
        # Pattern 2: All:XX.XX (for SSIM)
        # Pattern 3: "Y:XX.XX U:XX.XX V:XX.XX" format
        
        psnr_patterns = [
            r"(?i)PSNR.*average[:\s]+([0-9.]+)",
            r"(?i)(?:Y|overall)[:\s]+([0-9.]+).*\(dB\)?",
            r"(?i)avg[:\s]+([0-9.]+)",
        ]
        
        ssim_patterns = [
            r"(?i)SSIM.*All[:\s]+([0-9.]+)",
            r"(?i)All[:\s]+([0-9.]+)\s*$",
            r"(?i)Y[:\s]+([0-9.]+)\s+U[:\s]+[0-9.]+\s+V[:\s]+[0-9.]+",
        ]
        
        for pattern in psnr_patterns:
            match = re.search(pattern, stderr_out)
            if match:
                try:
                    val = float(match.group(1))
                    if val > 0:
                        metrics["psnr"] = val
                        break
                except (ValueError, IndexError):
                    continue

        for pattern in ssim_patterns:
            match = re.search(pattern, stderr_out)
            if match:
                try:
                    val = float(match.group(1))
                    if val > 0:
                        metrics["ssim"] = val
                        break
                except (ValueError, IndexError):
                    continue

        # If still 0.0, the file may be too short/small - log warning
        if metrics["psnr"] == 0.0 or metrics["ssim"] == 0.0:
            print(f"[WARNING] Could not extract metrics. STDERR sample: {stderr_out[-500:]}")

        return metrics

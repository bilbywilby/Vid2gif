import os
import re
import subprocess
from dataclasses import dataclass


@dataclass
class ConversionConfig:
    input_path: str
    output_path: str
    width: int = 480
    fps: int = 15
    benchmark: bool = False
    optimize_palette: bool = True


class GifConverter:
    def __init__(
        self,
        input_path=None,
        output_path=None,
        width: int = 480,
        fps: int = 15,
        benchmark: bool = False,
        optimize_palette: bool = True,
        config: ConversionConfig = None
    ):
        if isinstance(input_path, ConversionConfig):
            self.config = input_path
        elif config is not None:
            self.config = config
        else:
            self.config = ConversionConfig(
                input_path=input_path,
                output_path=output_path,
                width=width,
                fps=fps,
                benchmark=benchmark,
                optimize_palette=optimize_palette
            )

    def convert(self):
        if not self.config.input_path or not os.path.exists(self.config.input_path):
            raise FileNotFoundError(f"Input file not found: {self.config.input_path}")

        target_width = self.config.width
        if target_width % 2 != 0:
            target_width -= 1

        filter_complex = f"fps={self.config.fps},scale={target_width}:-2:flags=lanczos"
        if self.config.optimize_palette:
            filter_complex += " [x]; [x] split [a][b]; [a] palettegen [p]; [b][p] paletteuse"

        cmd = [
            "ffmpeg", "-y", "-i", self.config.input_path,
            "-vf", filter_complex, self.config.output_path
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        if self.config.benchmark:
            return self.compute_quality_metrics()
        return None

    def _parse_metric(self, log_output: str, pattern: str) -> float:
        match = re.search(pattern, log_output)
        return float(match.group(1)) if match else 0.0

    def compute_quality_metrics(self) -> dict:
        cmd = [
            "ffmpeg", "-i", self.config.output_path, "-i", self.config.input_path,
            "-filter_complex", "lavfi.psnr=stats_file=psnr.log;lavfi.ssim=stats_file=ssim.log",
            "-f", "null", "-"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        psnr = self._parse_metric(result.stderr, r"average:([\d\.]+)")
        ssim = self._parse_metric(result.stderr, r"All:([\d\.]+)")
        return {"psnr": psnr, "ssim": ssim}


def convert_video(input_path=None, output_path=None, **kwargs):
    converter = GifConverter(input_path, output_path, **kwargs)
    return converter.convert()

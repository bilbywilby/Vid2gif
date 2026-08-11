Usage Guide
===========

CLI Execution
-------------

Convert video to GIF with standard parameters:

.. code-block:: bash

   vid2gif input.mp4 -o output.gif

Configure dithering, frame rate, width, and execute benchmarking:

.. code-block:: bash

   vid2gif input.mp4 -o output.gif --fps 20 --width 640 --dither floyd_steinberg --benchmark

Python API Usage
----------------

Programmatic video conversion:

.. code-block:: python

   from vid2gif.converter import GifConverter

   converter = GifConverter(input_path="input.mp4", output_path="output.gif")
   stats = converter.convert(fps=15, width=480, dither="sierra2_4a")

   metrics = converter.compute_quality_metrics()
   print(f"PSNR: {metrics['psnr']} dB | SSIM: {metrics['ssim']}")

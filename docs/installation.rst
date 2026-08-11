Installation
============

System Dependencies
-------------------

FFmpeg must be installed and accessible on your system PATH.

Linux (Ubuntu/Debian):

.. code-block:: bash

   sudo apt-get update && sudo apt-get install -y ffmpeg

macOS:

.. code-block:: bash

   brew install ffmpeg

Python Package
--------------

Install the stable release via PyPI:

.. code-block:: bash

   pip install vid2gif

Or install locally in editable mode for development:

.. code-block:: bash

   git clone https://github.com/USERNAME/vid2gif.git
   cd vid2gif
   pip install -e ".[dev]"

import os
import sys

sys.path.insert(0, os.path.abspath("../src"))

project = "vid2gif"
copyright = "2026, bilbywilby"
author = "bilbywilby"
release = "0.5.1"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "sphinx.ext.intersphinx",
    "sphinx_autodoc_typehints",
]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
}

napoleon_google_docstring = True
napoleon_numpy_docstring = False
autodoc_member_order = "bysource"

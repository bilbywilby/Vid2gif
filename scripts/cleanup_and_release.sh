#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/Vid2gif"

if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Directory $REPO_DIR does not exist." >&2
    exit 1
fi

cd "$REPO_DIR"

echo "=== 1. Cleaning legacy files and untracked artifacts ==="
git rm -f fix_repo.sh git_push.py setup_complete.sh 2>/dev/null || true
rm -f fix_repo.sh git_push.py setup_complete.sh

echo "=== 2. Updating repository metadata and dev configuration ==="
cat << 'CHANGELOG_EOF' > CHANGELOG.md
# Changelog

All notable changes to `vid2gif` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-08-15

### Fixed
- Stale `port.py` invocation in CI smoke test replaced with `vid2gif` CLI entry point.
- Corrected author metadata and remote repository tracking to `bilbywilby/Vid2gif`.

### Cleanup
- Removed duplicate `.github/workflows/ci.yml` in favor of consolidated `main.yml`.
- Purged stale shell backup files (`vid2gif.sh.backup`, `vid2gif.sh.fixed_backup`, `vid2gif.sh.v0.3.0.backup`).

## [0.4.0b1] - 2026-08-11

### Added
- Native Python conversion pipeline (`converter.py`) utilizing `ConversionConfig` data structures.
- Automated GIF quality metrics calculation and odd-width aspect ratio scaling handling.
- `pyproject.toml` setup with direct CLI console script entry point.

### Changed
- Deprecated legacy shell-script wrapper (`vid2gif.sh`) in favor of unified Python module.

## [0.3.0] - 2026-08-09

### Added
- Single-pass `ffmpeg` filtergraph using `split`, `palettegen`, `paletteuse`
- Encoding presets via `-p`: `web`, `social`, `quality`, `minimal`
- Color control via `-m` (2-256 colors)
- Loop count via `-l` (0 = infinite)
- Dither algorithms: `bayer`, `floyd_steinberg`, `sierra2`, `sierra2_4a`, `sierra3`, `burkes`, `atkinson`, `none`
- Dry-run mode (`-n`, `--dry-run`)
- Human-readable file sizing via `numfmt`

### Changed
- `-r` replaces `-f` for framerate (POSIX alignment)
- Structured `log()` / `die()` error handling
- In-memory filter graph (no temp palette files)

### Removed
- `vid2gif-1.sh`, `vid2gif-2.sh`, `README-3.md`, `vid2gif.pdf`

## [0.1.0] - 2026-08-09
- Initial release with two-stage palette generation
CHANGELOG_EOF

cat << 'PYPROJECT_EOF' > pyproject.toml
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "vid2gif"
version = "0.5.1"
authors = [
  { name = "bilbywilby", email = "bilbywilby@users.noreply.github.com" },
]
description = "Convert video files to optimized animated GIFs using FFmpeg"
readme = "README.md"
requires-python = ">=3.10"
classifiers = [
    "Programming Language :: Python :: 3",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
]
dependencies = [
    "numpy>=1.22.0,<3.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "twine>=4.0.0",
    "build>=0.10.0",
    "flake8>=6.0.0",
    "black>=23.9.1",
    "mypy>=1.5.1",
]

[project.scripts]
vid2gif = "vid2gif.cli:main"

[tool.pytest.ini_options]
testpaths = ["tests"]
PYPROJECT_EOF

echo "-e .[dev]" > requirements-dev.txt

echo "=== 3. Staging and committing changes ==="
git add CHANGELOG.md pyproject.toml requirements-dev.txt scripts/
if ! git diff-index --quiet HEAD --; then
    git commit -m "chore: clean up legacy scripts, update CHANGELOG for v0.5.1, and synchronize dev dependencies"
fi

echo "=== 4. Updating release tags and pushing to origin ==="
git tag -f -a v0.5.1 -m "Release v0.5.1"
git push origin main
git push origin v0.5.1 --force

echo "=== 5. Building wheels and source distribution ==="
if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

rm -rf dist/* build/* *.egg-info
python3 -m build

echo "=== 6. Uploading package to PyPI ==="
if [ -z "${PYPI_TOKEN:-}" ]; then
    echo "Error: PYPI_TOKEN environment variable is not set." >&2
    echo "Export PYPI_TOKEN before running or pass it inline." >&2
    exit 1
fi

TWINE_USERNAME="__token__" TWINE_PASSWORD="$PYPI_TOKEN" twine upload dist/*

echo "=== SUCCESS: vid2gif v0.5.1 published to PyPI and synchronized with GitHub ==="

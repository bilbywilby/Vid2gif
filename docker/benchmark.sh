#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-input_test.mp4}"
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found"
    exit 1
fi

echo "Running vid2gif benchmarks..."
for w in 320 480 640; do
    for f in 10 15 24; do
        OUT="bench_${w}_${f}fps.gif"
        vid2gif "$INPUT" -o "$OUT" --width "$w" --fps "$f" --benchmark
    done
done

echo "Complete!"
ls -lh bench_*.gif 2>/dev/null || true

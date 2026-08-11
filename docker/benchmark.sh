#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-input_test.mp4}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Benchmark input file '$INPUT_FILE' not found."
    exit 1
fi

echo "=========================================="
echo " Executing Automated Conversion Benchmark "
echo "=========================================="

for WIDTH in 320 480 640; do
    for FPS in 10 15 24; do
        OUTPUT="bench_${WIDTH}_${FPS}fps.gif"
        echo "Testing Width=${WIDTH}px, FPS=${FPS}..."
        vid2gif "$INPUT_FILE" -o "$OUTPUT" --width "$WIDTH" --fps "$FPS" --benchmark
    done
done

echo "Benchmark complete!"
ls -lh bench_*.gif 2>/dev/null || true

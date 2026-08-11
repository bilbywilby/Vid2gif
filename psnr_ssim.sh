#!/usr/bin/env bash
# psnr_ssim.sh — Compare video/GIF quality via PSNR and SSIM metrics

set -euo pipefail

REFERENCE="${1:-}"
DEGRADED="${2:-}"
FPS="${3:-15}"
SCALE="${4:-320:-1}"

[[ -z "$REFERENCE" || -z "$DEGRADED" ]] && { echo "Usage: $0 <ref> <degraded>" >&2; exit 1; }

PSNR_LOG=$(mktemp)
SSIM_LOG=$(mktemp)
trap 'rm -f "$PSNR_LOG" "$SSIM_LOG"' EXIT

ffmpeg -v warning -y -i "$REFERENCE" -i "$DEGRADED" -lavfi \
    "[0:v]fps=$FPS,scale=$SCALE:flags=lanczos,format=rgb24,split=2[ref1][ref2]; \
     [1:v]fps=$FPS,scale=$SCALE:flags=lanczos,format=rgb24,split=2[deg1][deg2]; \
     [ref1][deg1]psnr=f='$PSNR_LOG'; \
     [ref2][deg2]ssim=f='$SSIM_LOG'" \
    -f null - 2>&1 | tee /tmp/ffmpeg_debug.log

echo "=== QUALITY METRICS ==="
echo "PSNR Log contents:"
cat "$PSNR_LOG" 2>/dev/null | head -5 || echo "(empty)"
echo ""
echo "SSIM Log contents:"
cat "$SSIM_LOG" 2>/dev/null | head -5 || echo "(empty)"

# More robust parsing for typical FFmpeg output format
if [[ -s "$PSNR_LOG" ]]; then
    AVG_PSNR=$(awk '/psnr_avg:/ {gsub(/[^0-9.]/, "", $NF); sum+=$NF; n++} END {if(n>0) printf "%.2f", sum/n; else print "N/A"}' "$PSNR_LOG")
    echo "Average PSNR: ${AVG_PSNR} dB"
fi

if [[ -s "$SSIM_LOG" ]]; then
    AVG_SSIM=$(awk '/All:/ {match($0, /All:[0-9.]+/); val=substr($0, RSTART+4, RLENGTH-4); sum+=val; n++} END {if(n>0) printf "%.4f", sum/n; else print "N/A"}' "$SSIM_LOG")
    echo "Average SSIM: ${AVG_SSIM}"
fi

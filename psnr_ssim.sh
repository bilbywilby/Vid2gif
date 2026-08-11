#!/usr/bin/env bash
# psnr_ssim.sh — Compare video/GIF quality via PSNR and SSIM metrics
# POSIX-compliant (no GNU grep -oP dependency, dynamic field parsing)

set -euo pipefail

REFERENCE="$1"
DEGRADED="$2"
FPS="${3:-15}"
SCALE="${4:-320:-1}"
LOG_PREFIX="${5:-}"

[[ -f "$REFERENCE" ]] || { echo "error: reference not found: $REFERENCE" >&2; exit 1; }
[[ -f "$DEGRADED" ]] || { echo "error: degraded not found: $DEGRADED" >&2; exit 1; }

PSNR_LOG=$(mktemp "${TMPDIR:-/tmp}/vid2gif-psnr-XXXXXX")
SSIM_LOG=$(mktemp "${TMPDIR:-/tmp}/vid2gif-ssim-XXXXXX")
trap 'rm -f "$PSNR_LOG" "$SSIM_LOG"' EXIT

PSNR_LOG_ESC="${PSNR_LOG//:/\\:}"
SSIM_LOG_ESC="${SSIM_LOG//:/\\:}"

ffmpeg -v error -y \
    -i "$REFERENCE" -i "$DEGRADED" \
    -lavfi "\
        [0:v]fps=$FPS,scale=$SCALE:flags=lanczos,split=2[ref1][ref2]; \
        [1:v]fps=$FPS,scale=$SCALE:flags=lanczos,split=2[deg1][deg2]; \
        [ref1][deg1]psnr=f='${PSNR_LOG_ESC}'; \
        [ref2][deg2]ssim=f='${SSIM_LOG_ESC}'" \
    -f null - 2>&1

echo "---"
echo "PSNR Summary (${LOG_PREFIX:+$LOG_PREFIX - }$DEGRADED):"
if [[ -s "$PSNR_LOG" ]]; then
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^psnr_avg:/) {
                split($i, kv, ":");
                val = kv[2] + 0;
                if (val > 0) {
                    if (count == 0 || val < min) min = val;
                    if (count == 0 || val > max) max = val;
                    sum += val;
                    count++;
                }
            }
        }
    } 
    END {
        if (count > 0)
            printf "  avg: %.2f dB  min: %.2f dB  max: %.2f dB  frames: %d\n", sum/count, min, max, count;
        else
            print "  (no valid PSNR data)";
    }' "$PSNR_LOG"
else
    echo "  (no PSNR data)"
fi

echo ""
echo "SSIM Summary:"
if [[ -s "$SSIM_LOG" ]]; then
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^All:/) {
                split($i, kv, ":");
                val = kv[2] + 0;
                if (val > 0) {
                    if (count == 0 || val < min) min = val;
                    if (count == 0 || val > max) max = val;
                    sum += val;
                    count++;
                }
            }
        }
    } 
    END {
        if (count > 0)
            printf "  avg: %.4f  min: %.4f  max: %.4f  frames: %d\n", sum/count, min, max, count;
        else
            print "  (no valid SSIM data)";
    }' "$SSIM_LOG"
else
    echo "  (no SSIM data)"
fi

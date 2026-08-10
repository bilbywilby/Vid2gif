#!/usr/bin/env bash
REFERENCE="$1"
DEGRADED="$2"
FPS="${3:-15}"
SCALE="${4:-320:-1}"
ffmpeg -v warning -y -i "$REFERENCE" -i "$DEGRADED" -lavfi \
   "[0:v]fps=$FPS,scale=$SCALE:flags=lanczos,split=2[ref1][ref2]; \
    [1:v]fps=$FPS,scale=$SCALE:flags=lanczos,split=2[deg1][deg2]; \
    [ref1][deg1]psnr=f=_psnr.log; \
    [ref2][deg2]ssim=f=_ssim.log" \
   -f null -
echo "--- PSNR ---"; cat _psnr.log
echo "--- SSIM ---"; cat _ssim.log

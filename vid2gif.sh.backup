#!/usr/bin/env bash
# vid2gif.sh — convert video to an optimized GIF using ffmpeg's two-pass
# palette technique (palettegen + paletteuse).
#
# Usage:
#   vid2gif.sh -i input.mp4 -o output.gif [options]
#
# Options:
#   -i FILE       Input video (required)
#   -o FILE       Output GIF (default: <input>.gif)
#   -Q METHOD     Palette quantization method: octree (default) | mediancut | bayer
#   -F FPS        Output frame rate (default: 15)
#   -W WIDTH      Output width in px, height auto-scaled (default: source width)
#   -R BYTES      Target size in bytes; degrades quality/scale in steps to hit it
#   -T            Preserve transparency (alpha channel passthrough)
#   -S            Strip metadata from the output GIF
#   -C            Auto-crop letterbox/pillarbox bars before conversion
#   -B SECONDS    Benchmark smoke-test mode: run a quick preset sweep capped
#                 at SECONDS of wall time and print timing/size results
#   -h            Show this help text
#
# Exit codes: 0 success, 1 bad usage, 2 ffmpeg failure, 3 target size unreachable

set -euo pipefail

QUANT_METHOD="octree"
FPS=15
WIDTH=""
TARGET_BYTES=""
TRANSPARENCY=0
STRIP_METADATA=0
AUTO_CROP=0
BENCH_SECONDS=""
INPUT=""
OUTPUT=""

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

die() {
    echo "vid2gif: error: $*" >&2
    exit 2
}

require_ffmpeg() {
    command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found on PATH"
    command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found on PATH"
}

while getopts ":i:o:Q:F:W:R:B:TSCh" opt; do
    case "$opt" in
        i) INPUT="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        Q) QUANT_METHOD="$OPTARG" ;;
        F) FPS="$OPTARG" ;;
        W) WIDTH="$OPTARG" ;;
        R) TARGET_BYTES="$OPTARG" ;;
        B) BENCH_SECONDS="$OPTARG" ;;
        T) TRANSPARENCY=1 ;;
        S) STRIP_METADATA=1 ;;
        C) AUTO_CROP=1 ;;
        h) usage 0 ;;
        \?) die "unknown option: -$OPTARG" ;;
        :) die "option -$OPTARG requires an argument" ;;
    esac
done

pick_input_file() {
    # Streamlined media picker for interactive terminals, tried in order:
    #   1. Termux:API native Android file picker (best UX, needs the
    #      Termux:API companion app + `pkg install termux-api`)
    #   2. fzf fuzzy browser over common video locations
    #   3. plain numbered `select` menu (no extra dependencies)
    if command -v termux-storage-get >/dev/null 2>&1; then
        local dest="${TMPDIR:-/tmp}/vid2gif-picked-$$"
        echo "vid2gif: opening Android file picker..." >&2
        termux-storage-get "$dest" >/dev/null 2>&1 || true
        if [[ -f "$dest" ]]; then
            echo "$dest"
            return 0
        fi
        echo "vid2gif: no file selected via picker, falling back" >&2
    fi

    local search_dirs=("$HOME" "$HOME/storage/shared" "$HOME/storage/dcim" "$HOME/storage/movies" "$PWD")
    local -a existing_dirs=()
    for d in "${search_dirs[@]}"; do
        [[ -d "$d" ]] && existing_dirs+=("$d")
    done
    [[ ${#existing_dirs[@]} -gt 0 ]] || die "no searchable directories found; pass -i explicitly"

    local -a candidates=()
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find "${existing_dirs[@]}" -maxdepth 4 -type f \
        \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.avi' \) \
        -print0 2>/dev/null | sort -z -u)

    [[ ${#candidates[@]} -gt 0 ]] || die "no video files found under ${existing_dirs[*]}; pass -i explicitly"

    if command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "${candidates[@]}" | fzf --prompt="vid2gif> select input: " --preview 'ffprobe -hide_banner "{}" 2>&1 | head -20'
        return 0
    fi

    echo "Select input video:" >&2
    local f
    select f in "${candidates[@]}"; do
        [[ -n "$f" ]] && { echo "$f"; return 0; }
        echo "invalid selection, try again" >&2
    done
}

if [[ -z "$INPUT" ]]; then
    if [[ -t 0 && -z "$BENCH_SECONDS" ]]; then
        INPUT="$(pick_input_file)"
        [[ -n "$INPUT" ]] || die "no input selected"
    else
        usage 1
    fi
fi

[[ -f "$INPUT" ]] || die "input file not found: $INPUT"

case "$QUANT_METHOD" in
    octree|mediancut|bayer) ;;
    *) die "invalid quant method: $QUANT_METHOD (expected octree|mediancut|bayer)" ;;
esac

case "$QUANT_METHOD" in
    bayer)     DITHER_ALGO="bayer" ;;
    mediancut) DITHER_ALGO="floyd_steinberg" ;;
    octree)    DITHER_ALGO="sierra2_4a" ;;
esac

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT%.*}.gif"
fi

require_ffmpeg

build_filter() {
    local width="$1"
    local -a chain=()
    if [[ "$AUTO_CROP" -eq 1 ]]; then
        chain+=("cropdetect=24:16:0")
    fi
    chain+=("fps=${FPS}")
    if [[ -n "$width" ]]; then
        chain+=("scale=${width}:-1:flags=lanczos")
    fi
    local IFS=,
    echo "${chain[*]}"
}

convert_once() {
    local width="$1" out="$2"
    local filters palette
    filters="$(build_filter "$width")"
    palette="$(mktemp -t vid2gif-palette-XXXXXX.png)"
    trap 'rm -f "$palette"' RETURN

    local gen_extra=""
    [[ "$TRANSPARENCY" -eq 1 ]] && gen_extra="reserve_transparent=1:"

    ffmpeg -y -v error -i "$INPUT" \
        -vf "${filters},palettegen=stats_mode=diff:${gen_extra}max_colors=256" \
        "$palette" || die "palettegen pass failed"

    local use_extra=""
    [[ "$TRANSPARENCY" -eq 1 ]] && use_extra="alpha_threshold=128:"

    ffmpeg -y -v error -i "$INPUT" -i "$palette" \
        -lavfi "${filters}[x];[x][1:v]paletteuse=dither=${DITHER_ALGO}:${use_extra}diff_mode=rectangle" \
        "$out" || die "paletteuse pass failed"

    if [[ "$STRIP_METADATA" -eq 1 ]]; then
        local stripped
        stripped="$(mktemp -t vid2gif-strip-XXXXXX.gif)"
        ffmpeg -y -v error -i "$out" -map_metadata -1 "$stripped" && mv "$stripped" "$out"
    fi
}

run_benchmark() {
    local deadline=$((SECONDS + BENCH_SECONDS))
    local presets=("octree:480" "mediancut:480" "bayer:480" "octree:320")
    echo "config,size_bytes,time_ms"
    for preset in "${presets[@]}"; do
        [[ $SECONDS -ge $deadline ]] && break
        local q="${preset%%:*}" w="${preset##*:}"
        local tmp start end
        tmp="$(mktemp -t vid2gif-bench-XXXXXX.gif)"
        start=$(date +%s%3N)
        QUANT_METHOD="$q" convert_once "$w" "$tmp" || { rm -f "$tmp"; continue; }
        end=$(date +%s%3N)
        echo "${q}_${w}px,$(stat -c%s "$tmp"),$((end - start))"
        rm -f "$tmp"
    done
}

# Degrade quality/scale in three steps to hit a target byte size:
#   1. original width, chosen quant method
#   2. reduced width (75%), same quant method
#   3. reduced width (50%) + faster quant method (mediancut) + reduced fps
try_hit_target_size() {
    local base_width="$1"
    local attempt_widths=("$base_width" "$((base_width * 3 / 4))" "$((base_width / 2))")
    local i=0
    for w in "${attempt_widths[@]}"; do
        i=$((i + 1))
        if [[ "$i" -eq 3 ]]; then
            QUANT_METHOD="mediancut"
            FPS=$((FPS > 10 ? 10 : FPS))
        fi
        convert_once "$w" "$OUTPUT"
        local size
        size=$(stat -c%s "$OUTPUT")
        if [[ "$size" -le "$TARGET_BYTES" ]]; then
            echo "vid2gif: hit target size on attempt $i: ${size} bytes <= ${TARGET_BYTES}" >&2
            return 0
        fi
    done
    echo "vid2gif: warning: could not reach target size after 3 attempts (last: ${size} bytes)" >&2
    return 3
}

if [[ -n "$BENCH_SECONDS" ]]; then
    run_benchmark
    exit 0
fi

if [[ -n "$TARGET_BYTES" ]]; then
    src_width="${WIDTH:-$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$INPUT")}"
    try_hit_target_size "$src_width"
else
    convert_once "$WIDTH" "$OUTPUT"
fi

echo "vid2gif: wrote $OUTPUT"

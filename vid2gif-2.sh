#!/usr/bin/env bash
#
# vid2gif.sh — convert a video file to an optimized animated GIF
#
# Usage:
#   vid2gif.sh -i input.mp4 [-o output.gif] [-f fps] [-w width]
#              [-s start] [-t duration] [-d dither] [-c] [-n] [-v] [-h] [-V]
#
# Options:
#   -i  Input video file (required)
#   -o  Output GIF path (default: <input_basename>.gif)
#   -f  Frames per second, positive integer (default: 15)
#   -w  Output width in px, positive integer, height auto-scaled (default: 800)
#   -s  Start time, e.g. 00:00:05 or 5 (seconds) — trims from here
#   -t  Duration to encode, e.g. 00:00:10 or 10 (seconds)
#   -d  Dither algorithm passed to paletteuse (default: sierra2_4a)
#   -c  Compress the final GIF with gifsicle -O3 (requires gifsicle)
#   -n  Dry run — print the ffmpeg command without executing it
#   -v  Verbose — show ffmpeg's own progress output
#   -V  Print script version and exit
#   -h  Show this help
#
# Requires: ffmpeg (and optionally gifsicle for -c)
#
# Example:
#   vid2gif.sh -i demo.mp4 -o demo.gif -f 12 -w 900 -s 3 -t 8 -c

set -euo pipefail

readonly SCRIPT_VERSION="0.1.0-beta"
readonly SCRIPT_NAME="$(basename "$0")"

# ---- defaults ---------------------------------------------------------
INPUT=""
OUTPUT=""
FPS=15
WIDTH=800
START=""
DURATION=""
DITHER="sierra2_4a"
COMPRESS=0
DRY_RUN=0
VERBOSE=0

# ---- helpers ------------------------------------------------------------
log()  { printf '==> %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
    grep '^#' "$0" | sed -n '2,26p' | sed 's/^#//; s/^ //'
    exit "${1:-0}"
}

version() {
    printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
    exit 0
}

require_positive_int() {
    local name="$1" value="$2"
    [[ "$value" =~ ^[0-9]+$ ]] || die "$name must be a positive integer (got '$value')"
    [[ "$value" -gt 0 ]] || die "$name must be greater than zero"
}

cleanup() {
    [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"
}

# ---- argument parsing -----------------------------------------------------
while getopts ":i:o:f:w:s:t:d:cnvVh" opt; do
    case "$opt" in
        i) INPUT="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        f) FPS="$OPTARG" ;;
        w) WIDTH="$OPTARG" ;;
        s) START="$OPTARG" ;;
        t) DURATION="$OPTARG" ;;
        d) DITHER="$OPTARG" ;;
        c) COMPRESS=1 ;;
        n) DRY_RUN=1 ;;
        v) VERBOSE=1 ;;
        V) version ;;
        h) usage 0 ;;
        \?) die "Unknown option: -$OPTARG" ;;
        :)  die "Option -$OPTARG requires an argument" ;;
    esac
done

# ---- validation -----------------------------------------------------------
[[ -n "$INPUT" ]] || { echo "Error: input file is required (-i)" >&2; usage 1; }
[[ -f "$INPUT" ]] || die "input file '$INPUT' not found"
[[ -r "$INPUT" ]] || die "input file '$INPUT' is not readable"

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg is not installed or not on PATH"

require_positive_int "FPS (-f)" "$FPS"
require_positive_int "Width (-w)" "$WIDTH"

if [[ -z "$OUTPUT" ]]; then
    BASE="${INPUT%.*}"
    OUTPUT="${BASE}.gif"
fi

case "$OUTPUT" in
    *.gif) ;;
    *) log "Warning: output '$OUTPUT' does not end in .gif" ;;
esac

if [[ -e "$OUTPUT" && "$DRY_RUN" -eq 0 ]]; then
    log "Warning: '$OUTPUT' already exists and will be overwritten"
fi

SEEK_ARGS=()
[[ -n "$START" ]] && SEEK_ARGS+=(-ss "$START")

DURATION_ARGS=()
[[ -n "$DURATION" ]] && DURATION_ARGS+=(-t "$DURATION")

# ---- build filter graph ----------------------------------------------------
# Single-pass: generate palette and apply it in one ffmpeg invocation via
# a split filter, avoiding an intermediate palette file.
FILTER_GRAPH="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos[v];[v]split[v1][v2];[v1]palettegen[p];[v2][p]paletteuse=dither=${DITHER}"

FFMPEG_ARGS=(
    -y
    "${SEEK_ARGS[@]}"
    "${DURATION_ARGS[@]}"
    -i "$INPUT"
    -filter_complex "$FILTER_GRAPH"
)

if [[ "$VERBOSE" -eq 1 ]]; then
    FFMPEG_ARGS+=(-loglevel info -stats)
else
    FFMPEG_ARGS+=(-loglevel error -stats)
fi

FFMPEG_ARGS+=("$OUTPUT")

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'ffmpeg'
    printf ' %q' "${FFMPEG_ARGS[@]}"
    printf '\n'
    if [[ "$COMPRESS" -eq 1 ]]; then
        printf 'gifsicle -O3 --batch %q\n' "$OUTPUT"
    fi
    exit 0
fi

trap cleanup EXIT

log "Rendering GIF (${WIDTH}px @ ${FPS}fps, dither=${DITHER})..."
ffmpeg "${FFMPEG_ARGS[@]}"

if [[ "$COMPRESS" -eq 1 ]]; then
    if command -v gifsicle >/dev/null 2>&1; then
        log "Compressing with gifsicle -O3..."
        gifsicle -O3 --batch "$OUTPUT"
    else
        log "Warning: gifsicle not found on PATH, skipping compression (-c ignored)"
    fi
fi

if command -v numfmt >/dev/null 2>&1; then
    SIZE_BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
    SIZE=$(numfmt --to=iec-i --suffix=B "$SIZE_BYTES")
else
    SIZE=$(du -h "$OUTPUT" | awk '{print $1}')
fi

log "Done: $OUTPUT ($SIZE)"

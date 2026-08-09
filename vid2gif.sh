#!/usr/bin/env bash
set -euo pipefail

readonly VERSION="0.3.0"
readonly SCRIPT_NAME=$(basename "$0")

declare INPUT=""
declare OUTPUT=""
declare FPS=15
declare WIDTH=480
declare MAX_COLORS=256
declare LOOP_COUNT=0
declare DITHER="sierra2_4a"
declare START_TIME=""
declare DURATION=""
declare DRY_RUN=0
declare OPTIMIZE=0
declare VERBOSE=0
declare PRESET=""

readonly ALLOWED_DITHERS=("bayer" "floyd_steinberg" "sierra2" "sierra2_4a" "sierra3" "burkes" "atkinson" "none")

log_debug() { [[ $VERBOSE -eq 1 ]] && echo "[DEBUG] $(date '+%H:%M:%S') $*" >&2 || true; }
log_info() { echo "[INFO] $(date '+%H:%M:%S') $*" >&2; }
log_warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }
die() { log_error "$@"; exit 1; }

usage() {
    cat <<EOF
${SCRIPT_NAME} v${VERSION} - Convert video files to optimized GIFs

USAGE: ${SCRIPT_NAME} -i <input_video> [OPTIONS]

REQUIRED:
    -i <file>        Input video path

OPTIONS:
    -o <file>        Output GIF path (default: input_basename.gif)
    -s <time>        Start time (HH:MM:SS, MM:SS, or seconds)
    -t <time>        Duration (same formats)
    -r <fps>         Framerate (default: 15, range 1-60)
    -w <width>       Target width in pixels (default: 480, min 64)
    -m <colors>      Max colors 2-256 (default: 256)
    -l <loops>       Loop count 0=infinite (default: 0)
    -d <dither>      Dither: ${ALLOWED_DITHERS[*]} (default: sierra2_4a)
    -p <preset>      Preset: web, social, quality, minimal
    -O               Optimize with gifsicle if available
    -v               Verbose/debug mode
    -n, --dry-run    Display commands without executing
    -h, --help       Show help

EXAMPLES:
    ${SCRIPT_NAME} -i video.mp4 -o animation.gif
    ${SCRIPT_NAME} -i clip.mov -s 0:10 -t 5 -r 12 -w 640
    ${SCRIPT_NAME} -i movie.mkv -p social -O -v
EOF
}

time_to_seconds() {
    local time_str="$1"
    if [[ "$time_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$time_str"; return 0
    fi
    if [[ "$time_str" =~ ^([0-9]+):([0-5][0-9]):([0-5][0-9])(\.[0-9]+)?$ ]]; then
        local h="${BASH_REMATCH[1]}" m="${BASH_REMATCH[2]}" s="${BASH_REMATCH[3]}"
        echo "$h * 3600 + $m * 60 + $s" | bc -l; return 0
    fi
    if [[ "$time_str" =~ ^([0-5]?[0-9]):([0-5][0-9])(\.[0-9]+)?$ ]]; then
        local m="${BASH_REMATCH[1]}" s="${BASH_REMATCH[2]}"
        echo "$m * 60 + $s" | bc -l; return 0
    fi
    echo ""; return 1
}

apply_preset() {
    case "$1" in
        web)      WIDTH=640; FPS=12; MAX_COLORS=128; DITHER="floyd_steinberg" ;;
        social)   WIDTH=480; FPS=10; MAX_COLORS=96;  DITHER="sierra2_4a" ;;
        quality)  WIDTH=800; FPS=15; MAX_COLORS=256; DITHER="sierra2_4a" ;;
        minimal)  WIDTH=320; FPS=8;  MAX_COLORS=64;  DITHER="atkinson" ;;
        *) die "Unknown preset '$1'. Use: web, social, quality, minimal" ;;
    esac
    log_debug "Preset '$1' applied"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i) [[ -z "${2:-}" ]] && die "-i requires arg"; INPUT="$2"; shift 2 ;;
            -o) [[ -z "${2:-}" ]] && die "-o requires arg"; OUTPUT="$2"; shift 2 ;;
            -s) [[ -z "${2:-}" ]] && die "-s requires arg"; START_TIME="$2"; shift 2 ;;
            -t) [[ -z "${2:-}" ]] && die "-t requires arg"; DURATION="$2"; shift 2 ;;
            -r) [[ -z "${2:-}" ]] && die "-r requires arg"; FPS="$2"; shift 2 ;;
            -w) [[ -z "${2:-}" ]] && die "-w requires arg"; WIDTH="$2"; shift 2 ;;
            -m) [[ -z "${2:-}" ]] && die "-m requires arg"; MAX_COLORS="$2"; shift 2 ;;
            -l) [[ -z "${2:-}" ]] && die "-l requires arg"; LOOP_COUNT="$2"; shift 2 ;;
            -d) [[ -z "${2:-}" ]] && die "-d requires arg"; DITHER="$2"; shift 2 ;;
            -p) [[ -z "${2:-}" ]] && die "-p requires arg"; apply_preset "$2"; shift 2 ;;
            -O) OPTIMIZE=1; shift ;;
            -v) VERBOSE=1; shift ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1. Run '$SCRIPT_NAME --help'" ;;
        esac
    done
}

validate_inputs() {
    [[ -z "$INPUT" ]] && { usage; die "Input file (-i) required."; }
    [[ ! -f "$INPUT" ]] && die "Input not found: $INPUT"
    [[ ! -s "$INPUT" ]] && die "Input empty: $INPUT"
    
    validate_dither "$DITHER"
    [[ ! "$MAX_COLORS" =~ ^[0-9]+$ ]] && die "Invalid max colors: $MAX_COLORS"
    (( MAX_COLORS < 2 || MAX_COLORS > 256 )) && die "Colors must be 2-256"
    [[ ! "$LOOP_COUNT" =~ ^[0-9]+$ ]] && die "Invalid loop count: $LOOP_COUNT"
    [[ ! "$FPS" =~ ^[0-9]+$ ]] && die "Invalid fps: $FPS"
    (( FPS < 1 || FPS > 60 )) && die "Fps must be 1-60"
    [[ ! "$WIDTH" =~ ^[0-9]+$ ]] && die "Invalid width: $WIDTH"
    (( WIDTH < 64 )) && die "Width must be ≥64"
}

validate_dither() {
    local mode="$1"
    for d in "${ALLOWED_DITHERS[@]}"; do
        [[ "$d" == "$mode" ]] && return 0
    done
    die "Invalid dither '$mode'. Valid: ${ALLOWED_DITHERS[*]}"
}

check_deps() {
    command -v ffmpeg &>/dev/null || die "ffmpeg required but not found"
    [[ $OPTIMIZE -eq 1 ]] && command -v gifsicle &>/dev/null && log_info "gifsicle found, will optimize"
}

calc_size() {
    local bytes
    bytes=$(wc -c < "$1" 2>/dev/null || stat -c%s "$1")
    if (( bytes >= 1073741824 )); then
        printf "%.2f GB" "$(echo "$bytes/1073741824" | bc -l)"
    elif (( bytes >= 1048576 )); then
        printf "%.2f MB" "$(echo "$bytes/1048576" | bc -l)"
    elif (( bytes >= 1024 )); then
        printf "%.2f KB" "$(echo "$bytes/1024" | bc -l)"
    else
        printf "%d B" "$bytes"
    fi
}

resolve_paths() {
    if [[ -z "$OUTPUT" ]]; then
        OUTPUT="${INPUT%.gif}.gif"
    fi
    local dir
    dir=$(dirname "$OUTPUT")
    [[ ! -d "$dir" ]] && mkdir -p "$dir" && log_info "Created directory: $dir"
}

temp_cleanup() {
    for f in "${TEMP_FILES[@]:-}"; do
        [[ -f "$f" ]] && rm -f "$f"
    done
}

check_bounds() {
    local start="$1" dur="$2" total="$3"
    [[ -z "$total" || "$total" == "N/A" ]] && return 0
    
    if [[ -n "$start" ]]; then
        (( $(echo "$start >= $total" | bc -l) )) && warn "Start ($start s) > duration ($total s)"
    fi
    if [[ -n "$start" && -n "$dur" ]]; then
        local end
        end=$(echo "$start + $dur" | bc -l)
        (( $(echo "$end > $total" | bc -l) )) && warn "Segment ends beyond video duration"
    fi
}

run_palette() {
    local filter="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos,palettegen=max_colors=${MAX_COLORS}"
    local args=()
    [[ -n "$START_TIME" ]] && args+=("-ss" "$START_TIME")
    [[ -n "$DURATION" ]] && args+=("-t" "$DURATION")
    
    log_info "Generating palette..."
    ffmpeg -y -hide_banner -loglevel error "${args[@]}" -i "$INPUT" -vf "$filter" "$PALETTE_FILE" 2>&1 || die "Palette generation failed"
    log_info "Palette complete: $PALETTE_FILE"
}

run_convert() {
    local filter="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=${DITHER}"
    local args=()
    [[ -n "$START_TIME" ]] && args+=("-ss" "$START_TIME")
    [[ -n "$DURATION" ]] && args+=("-t" "$DURATION")
    
    log_info "Synthesizing GIF..."
    ffmpeg -y -hide_banner -loglevel error "${args[@]}" -i "$INPUT" -i "$PALETTE_FILE" -filter_complex "$filter" -loop "$LOOP_COUNT" "$OUTPUT" 2>&1 || die "GIF synthesis failed"
}

run_optimize() {
    command -v gifsicle &>/dev/null || { warn "gifsicle not found, skipping optimization"; return 0; }
    
    log_info "Optimizing with gifsicle..."
    gifsicle --batch -O3 --loopcount="$LOOP_COUNT" "$OUTPUT" 2>&1 || warn "Optimization failed, output preserved"
}

show_dry_run() {
    local base=()
    [[ -n "$START_TIME" ]] && base+=("-ss" "$START_TIME")
    [[ -n "$DURATION" ]] && base+=("-t" "$DURATION")
    
    echo ""
    echo "=== DRY RUN ==="
    echo ""
    echo "Palette: ffmpeg -y -hide_banner -loglevel error ${base[*]} -i '$INPUT' -vf '...' '$PALETTE_FILE'"
    echo "Convert: ffmpeg -y -hide_banner -loglevel error ${base[*]} -i '$INPUT' -i '$PALETTE_FILE' -filter_complex '...' -loop $LOOP_COUNT '$OUTPUT'"
    [[ $OPTIMIZE -eq 1 ]] && echo "Optimize: gifsicle --batch -O3 --loopcount=$LOOP_COUNT '$OUTPUT'"
    echo ""
    echo "Settings: ${WIDTH}px | ${FPS}fps | $MAX_COLORS colors | dither=$DITHER"
    [[ -n "$START_TIME" ]] && echo "Segment: $START_TIME (+${DURATION:-full})"
    echo ""
}

# --- Main ---

main() {
    TEMP_FILES=()
    trap temp_cleanup EXIT
    
    parse_args "$@"
    [[ -n "$PRESET" ]] || true  # apply_preset already called in parse_args
    
    validate_inputs
    check_deps
    
    PALETTE_FILE=$(mktemp "/tmp/vid2gif_palette_XXXXXX.png")
    TEMP_FILES+=("$PALETTE_FILE")
    
    resolve_paths
    
    local start_sec="" dur_sec="" vid_dur=""
    [[ -n "$START_TIME" ]] && start_sec=$(time_to_seconds "$START_TIME") || true
    [[ -n "$DURATION" ]] && dur_sec=$(time_to_seconds "$DURATION") || true
    
    if command -v ffprobe &>/dev/null; then
        vid_dur=$(ffprobe -v error -show_entries format=duration -of default=noprintwrappers=1:nokey=1 "$INPUT" 2>/dev/null || echo "")
        check_bounds "$start_sec" "$dur_sec" "$vid_dur"
    fi
    
    log_info "=== VID2GIF v${VERSION} ==="
    log_info "Input:  $INPUT ($(calc_size "$INPUT"))"
    log_info "Output: $OUTPUT"
    log_info "Config: ${WIDTH}px | ${FPS}fps | $MAX_COLORS colors | dither=$DITHER"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        show_dry_run
        exit 0
    fi
    
    run_palette
    run_convert
    
    [[ $OPTIMIZE -eq 1 ]] && run_optimize
    
    log_info "=== COMPLETE ==="
    log_info "Output: $OUTPUT ($(calc_size "$OUTPUT"))"
}

main "$@"

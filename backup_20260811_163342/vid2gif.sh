#!/usr/bin/env bash
# vid2gif.sh v0.4.0-beta — Convert video to optimized GIF using FFmpeg.
# Cross-platform compatible (Linux, macOS, BSD, CI containers)

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    echo "vid2gif: error: Bash 4.0 or higher is required (current: ${BASH_VERSION}). Install via 'brew install bash' on macOS." >&2
    exit 2
fi

VERSION="0.4.0-beta"

WIDTH=480
FPS=15
MAX_COLORS=256
LOOP_COUNT=0
DITHER="sierra2_4a"
TARGET_BYTES=""
TRANSPARENCY=0
STRIP_METADATA=0
AUTO_CROP=0
DRY_RUN=0
TWO_PASS=0
BENCH_SECONDS=""
START_TIME=""
DURATION=""
INPUT=""
OUTPUT=""
PRESET=""

declare -A P_FPS=( ["web"]=12 ["social"]=10 ["quality"]=15 ["minimal"]=8 )
declare -A P_WIDTH=( ["web"]=480 ["social"]=480 ["quality"]=800 ["minimal"]=320 )
declare -A P_COLORS=( ["web"]=128 ["social"]=96 ["quality"]=256 ["minimal"]=64 )
declare -A P_DITHER=( ["web"]="floyd_steinberg" ["social"]="sierra2_4a" ["quality"]="sierra2_4a" ["minimal"]="atkinson" )

VALID_DITHERS=("sierra2_4a" "floyd_steinberg" "bayer" "sierra2" "sierra3" "burkes" "atkinson" "none")

usage() {
    cat << 'EOF'
vid2gif.sh — Convert video to animated GIF via FFmpeg.

Usage:
  vid2gif.sh -i input.mp4 -o output.gif [options]

Options:
  -i FILE       Input video file
  -o FILE       Output GIF path (default: <input>.gif)
  -w WIDTH      Output width in px (default: 480)
  -f FPS        Frame rate 1-60 (default: 15)
  -c COLORS     Palette color limit 2-256 (default: 256)
  -l LOOPS      Loop count, 0=infinite (default: 0)
  -d DITHER     Dithering algorithm (default: sierra2_4a)
  -p PRESET     Preset: web|social|quality|minimal
  -s START      Start timestamp (HH:MM:SS or seconds)
  -t DURATION   Duration to encode
  -R BYTES      Target output size in bytes
  -n            Dry-run: display commands without execution
  -T            Preserve transparency (forces two-pass)
  -S            Strip metadata
  -C            Auto-crop letterboxing
  -B SECONDS    Benchmark mode execution time ceiling
  --two-pass    Force two-pass rendering
  --version     Display version and exit
EOF
    exit "${1:-0}"
}

die() {
    echo "vid2gif: error: $*" >&2
    exit 2
}

warn() {
    echo "vid2gif: warning: $*" >&2
}

info() {
    echo "vid2gif: $*" >&2
}

require_ffmpeg() {
    command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found on PATH"
    command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found on PATH"
}

valid_dither() {
    local d="$1"
    for v in "${VALID_DITHERS[@]}"; do
        [[ "$d" == "$v" ]] && return 0
    done
    return 1
}

apply_preset() {
    local p="$1"
    if [[ -z "${P_FPS[$p]:-}" ]]; then
        die "unknown preset: $p"
    fi
    [[ -z "${WIDTH_SET:-}" ]]   && WIDTH="${P_WIDTH[$p]}"
    [[ -z "${FPS_SET:-}" ]]     && FPS="${P_FPS[$p]}"
    [[ -z "${COLORS_SET:-}" ]]  && MAX_COLORS="${P_COLORS[$p]}"
    [[ -z "${DITHER_SET:-}" ]]  && DITHER="${P_DITHER[$p]}"
}

pick_input_file() {
    if command -v termux-storage-get >/dev/null 2>&1; then
        local dest="${TMPDIR:-/tmp}/vid2gif-picked-$$"
        termux-storage-get "$dest" >/dev/null 2>&1 || true
        if [[ -f "$dest" ]]; then
            echo "$dest"
            return 0
        fi
    fi

    local search_dirs=("${HOME}" "$PWD")
    local -a candidates=()
    local -A seen=()

    while IFS= read -r -d '' f; do
        if [[ -z "${seen["$f"]:-}" ]]; then
            seen["$f"]=1
            candidates+=("$f")
        fi
    done < <(find "${search_dirs[@]}" -maxdepth 3 -type f \
        \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' \) \
        -print0 2>/dev/null)

    [[ ${#candidates[@]} -gt 0 ]] || die "no input files found"

    if command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "${candidates[@]}" | fzf --prompt="vid2gif> "
        return 0
    fi

    echo "${candidates[0]}"
}

get_file_size() {
    local file="$1"
    if stat -c%s "$file" 2>/dev/null; then
        return 0
    fi
    stat -f%z "$file" 2>/dev/null || echo 0
}

get_time_ms() {
    local ms
    ms=$(date +%s%3N 2>/dev/null)
    if [[ "$ms" =~ ^[0-9]+$ ]]; then
        echo "$ms"
    else
        if command -v python3 >/dev/null 2>&1; then
            python3 -c 'import time; print(int(time.time() * 1000))'
        else
            echo "$(( $(date +%s) * 1000 ))"
        fi
    fi
}

make_temp_file() {
    local suffix="${1:-}"
    local tmpdir="${TMPDIR:-/tmp}"
    local base
    base="$(mktemp "${tmpdir}/vid2gif-XXXXXX")"
    if [[ -n "$suffix" ]]; then
        mv "$base" "${base}${suffix}"
        echo "${base}${suffix}"
    else
        echo "$base"
    fi
}

build_filter() {
    local width="$1"
    local -a chain=()

    [[ "$AUTO_CROP" -eq 1 ]] && chain+=("cropdetect=24:16:0")
    chain+=("fps=${FPS}")
    [[ -n "$width" && "$width" -gt 0 ]] && chain+=("scale=${width}:-2:flags=lanczos")

    local IFS=,
    echo "${chain[*]}"
}

convert_single_pass() {
    local width="$1" out="$2"
    local filters graph

    filters="$(build_filter "$width")"
    graph="${filters},split[s0][s1];[s0]palettegen=max_colors=${MAX_COLORS}[p];[s1][p]paletteuse=dither=${DITHER}"

    local -a cmd=(ffmpeg -y -v error)
    [[ -n "$START_TIME" ]]  && cmd+=(-ss "$START_TIME")
    [[ -n "$DURATION" ]]    && cmd+=(-t "$DURATION")
    cmd+=(-i "$INPUT" -lavfi "$graph" -loop "$LOOP_COUNT" "$out")

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] ${cmd[*]}"
        return 0
    fi

    "${cmd[@]}" || die "single-pass conversion failed"
}

convert_two_pass() {
    local width="$1" out="$2"
    local filters palette palette_esc

    filters="$(build_filter "$width")"
    palette="$(make_temp_file ".png")"
    trap 'rm -f "${palette:-}"' RETURN

    palette_esc="${palette//:/\\:}"

    local gen_extra=""
    [[ "$TRANSPARENCY" -eq 1 ]] && gen_extra="reserve_transparent=1:"

    local -a gen_cmd=(ffmpeg -y -v error)
    [[ -n "$START_TIME" ]]  && gen_cmd+=(-ss "$START_TIME")
    [[ -n "$DURATION" ]]    && gen_cmd+=(-t "$DURATION")
    gen_cmd+=(-i "$INPUT" -vf "${filters},palettegen=stats_mode=diff:${gen_extra}max_colors=${MAX_COLORS}" "$palette_esc")

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] pass-1: ${gen_cmd[*]}"
    else
        "${gen_cmd[@]}" || die "palettegen pass failed"
    fi

    local use_extra=""
    [[ "$TRANSPARENCY" -eq 1 ]] && use_extra="alpha_threshold=128:"

    local -a use_cmd=(ffmpeg -y -v error)
    [[ -n "$START_TIME" ]]  && use_cmd+=(-ss "$START_TIME")
    [[ -n "$DURATION" ]]    && use_cmd+=(-t "$DURATION")
    use_cmd+=(-i "$INPUT" -i "$palette_esc"
              -lavfi "${filters}[x];[x][1:v]paletteuse=dither=${DITHER}:${use_extra}diff_mode=rectangle"
              -loop "$LOOP_COUNT" "$out")

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] pass-2: ${use_cmd[*]}"
        return 0
    fi

    "${use_cmd[@]}" || die "paletteuse pass failed"
}

convert_once() {
    local width="$1" out="$2"

    if [[ "$TWO_PASS" -eq 1 || "$TRANSPARENCY" -eq 1 ]]; then
        convert_two_pass "$width" "$out"
    else
        convert_single_pass "$width" "$out"
    fi

    if [[ "$STRIP_METADATA" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
        local stripped
        stripped="$(make_temp_file ".gif")"
        if ffmpeg -y -v error -i "$out" -map_metadata -1 "$stripped" 2>/dev/null; then
            mv "$stripped" "$out"
        else
            warn "metadata stripping failed; keeping original"
            rm -f "$stripped"
        fi
    fi
}

run_benchmark() {
    local deadline=$((SECONDS + BENCH_SECONDS))
    local presets=("sierra2_4a:480" "floyd_steinberg:480" "bayer:480" "sierra2_4a:320")
    echo "config,size_bytes,time_ms"
    for preset in "${presets[@]}"; do
        [[ $SECONDS -ge $deadline ]] && break
        local d="${preset%%:*}" w="${preset##*:}"
        local tmp start end
        tmp="$(make_temp_file ".gif")"
        start=$(get_time_ms)
        DITHER="$d" convert_single_pass "$w" "$tmp" || { rm -f "$tmp"; continue; }
        end=$(get_time_ms)
        echo "${d}_${w}px,$(get_file_size "$tmp"),$((end - start))"
        rm -f "$tmp"
    done
    exit 0
}

try_hit_target_size() {
    local base_width="$1"
    local attempt_widths=("${base_width}" "$((base_width * 3 / 4))" "$((base_width / 2))")
    local i=0 size
    for w in "${attempt_widths[@]}"; do
        i=$((i + 1))
        if [[ "$i" -eq 3 ]]; then
            DITHER="floyd_steinberg"
            FPS=$((FPS > 10 ? 10 : FPS))
        fi
        convert_once "$w" "$OUTPUT"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            return 0
        fi
        size=$(get_file_size "$OUTPUT")
        if [[ "$size" -gt 0 && "$size" -le "$TARGET_BYTES" ]]; then
            info "hit target on attempt $i: ${size} bytes <= ${TARGET_BYTES}"
            return 0
        fi
    done
    warn "could not reach target after 3 attempts (last: ${size:-0} bytes)"
    return 3
}

PROCESSED_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --two-pass) TWO_PASS=1; shift ;;
        --version)  echo "vid2gif $VERSION"; exit 0 ;;
        --)         shift; PROCESSED_ARGS+=("$@"); break ;;
        --*)        die "unknown option: $1 (use -h for help)" ;;
        *)          PROCESSED_ARGS+=("$1"); shift ;;
    esac
done

set -- "${PROCESSED_ARGS[@]+"${PROCESSED_ARGS[@]}"}"

while getopts ":i:o:w:f:c:l:d:p:s:t:R:B:nTSCh" opt; do
    case "$opt" in
        i) INPUT="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        w) WIDTH="$OPTARG"; WIDTH_SET=1 ;;
        f) FPS="$OPTARG"; FPS_SET=1 ;;
        c) MAX_COLORS="$OPTARG"; COLORS_SET=1 ;;
        l) LOOP_COUNT="$OPTARG" ;;
        d) DITHER="$OPTARG"; DITHER_SET=1 ;;
        p) PRESET="$OPTARG" ;;
        s) START_TIME="$OPTARG" ;;
        t) DURATION="$OPTARG" ;;
        R) TARGET_BYTES="$OPTARG" ;;
        B) BENCH_SECONDS="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        T) TRANSPARENCY=1 ;;
        S) STRIP_METADATA=1 ;;
        C) AUTO_CROP=1 ;;
        h) usage 0 ;;
        \?) die "unknown option: -$OPTARG (use -h for help)" ;;
        :)  die "option -$OPTARG requires an argument" ;;
    esac
done

[[ -n "$PRESET" ]] && apply_preset "$PRESET"

valid_dither "$DITHER" || die "invalid dither: $DITHER (expected: ${VALID_DITHERS[*]})"

[[ "$MAX_COLORS" =~ ^[0-9]+$ ]] || die "colours must be a number"
(( MAX_COLORS >= 2 && MAX_COLORS <= 256 )) || die "colours must be 2-256, got $MAX_COLORS"
(( FPS >= 1 && FPS <= 60 )) || die "fps must be 1-60, got $FPS"
(( LOOP_COUNT >= 0 )) || die "loop count must be >= 0"

if [[ -z "$INPUT" ]]; then
    if [[ -t 0 && -z "$BENCH_SECONDS" ]]; then
        INPUT="$(pick_input_file)"
        [[ -n "$INPUT" ]] || die "no input selected"
    else
        usage 1
    fi
fi
[[ -f "$INPUT" ]] || die "input file not found: $INPUT"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT%.*}.gif"
fi

require_ffmpeg

if [[ -n "$BENCH_SECONDS" ]]; then
    run_benchmark
fi

if [[ -n "$TARGET_BYTES" ]]; then
    src_width="${WIDTH:-$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$INPUT")}"
    try_hit_target_size "$src_width"
    exit $?
fi

convert_once "$WIDTH" "$OUTPUT"

if [[ "$DRY_RUN" -eq 0 ]]; then
    size=$(get_file_size "$OUTPUT")
    info "wrote $OUTPUT ($size bytes)"
fi

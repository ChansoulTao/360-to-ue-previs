#!/bin/bash
set -Eeuo pipefail

# ============================================================
# 360 TO UE PREVIS
# macOS / Apple Silicon
#
# User input:
#   1 / 2 / 5 FPS
#   One final Y/N confirmation
#
# After confirmation the pipeline is unattended.
# ============================================================


# ------------------------------------------------------------
# Local private config
# ------------------------------------------------------------

CONFIG_FILE="$HOME/.360-to-ue-previs.conf"

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"


# Finder-launched .command files may have a minimal PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

PIPELINE="${PIPELINE:-$HOME/Downloads/colmap-360-rig-pipeline}"

BRUSH="${BRUSH:-/Applications/brush-app-aarch64-apple-darwin/brush_app}"

RUNS_DIR="${RUNS_DIR:-$HOME/Movies/360-to-ue-previs-runs}"


NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

NTFY_TOPIC="${NTFY_TOPIC:-}"


BRUSH_STEPS="${BRUSH_STEPS:-15000}"

BRUSH_RES="${BRUSH_RES:-2560}"

BRUSH_EXPORT_EVERY="${BRUSH_EXPORT_EVERY:-5000}"


PYTHON="$PIPELINE/.venv/bin/python"

RECONSTRUCT="$PIPELINE/reconstruct_360.py"


NAME="unknown"

LABEL="unknown"

PHASE="Startup"

NOTIFICATIONS_ARMED=0

LOG_FILE=""


# ============================================================
# Notifications
# ============================================================

notify_ntfy() {

    [[ -z "$NTFY_TOPIC" ]] && return 0

    command -v curl >/dev/null 2>&1 || return 0

    curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -H "Title: $1" \
        -H "Priority: $2" \
        -H "Tags: $3" \
        -d "$4" \
        "$NTFY_SERVER/$NTFY_TOPIC" \
        >/dev/null 2>&1 || true
}


on_exit() {

    local code=$?

    trap - EXIT

    if [[ $code -ne 0 && "$NOTIFICATIONS_ARMED" -eq 1 ]]; then

        notify_ntfy \
            "360 to UE Previs Failed" \
            "high" \
            "warning,movie_camera" \
            "Job: ${NAME:-unknown}
Mode: ${LABEL:-unknown}
Phase: ${PHASE:-unknown}
Exit code: $code

Check process.log on the Mac."

    fi

    exit "$code"
}


trap on_exit EXIT


fatal() {

    echo ""

    echo "ERROR: $*" >&2

    return 1
}


# ============================================================
# Choose video
# ============================================================

choose_video() {

    if [[ $# -ge 1 && -f "$1" ]]; then

        printf '%s\n' "$1"

        return 0

    fi


    command -v osascript >/dev/null 2>&1 || return 1


    osascript -e \
        'POSIX path of (choose file with prompt "Choose a full 2:1 equirectangular MP4/MOV")'
}


# ============================================================
# Dependency checks
# ============================================================

PHASE="Dependency check"


for cmd in ffmpeg ffprobe shasum stat df tee
do

    command -v "$cmd" >/dev/null 2>&1 \
        || fatal "$cmd not found"

done


[[ -d "$PIPELINE" ]] \
    || fatal "Pipeline not found: $PIPELINE"


[[ -x "$PYTHON" ]] \
    || fatal "Pipeline Python not found: $PYTHON"


[[ -f "$RECONSTRUCT" ]] \
    || fatal "reconstruct_360.py not found: $RECONSTRUCT"


[[ -x "$BRUSH" ]] \
    || fatal "Brush not found: $BRUSH"


"$PYTHON" -c \
'import pycolmap, cv2, PIL, scipy, tqdm' \
>/dev/null 2>&1 \
    || fatal "Pipeline Python dependencies are incomplete"


# Confirm upstream CLI is still compatible.

RECON_HELP="$("$PYTHON" "$RECONSTRUCT" --help 2>&1)"


for required in \
    "--images" \
    "--output" \
    "--matcher" \
    "--render-type"
do

    grep -q -- "$required" <<<"$RECON_HELP" \
        || fatal \
        "reconstruct_360.py no longer supports $required"

done


# Confirm Brush CLI is still compatible.

BRUSH_HELP="$("$BRUSH" --help 2>&1)"


for required in \
    "--total-steps" \
    "--max-resolution" \
    "--export-path" \
    "--export-name"
do

    grep -q -- "$required" <<<"$BRUSH_HELP" \
        || fatal \
        "Brush no longer supports $required"

done


BRUSH_EXPORT_EVERY_SUPPORTED=0


if grep -q -- "--export-every" <<<"$BRUSH_HELP"; then

    BRUSH_EXPORT_EVERY_SUPPORTED=1

fi


# ============================================================
# Video input
# ============================================================

PHASE="Input selection"


VIDEO="$(choose_video "${1:-}")" \
    || fatal "No video selected"


[[ -f "$VIDEO" ]] \
    || fatal "Video not found: $VIDEO"


BASENAME="$(basename "$VIDEO")"

NAME="${BASENAME%.*}"


SAFE_NAME="$(
    printf '%s' "$NAME" |
    tr ' ' '_' |
    tr -cd '[:alnum:]_.-'
)"


[[ -n "$SAFE_NAME" ]] \
    || SAFE_NAME="scan"


# ============================================================
# Inspect input
# ============================================================

PHASE="Preflight"


DURATION="$(
    ffprobe \
        -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
)"


WIDTH="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=width \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
)"


HEIGHT="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=height \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
)"


SOURCE_FPS="$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=avg_frame_rate \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
)"


[[ "$DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]] \
    || fatal "Could not read video duration"


[[ "$WIDTH" =~ ^[0-9]+$ ]] \
    || fatal "Could not read video width"


[[ "$HEIGHT" =~ ^[0-9]+$ ]] \
    || fatal "Could not read video height"


[[ "$WIDTH" -eq $((HEIGHT * 2)) ]] \
    || fatal \
    "Input is ${WIDTH}x${HEIGHT}; expected exact 2:1 equirectangular video"


DURATION_INT="$(printf '%.0f' "$DURATION")"

MINUTES=$((DURATION_INT / 60))

SECONDS=$((DURATION_INT % 60))


clear


echo "=============================================="
echo "          360 -> UE PREVIS PREFLIGHT"
echo "=============================================="

echo "File:        $BASENAME"

printf "Duration:    %02d:%02d\n" \
    "$MINUTES" \
    "$SECONDS"

echo "Resolution:  ${WIDTH} x ${HEIGHT}"

echo "Source FPS:  $SOURCE_FPS"

echo "360 format:  2:1 OK"


if [[ -n "$NTFY_TOPIC" ]]; then

    echo "ntfy:        ON"

else

    echo "ntfy:        OFF"

fi


# ============================================================
# FPS selection
# ============================================================

echo ""

echo "Choose extraction density:"

echo "  [1] 1 FPS"

echo "  [2] 2 FPS"

echo "  [5] 5 FPS"

echo ""


read -r -p \
    "Choose [1/2/5] (default 2): " \
    FPS_CHOICE


FPS_CHOICE="${FPS_CHOICE:-2}"


case "$FPS_CHOICE" in

    1|2|5)

        ;;


    *)

        fatal \
        "Invalid FPS choice: $FPS_CHOICE"

        ;;

esac


LABEL="${FPS_CHOICE}FPS"


# ============================================================
# Estimate workload
# ============================================================

PANOS="$(
    "$PYTHON" \
        - \
        "$DURATION" \
        "$FPS_CHOICE" <<'PY'

import sys

print(
    max(
        1,
        round(
            float(sys.argv[1]) *
            float(sys.argv[2])
        )
    )
)

PY
)"


VIEWS=$((PANOS * 12))


read -r \
    COLMAP_LOW \
    COLMAP_HIGH \
    BRUSH_EST <<< "$(
        "$PYTHON" \
            - \
            "$VIEWS" \
            "$BRUSH_STEPS" \
            "$BRUSH_RES" <<'PY'

import sys


views = int(sys.argv[1])

steps = int(sys.argv[2])

res = int(sys.argv[3])


# Intentionally broad.
# COLMAP runtime becomes highly scene dependent
# with large datasets.

if views <= 3500:

    low = 10
    high = 40

elif views <= 7000:

    low = 30
    high = 180

elif views <= 12000:

    low = 90
    high = 360

else:

    low = 180
    high = 720


# Baseline:
# ~2976 views
# 15k steps
# 2560 px
# ~56 min on the tested M3 Pro.

brush = max(
    20,
    round(
        56 *
        max(
            0.45,
            (views / 2976) ** 0.45
        ) *
        (steps / 15000) *
        (res / 2560) ** 1.2
    )
)


print(
    low,
    high,
    brush
)

PY
    )"


TOTAL_LOW=$((COLMAP_LOW + BRUSH_EST))

TOTAL_HIGH=$((COLMAP_HIGH + BRUSH_EST))


# ============================================================
# Stable job identity / Resume
# ============================================================

mkdir -p "$RUNS_DIR"


FREE_KB="$(
    df -Pk "$RUNS_DIR" |
    awk 'NR==2 {print $4}'
)"


FREE_GB=$((FREE_KB / 1024 / 1024))


FILE_SIZE="$(
    stat -f '%z' "$VIDEO"
)"


FILE_MTIME="$(
    stat -f '%m' "$VIDEO"
)"


SOURCE_ID="$(
    printf '%s' \
        "$BASENAME|$FILE_SIZE|$FILE_MTIME|$FPS_CHOICE" |
    shasum -a 256 |
    awk '{print substr($1,1,10)}'
)"


JOB_ROOT="$RUNS_DIR/${SAFE_NAME}_${FPS_CHOICE}fps_${SOURCE_ID}"


FRAMES_DIR="$JOB_ROOT/frames"

COLMAP_DIR="$JOB_ROOT/colmap"

DATASET="$COLMAP_DIR/brush-dataset"

STATE_DIR="$JOB_ROOT/state"

LOG_FILE="$JOB_ROOT/process.log"


OUTPUT_DIR="$(dirname "$VIDEO")/UE_PREVIS_OUTPUT"


OUTPUT_NAME="${SAFE_NAME}_${FPS_CHOICE}fps_${BRUSH_STEPS}s_${BRUSH_RES}px_UE.ply"


FINAL_PLY="$OUTPUT_DIR/$OUTPUT_NAME"


FRAMES_DONE="$STATE_DIR/frames.done"

COLMAP_DONE="$STATE_DIR/colmap.done"


RESUME_TEXT="New job"


[[ -f "$FRAMES_DONE" ]] \
    && RESUME_TEXT="Resume after frame extraction"


[[ -f "$COLMAP_DONE" && -d "$DATASET" ]] \
    && RESUME_TEXT="Resume from Brush"


[[ -s "$FINAL_PLY" ]] \
    && RESUME_TEXT="Final PLY already exists"


# ============================================================
# Preflight summary
# ============================================================

echo ""

echo "Mode:                $LABEL"

echo "Estimated panoramas: ~$PANOS"

echo "Estimated views:     ~$VIEWS"

echo "Brush:               $BRUSH_STEPS steps @ $BRUSH_RES px"

echo "Estimated COLMAP:    ~${COLMAP_LOW}-${COLMAP_HIGH} min"

echo "Estimated Brush:     ~${BRUSH_EST} min"

echo "Estimated total:     ~${TOTAL_LOW}-${TOTAL_HIGH} min"

echo "Free disk:           ~${FREE_GB} GB"

echo "Resume state:        $RESUME_TEXT"

echo "Job folder:          $JOB_ROOT"


if (( FREE_GB < 15 )); then

    fatal \
    "Less than 15 GB free on the work volume"

elif (( FREE_GB < 30 )); then

    echo \
    "WARNING: less than 30 GB free. Large jobs may run out of space."

fi


if (( VIEWS > 6000 )); then

    echo \
    "WARNING: LARGE DATASET. Runtime may be several hours."

fi


if [[ -s "$FINAL_PLY" ]]; then

    echo ""

    echo "Final PLY already exists:"

    echo "$FINAL_PLY"

    echo "Nothing to do."


    open "$OUTPUT_DIR" \
        >/dev/null 2>&1 || true


    exit 0

fi


# ============================================================
# The ONLY final confirmation
# ============================================================

echo ""


read -r -p \
    "Start processing? [Y/N]: " \
    GO


case "$GO" in

    y|Y)

        ;;


    *)

        echo "Cancelled."

        exit 0

        ;;

esac


# ============================================================
# NO MORE USER INPUT AFTER THIS POINT
# ============================================================

mkdir -p \
    "$JOB_ROOT" \
    "$STATE_DIR" \
    "$OUTPUT_DIR"


# Log everything from here forward.

exec > >(
    tee -a "$LOG_FILE"
) 2>&1


NOTIFICATIONS_ARMED=1


notify_ntfy \
    "360 to UE Previs Started" \
    "default" \
    "rocket,movie_camera" \
    "Job: $NAME
Mode: $LABEL
Panoramas: ~$PANOS
Virtual views: ~$VIEWS
Resume: $RESUME_TEXT
Estimated total: ~$TOTAL_LOW-$TOTAL_HIGH min"


echo ""

echo "=============================================="

echo "JOB STARTED"

echo "=============================================="


date


echo "Source: $VIDEO"

echo "Job:    $JOB_ROOT"

echo "Log:    $LOG_FILE"


# ============================================================
# 1 / 3
# Extract frames
# ============================================================

if [[ ! -f "$FRAMES_DONE" ]]; then

    PHASE="Panorama extraction"


    rm -rf "$FRAMES_DIR"

    mkdir -p "$FRAMES_DIR"


    echo ""

    echo "=============================================="

    echo "1/3  EXTRACTING 360 PANORAMAS"

    echo "=============================================="


    ffmpeg \
        -hide_banner \
        -y \
        -i "$VIDEO" \
        -vf "fps=$FPS_CHOICE" \
        -q:v 2 \
        "$FRAMES_DIR/frame_%06d.jpg"


    ACTUAL_PANOS="$(
        find "$FRAMES_DIR" \
            -maxdepth 1 \
            -type f \
            -name 'frame_*.jpg' |
        wc -l |
        tr -d ' '
    )"


    (( ACTUAL_PANOS >= 8 )) \
        || fatal \
        "Only $ACTUAL_PANOS panoramas were extracted"


    printf '%s\n' \
        "$ACTUAL_PANOS" \
        > "$STATE_DIR/panorama_count.txt"


    touch "$FRAMES_DONE"

else

    ACTUAL_PANOS="$(
        cat "$STATE_DIR/panorama_count.txt" \
        2>/dev/null || true
    )"


    if [[ ! "$ACTUAL_PANOS" =~ ^[0-9]+$ ]]; then

        ACTUAL_PANOS="$(
            find "$FRAMES_DIR" \
                -maxdepth 1 \
                -type f \
                -name 'frame_*.jpg' |
            wc -l |
            tr -d ' '
        )"

    fi


    (( ACTUAL_PANOS >= 8 )) \
        || fatal \
        "Saved frame stage is incomplete"


    echo ""

    echo \
    "1/3  Frames already complete — skipping extraction."

fi


EXPECTED_VIEWS=$((ACTUAL_PANOS * 12))


echo "Panoramas: $ACTUAL_PANOS"

echo "Expected virtual views: $EXPECTED_VIEWS"


# ============================================================
# 2 / 3
# COLMAP reconstruction
#
# IMPORTANT:
# We call the upstream non-interactive reconstruct_360.py.
#
# It performs:
# - 12-view virtual rig generation
# - COLMAP
# - best model selection
# - prepare_brush_dataset()
#
# No Spanish [s/N] confirmations exist here.
# ============================================================

if [[ ! -f "$COLMAP_DONE" ]]; then

    PHASE="COLMAP reconstruction"


    if [[ -e "$COLMAP_DIR" ]]; then

        echo \
        "Removing incomplete previous COLMAP output..."


        rm -rf "$COLMAP_DIR"

    fi


    echo ""

    echo "=============================================="

    echo "2/3  COLMAP 360 RECONSTRUCTION"

    echo "=============================================="


    START_COLMAP="$(date +%s)"


    if command -v caffeinate >/dev/null 2>&1; then

        caffeinate \
            -i \
            "$PYTHON" \
            "$RECONSTRUCT" \
            --images "$FRAMES_DIR" \
            --output "$COLMAP_DIR" \
            --matcher sequential \
            --render-type perspective_overlapping

    else

        "$PYTHON" \
            "$RECONSTRUCT" \
            --images "$FRAMES_DIR" \
            --output "$COLMAP_DIR" \
            --matcher sequential \
            --render-type perspective_overlapping

    fi


    END_COLMAP="$(date +%s)"


    COLMAP_MIN=$(( (END_COLMAP - START_COLMAP) / 60 ))


    [[ -f "$DATASET/sparse/0/cameras.bin" ]] \
        || fatal \
        "Brush cameras.bin missing after reconstruction"


    [[ -f "$DATASET/sparse/0/images.bin" ]] \
        || fatal \
        "Brush images.bin missing after reconstruction"


    [[ -f "$DATASET/sparse/0/points3D.bin" ]] \
        || fatal \
        "Brush points3D.bin missing after reconstruction"


    printf '%s\n' \
        "$COLMAP_MIN" \
        > "$STATE_DIR/colmap_minutes.txt"


    touch "$COLMAP_DONE"

else

    COLMAP_MIN="$(
        cat "$STATE_DIR/colmap_minutes.txt" \
        2>/dev/null || echo 0
    )"


    echo ""

    echo \
    "2/3  COLMAP already complete — skipping reconstruction."

fi


# ============================================================
# Verify reconstruction quality
# ============================================================

read -r \
    REG_IMAGES \
    SPARSE_POINTS <<< "$(
        "$PYTHON" \
            - \
            "$DATASET/sparse/0" <<'PY'

import sys

import pycolmap


model = pycolmap.Reconstruction(
    sys.argv[1]
)


print(
    model.num_reg_images(),
    model.num_points3D()
)

PY
    )"


REG_PERCENT="$(
    "$PYTHON" \
        - \
        "$REG_IMAGES" \
        "$EXPECTED_VIEWS" <<'PY'

import sys


registered = int(
    sys.argv[1]
)


expected = max(
    1,
    int(
        sys.argv[2]
    )
)


print(
    f"{100.0 * registered / expected:.1f}"
)

PY
)"


echo \
"Registered views: $REG_IMAGES / $EXPECTED_VIEWS ($REG_PERCENT%)"


echo \
"Sparse points:    $SPARSE_POINTS"


notify_ntfy \
    "COLMAP Complete - Brush Starting" \
    "default" \
    "white_check_mark,computer" \
    "Job: $NAME
Mode: $LABEL
COLMAP: ${COLMAP_MIN} min
Registered: $REG_IMAGES / $EXPECTED_VIEWS ($REG_PERCENT%)
Sparse points: $SPARSE_POINTS
Brush starting: $BRUSH_STEPS steps @ $BRUSH_RES px"


# ============================================================
# 3 / 3
# Brush
# ============================================================

PHASE="Brush training"


echo ""

echo "=============================================="

echo "3/3  BRUSH TRAINING"

echo "=============================================="


BRUSH_ARGS=(

    --total-steps "$BRUSH_STEPS"

    --max-resolution "$BRUSH_RES"

    --export-path "$OUTPUT_DIR"

    --export-name "$OUTPUT_NAME"

)


if [[ \
    "$BRUSH_EXPORT_EVERY_SUPPORTED" -eq 1 \
    && "$BRUSH_EXPORT_EVERY" =~ ^[0-9]+$ \
    && "$BRUSH_EXPORT_EVERY" -gt 0 \
]]; then

    BRUSH_ARGS+=(
        --export-every "$BRUSH_EXPORT_EVERY"
    )


    echo \
    "Brush autosave interval: $BRUSH_EXPORT_EVERY steps"

fi


START_BRUSH="$(date +%s)"


if command -v caffeinate >/dev/null 2>&1; then

    caffeinate \
        -i \
        "$BRUSH" \
        "${BRUSH_ARGS[@]}" \
        "$DATASET"

else

    "$BRUSH" \
        "${BRUSH_ARGS[@]}" \
        "$DATASET"

fi


END_BRUSH="$(date +%s)"


BRUSH_MIN_ACTUAL=$(( (END_BRUSH - START_BRUSH) / 60 ))


[[ -s "$FINAL_PLY" ]] \
    || fatal \
    "Brush finished but final PLY was not created: $FINAL_PLY"


# ============================================================
# PLY quality check
# ============================================================

SPLAT_COUNT="$(
    "$PYTHON" \
        - \
        "$FINAL_PLY" <<'PY'

import re

import sys


count = None


with open(
    sys.argv[1],
    "rb"
) as file:

    for _ in range(250):

        line = file.readline()


        if not line:

            break


        text = (
            line.decode(
                "ascii",
                errors="ignore"
            )
            .strip()
        )


        match = re.match(
            r"element\s+vertex\s+(\d+)",
            text
        )


        if match:

            count = int(
                match.group(1)
            )


        if text == "end_header":

            break


print(
    count
    if count is not None
    else "unknown"
)

PY
)"


QUALITY_WARNINGS=()


if [[ "$SPLAT_COUNT" =~ ^[0-9]+$ ]]; then

    if (( SPLAT_COUNT < 10000 )); then

        QUALITY_WARNINGS+=(
            "CRITICAL: unusually low splat count ($SPLAT_COUNT)"
        )

    elif (( SPLAT_COUNT < 50000 )); then

        QUALITY_WARNINGS+=(
            "Low splat count ($SPLAT_COUNT); inspect in Brush before UE"
        )

    fi

fi


if [[ "$REG_IMAGES" =~ ^[0-9]+$ ]] \
    && (( REG_IMAGES * 100 < EXPECTED_VIEWS * 80 ))
then

    QUALITY_WARNINGS+=(
        "Only $REG_PERCENT% of expected virtual views registered"
    )

fi


# ============================================================
# Complete
# ============================================================

PHASE="Complete"


echo ""

echo "=============================================="

echo "             PREVIS COMPLETE"

echo "=============================================="


echo "COLMAP:          ${COLMAP_MIN} min"

echo "Brush:           ${BRUSH_MIN_ACTUAL} min"

echo "Registered:      $REG_IMAGES / $EXPECTED_VIEWS ($REG_PERCENT%)"

echo "Sparse points:   $SPARSE_POINTS"

echo "Final splats:    $SPLAT_COUNT"

echo "Output:          $FINAL_PLY"

echo "Log:             $LOG_FILE"


QUALITY_TEXT="Quality checks passed."

PRIORITY="default"

TAGS="white_check_mark,movie_camera"


if (( ${#QUALITY_WARNINGS[@]} > 0 )); then

    PRIORITY="high"

    TAGS="warning,movie_camera"


    QUALITY_TEXT="$(
        printf '%s; ' \
            "${QUALITY_WARNINGS[@]}"
    )"


    echo ""

    echo "QUALITY WARNING:"


    printf \
        ' - %s\n' \
        "${QUALITY_WARNINGS[@]}"

else

    echo \
    "Quality check:   PASS"

fi


notify_ntfy \
    "360 to UE Previs Complete" \
    "$PRIORITY" \
    "$TAGS" \
    "Job: $NAME
Mode: $LABEL
COLMAP: ${COLMAP_MIN} min
Brush: ${BRUSH_MIN_ACTUAL} min
Registered: $REG_IMAGES / $EXPECTED_VIEWS ($REG_PERCENT%)
Sparse points: $SPARSE_POINTS
Final splats: $SPLAT_COUNT
Output: $OUTPUT_NAME

$QUALITY_TEXT"


open "$OUTPUT_DIR" \
    >/dev/null 2>&1 || true


exit 0
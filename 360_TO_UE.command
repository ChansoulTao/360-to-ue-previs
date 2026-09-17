#!/bin/bash
set -e

PIPELINE="$HOME/Downloads/colmap-360-rig-pipeline"
BRUSH="/Applications/brush-app-aarch64-apple-darwin/brush_app"

# ---------- local private config ----------
CONFIG_FILE="$HOME/.360-to-ue-previs.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# ---------- ntfy notifications ----------
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-}"

notify_ntfy() {
    [ -z "$NTFY_TOPIC" ] && return 0

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

notify_failure() {
    code=$?
    trap - ERR

    notify_ntfy \
        "360 to UE Previs Failed" \
        "high" \
        "warning" \
        "Job: ${NAME:-unknown}
Preset: ${LABEL:-unknown}
Exit code: $code

Check the Mac Terminal for details."

    exit "$code"
}

trap notify_failure ERR

clear
echo "=============================================="
echo "          360 → UE PREVIS V2"
echo "=============================================="
echo ""

# ---------- dependency checks ----------
for cmd in ffmpeg ffprobe python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd not found."
        read -n 1 -s -r -p "Press any key to close..."
        exit 1
    fi
done

if [ ! -d "$PIPELINE" ]; then
    echo "ERROR: Pipeline not found:"
    echo "$PIPELINE"
    exit 1
fi

if [ ! -x "$BRUSH" ]; then
    echo "ERROR: Brush not found:"
    echo "$BRUSH"
    exit 1
fi

source "$PIPELINE/.venv/bin/activate"

# ---------- video input ----------
if [ -n "$1" ]; then
    VIDEO="$1"
else
    echo "Drag your Insta360 Studio exported MP4/MOV here:"
    echo ""
    read -r VIDEO
    VIDEO="${VIDEO%\"}"
    VIDEO="${VIDEO#\"}"
    VIDEO="${VIDEO%\'}"
    VIDEO="${VIDEO#\'}"
fi

if [ ! -f "$VIDEO" ]; then
    echo "ERROR: Video not found:"
    echo "$VIDEO"
    exit 1
fi

BASENAME="$(basename "$VIDEO")"
NAME="${BASENAME%.*}"

# ---------- inspect source ----------
DURATION=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO")

WIDTH=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width \
    -of csv=s=x:p=0 "$VIDEO")

HEIGHT=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=height \
    -of csv=s=x:p=0 "$VIDEO")

SOURCE_FPS=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO")

DURATION_INT=$(printf "%.0f" "$DURATION")

MINUTES=$((DURATION_INT / 60))
SECONDS=$((DURATION_INT % 60))

# ---------- 2:1 validation ----------
EXPECTED_WIDTH=$((HEIGHT * 2))

clear
echo "=============================================="
echo "          360 → UE PREVIS PREFLIGHT"
echo "=============================================="
echo ""
echo "File:        $BASENAME"
printf "Duration:    %02d:%02d\n" "$MINUTES" "$SECONDS"
echo "Resolution:  ${WIDTH} × ${HEIGHT}"
echo "Source FPS:  $SOURCE_FPS"

if [ "$WIDTH" -ne "$EXPECTED_WIDTH" ]; then
    echo ""
    echo "⚠ WARNING: Input is not 2:1 equirectangular."
    echo "Expected width: $EXPECTED_WIDTH"
    echo "Actual width:   $WIDTH"
    echo ""
    echo "Export a full 360° 2:1 video from Insta360 Studio."
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
else
    echo "360 Format:  2:1 ✓"
fi

echo ""
echo "Choose preset:"
echo ""
echo "[1] FAST"
echo "    ~120 panoramas"
echo "    Quick blocking / rough scout"
echo ""
echo "[2] NORMAL  ← Recommended"
echo "    ~250 panoramas"
echo "    DP previs / CineCamera"
echo ""
echo "[3] QUALITY"
echo "    ~500 panoramas"
echo "    Higher-detail location"
echo ""
read -r -p "Preset [1/2/3]: " PRESET

case "$PRESET" in
    1)
        LABEL="FAST"
        TARGET=120
        BRUSH_STEPS=7500
        BRUSH_RES=1920
        ;;
    3)
        LABEL="QUALITY"
        TARGET=500
        BRUSH_STEPS=20000
        BRUSH_RES=3072
        ;;
    *)
        LABEL="NORMAL"
        TARGET=250
        BRUSH_STEPS=15000
        BRUSH_RES=2560
        ;;
esac

# ---------- calculate adaptive extraction FPS ----------
EXTRACT_FPS=$(python3 - <<PY
duration=float("$DURATION")
target=float("$TARGET")
fps=target/duration
fps=max(0.05, fps)
print(f"{fps:.4f}")
PY
)

PANOS=$(python3 - <<PY
duration=float("$DURATION")
fps=float("$EXTRACT_FPS")
print(round(duration*fps))
PY
)

VIEWS=$((PANOS * 12))

# ---------- initial ETA model ----------
# Conservative estimates calibrated from this M3 Pro workflow.
BRUSH_MIN=$(python3 - <<PY
steps=$BRUSH_STEPS
res=$BRUSH_RES
base=76.25
estimate=base*(steps/15000)*(res/2560)**1.35
print(round(estimate))
PY
)

COLMAP_LOW=$(python3 - <<PY
views=$VIEWS
# deliberately conservative nonlinear estimate
print(max(5, round(8*(views/276)**1.25)))
PY
)

COLMAP_HIGH=$(python3 - <<PY
views=$VIEWS
print(max(10, round(12*(views/276)**1.35)))
PY
)

TOTAL_LOW=$((COLMAP_LOW + BRUSH_MIN))
TOTAL_HIGH=$((COLMAP_HIGH + BRUSH_MIN))

echo ""
echo "=============================================="
echo "                 PREFLIGHT"
echo "=============================================="
echo ""
echo "Preset:             $LABEL"
echo "Adaptive FPS:       $EXTRACT_FPS"
echo "Target panoramas:   ~$PANOS"
echo "Virtual views:      ~$VIEWS"
echo ""
echo "Brush:"
echo "  Steps:            $BRUSH_STEPS"
echo "  Max resolution:   $BRUSH_RES"
echo ""
echo "Estimated COLMAP:   ${COLMAP_LOW}–${COLMAP_HIGH} min"
echo "Estimated Brush:    ~${BRUSH_MIN} min"
echo "----------------------------------------------"
echo "Estimated total:    ~${TOTAL_LOW}–${TOTAL_HIGH} min"
echo ""

if [ "$VIEWS" -gt 6000 ]; then
    echo "⚠ LARGE DATASET"
    echo "Consider NORMAL or FAST unless you need extra detail."
    echo ""
fi

read -r -p "Start processing? [Y/N]: " GO

case "$GO" in
    y|Y) ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

notify_ntfy \
    "360 to UE Previs Started" \
    "default" \
    "rocket,movie_camera" \
    "Job: $NAME
Preset: $LABEL

Panoramas: ~$PANOS
Virtual views: ~$VIEWS

Brush: $BRUSH_STEPS steps @ $BRUSH_RES px

Estimated total:
~$((COLMAP_LOW + BRUSH_MIN))-$((COLMAP_HIGH + BRUSH_MIN)) min"


# ---------- workspace ----------
WORK_VIDEO="$PIPELINE/${NAME}_V2.mp4"

echo ""
echo "Preparing workspace..."

if [ "$VIDEO" != "$WORK_VIDEO" ]; then
    cp "$VIDEO" "$WORK_VIDEO"
fi

FRAMES_DIR="$PIPELINE/${NAME}_V2-frames"
OUTPUT_ROOT="$PIPELINE/${NAME}_V2-colmap"
OUTPUT_DIR="$(dirname "$VIDEO")/UE_PREVIS_OUTPUT"

mkdir -p "$FRAMES_DIR"
mkdir -p "$OUTPUT_DIR"

# ---------- extract panoramas ----------
echo ""
echo "=============================================="
echo "1/3  EXTRACTING 360 PANORAMAS"
echo "=============================================="
echo ""
echo "Target: ~$PANOS panoramas"

rm -f "$FRAMES_DIR"/frame_*.jpg

ffmpeg -hide_banner -y \
    -i "$WORK_VIDEO" \
    -vf "fps=$EXTRACT_FPS" \
    -q:v 2 \
    "$FRAMES_DIR/frame_%06d.jpg"

ACTUAL_PANOS=$(find "$FRAMES_DIR" -name "frame_*.jpg" | wc -l | tr -d ' ')

echo ""
echo "Extracted: $ACTUAL_PANOS panoramas"

# ---------- COLMAP ----------
echo ""
echo "=============================================="
echo "2/3  COLMAP 360 RECONSTRUCTION"
echo "=============================================="
echo ""

START_COLMAP=$(date +%s)

python "$PIPELINE/panorama_sfm_4_1_1.py" \
    --input_image_path "$FRAMES_DIR" \
    --output_path "$OUTPUT_ROOT" \
    --matcher sequential \
    --mapper incremental \
    --pano_render_type perspective_overlapping

END_COLMAP=$(date +%s)
COLMAP_SEC=$((END_COLMAP - START_COLMAP))
COLMAP_MIN=$((COLMAP_SEC / 60))

# ---------- build Brush-compatible dataset ----------
DATASET="$OUTPUT_ROOT/brush-dataset"

echo ""
echo "Preparing Brush dataset..."

# panorama_sfm creates the COLMAP reconstruction but does not create
# the Brush wrapper directory, so build it here.
rm -rf "$DATASET"
mkdir -p "$DATASET"

if [ ! -d "$OUTPUT_ROOT/images" ]; then
    echo "ERROR: COLMAP images directory not found:"
    echo "$OUTPUT_ROOT/images"
    exit 1
fi

if [ ! -d "$OUTPUT_ROOT/sparse/0" ]; then
    echo "ERROR: COLMAP sparse model not found:"
    echo "$OUTPUT_ROOT/sparse/0"
    exit 1
fi

ln -s "$OUTPUT_ROOT/images" "$DATASET/images"
ln -s "$OUTPUT_ROOT/sparse" "$DATASET/sparse"

cat > "$DATASET/README.txt" <<EOF
Brush-ready COLMAP dataset

Selected source model: $OUTPUT_ROOT/sparse/0
Panoramas: $ACTUAL_PANOS
EOF

echo "Brush dataset ready:"
echo "$DATASET"

echo ""
echo "COLMAP complete: ${COLMAP_MIN} min"

# ---------- Brush ----------
echo ""
echo "=============================================="
notify_ntfy \
    "COLMAP Complete - Brush Starting" \
    "default" \
    "white_check_mark,computer" \
    "Job: $NAME
Preset: $LABEL

COLMAP: ${COLMAP_MIN} min

Brush starting:
$BRUSH_STEPS steps @ $BRUSH_RES px"

echo "3/3  BRUSH TRAINING"
echo "=============================================="
echo ""

OUTPUT_NAME="${NAME}_${LABEL}_UE.ply"

START_BRUSH=$(date +%s)

"$BRUSH" \
    --total-steps "$BRUSH_STEPS" \
    --max-resolution "$BRUSH_RES" \
    --export-path "$OUTPUT_DIR" \
    --export-name "$OUTPUT_NAME" \
    "$DATASET"

END_BRUSH=$(date +%s)
BRUSH_SEC=$((END_BRUSH - START_BRUSH))
BRUSH_MIN_ACTUAL=$((BRUSH_SEC / 60))

TOTAL_SEC=$((END_BRUSH - START_COLMAP))
TOTAL_MIN=$((TOTAL_SEC / 60))

echo ""
echo "=============================================="
echo "             PREVIS COMPLETE ✓"
echo "=============================================="
echo ""
echo "COLMAP:   ${COLMAP_MIN} min"
echo "Brush:    ${BRUSH_MIN_ACTUAL} min"
echo "Total:    ${TOTAL_MIN} min"
echo ""
echo "Output:"
echo "$OUTPUT_DIR/$OUTPUT_NAME"
echo ""
echo "UE:"
echo "1. Open GaussianScout"
echo "2. Drag PLY into Content Drawer"
echo "3. Add HarmonyActor"
echo "4. Calibrate against 2.5 m reference"
echo "5. Start CineCamera previs"
echo ""

notify_ntfy \
    "360 to UE Previs Complete" \
    "default" \
    "white_check_mark,movie_camera" \
    "Job: $NAME
Preset: $LABEL

COLMAP: ${COLMAP_MIN} min
Brush: ${BRUSH_MIN_ACTUAL} min
Total: ${TOTAL_MIN} min

Output: $OUTPUT_NAME

Ready for Unreal Engine."

open "$OUTPUT_DIR"

read -n 1 -s -r -p "Press any key to close..."

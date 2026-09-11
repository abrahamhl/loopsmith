#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FFMPEG="ffmpeg"
if command -v ffmpeg.exe &>/dev/null; then FFMPEG="ffmpeg.exe"; fi

echo "Generating long synthetic benchmark clip (2400 frames)..."
$FFMPEG -y -v error -f lavfi -i "testsrc=duration=100:size=640x360:rate=24" -c:v libx264 -crf 18 "bench_1.mp4"
$FFMPEG -y -v error -f lavfi -i "testsrc=duration=100:size=640x360:rate=24" -c:v libx264 -crf 18 "bench_2.mp4"

echo "Running benchmark..."
START=$(date +%s%N)
../loopsmith.sh --dry-run --json bench.json --duration 199 bench_1.mp4 bench_2.mp4 > bench.log
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

echo "=== BENCHMARK REPORT ==="
echo "Analysis Duration: ${ELAPSED}ms"
# It tries all combinations of 3 frames across 2 seams.
echo "Number of candidate combinations: Evaluated recursive drops"
TARGET=$(grep "objetivo" bench.log | awk '{print $5}')
ACTUAL=$(grep -oP '(?<="actual_frames": )[0-9]+' bench.json)
echo "Target frames: $TARGET"
echo "Actual frames: $ACTUAL"
echo "Chosen seams scores:"
grep "ratio" bench.json | tr ',' '\n' | grep ratio

rm bench_1.mp4 bench_2.mp4 bench.json bench.log

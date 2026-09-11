#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FFMPEG="ffmpeg"
if command -v ffmpeg.exe &>/dev/null; then FFMPEG="ffmpeg.exe"; fi

echo "Generating synthetic fixtures..."

$FFMPEG -y -v error -f lavfi -i "testsrc=duration=15:size=640x360:rate=24" -c:v libx264 -crf 18 "good_1.mp4"
$FFMPEG -y -v error -f lavfi -i "testsrc=duration=15:size=640x360:rate=24" -c:v libx264 -crf 18 "good_2.mp4"

$FFMPEG -y -v error -f lavfi -i "color=c=red:duration=15:size=640x360:rate=24" -c:v libx264 -crf 18 "bad_1.mp4"
$FFMPEG -y -v error -f lavfi -i "color=c=blue:duration=15:size=640x360:rate=24" -c:v libx264 -crf 18 "bad_2.mp4"

$FFMPEG -y -v error -f lavfi -i "testsrc=duration=15:size=640x360:rate=30" -c:v libx264 -crf 18 "mismatched_30fps.mp4"

$FFMPEG -y -v error -f lavfi -i "testsrc=duration=5:size=640x360:rate=24" -c:v libx264 -crf 18 "short.mp4"

cp good_1.mp4 "good file 1.mp4"
cp good_2.mp4 "buen archivo 🚀.mp4"

echo "Done generating fixtures."

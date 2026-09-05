#!/usr/bin/env bash
set -euo pipefail

echo "Generating good seams (continuous motion)..."
ffmpeg -y -v error -f lavfi -i "smptebars=duration=15:size=1280x720:rate=24" -vf "scroll=h=0.05" good_1.mp4
ffmpeg -y -v error -f lavfi -i "smptebars=duration=15:size=1280x720:rate=24" -vf "scroll=h=0.05" good_2.mp4

echo "Generating bad seams (jump cuts)..."
ffmpeg -y -v error -f lavfi -i "color=c=red:duration=15:size=1280x720:rate=24" bad_1.mp4
ffmpeg -y -v error -f lavfi -i "color=c=blue:duration=15:size=1280x720:rate=24" bad_2.mp4

echo "Done."

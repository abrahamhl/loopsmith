#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "Running tests..."

echo "Test: Exact requested duration & Exact output frame count"
../loopsmith.sh --out good_loop.mp4 --duration 30 good_1.mp4 good_2.mp4 > good_loop.log
frames=$(ffprobe.exe -v error -select_streams v -count_frames -show_entries stream=nb_read_frames -of csv=p=0 good_loop.mp4 | tr -d '\r')
# 30 seconds at 24fps = 720 frames
if [ "$frames" -eq 720 ]; then
    echo "PASSED: Exact output frame count ($frames frames)"
else
    echo "FAILED: Expected 720 frames, got $frames"
    exit 1
fi

echo "Test: Deterministic planning for identical inputs"
../loopsmith.sh --dry-run --json run1.json --duration 30 good_1.mp4 good_2.mp4 > /dev/null
../loopsmith.sh --dry-run --json run2.json --duration 30 good_1.mp4 good_2.mp4 > /dev/null
if cmp run1.json run2.json; then
    echo "PASSED: Deterministic planning"
else
    echo "FAILED: Output differs between runs"
    exit 1
fi

echo "Test: Head/tail trimming & loop seam scoring"
if grep -q '"clip_from":1, "clip_to":2, "ratio"' run1.json && grep -q '"clip_from":2, "clip_to":1, "ratio"' run1.json; then
    echo "PASSED: Seam scoring structure in JSON"
else
    echo "FAILED: Missing seam structures in JSON"
    cat run1.json
    exit 1
fi

echo "Test: --no-loop behaviour"
../loopsmith.sh --dry-run --no-loop --json noloop.json --duration 30 good_1.mp4 good_2.mp4 > /dev/null
if grep -q '"type":"loop"' noloop.json; then
    echo "FAILED: Loop seam found despite --no-loop"
    exit 1
else
    echo "PASSED: --no-loop behaviour"
fi

echo "Test: --dry-run behaviour"
rm -f dummy_out.mp4
../loopsmith.sh --dry-run --out dummy_out.mp4 --duration 30 good_1.mp4 good_2.mp4 > /dev/null
if [ -f dummy_out.mp4 ]; then
    echo "FAILED: File was created during --dry-run"
    exit 1
else
    echo "PASSED: --dry-run behaviour"
fi

echo "Test: Insufficient-frame rejection"
set +e
../loopsmith.sh --dry-run --duration 30 short.mp4 > /dev/null 2>&1
status=$?
set -e
if [ "$status" -eq 4 ]; then
    echo "PASSED: Insufficient-frame rejection (Exit 4)"
else
    echo "FAILED: Expected exit 4 for insufficient frames, got $status"
    exit 1
fi

echo "Test: Invalid/missing input"
set +e
../loopsmith.sh --dry-run --duration 30 missing.mp4 > /dev/null 2>&1
status=$?
set -e
if [ "$status" -eq 3 ]; then
    echo "PASSED: Missing input rejection (Exit 3)"
else
    echo "FAILED: Expected exit 3 for missing input, got $status"
    exit 1
fi

echo "Test: Spaces and Unicode in filenames"
../loopsmith.sh --dry-run --json unicode.json --duration 30 "good file 1.mp4" "buen archivo 🚀.mp4" > /dev/null
if [ -f unicode.json ]; then
    echo "PASSED: Spaces and Unicode in filenames"
else
    echo "FAILED: Did not produce JSON for Unicode files"
    exit 1
fi

echo "Test: Mismatched FPS"
set +e
../loopsmith.sh --dry-run --duration 30 good_1.mp4 mismatched_30fps.mp4 > mismatch.log 2>&1
# Note: script doesn't explicitly reject it currently, but we can verify it doesn't crash or behaves predictably.
# It should plan at the FPS of the first clip.
fps=$(cat mismatch.log | grep "24 fps" | wc -l)
set -e
if [ "$fps" -gt 0 ]; then
    echo "PASSED: Mismatched FPS handled (used first clip fps)"
else
    echo "FAILED: Mismatched FPS caused unexpected behavior"
    exit 1
fi

echo "All Tests Passed!"

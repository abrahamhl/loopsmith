#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "Running tests..."

echo "Test: Candidate seam enumeration"
../loopsmith.sh --dry-run --duration 30 good_1.mp4 good_2.mp4 > good_dry.log 2>&1 || true
if ! grep -q "midiendo costuras..." good_dry.log; then
    echo "FAILED: Did not find 'midiendo costuras...' in output"
    cat good_dry.log
    exit 1
fi
echo "PASSED: Candidate seam enumeration"

echo "Test: Final duration correctness & Frame/timebase correctness"
../loopsmith.sh --out good_loop.mp4 --duration 30 good_1.mp4 good_2.mp4 > good_loop.log
frames=$(ffprobe -v error -select_streams v -count_frames -show_entries stream=nb_read_frames -of csv=p=0 good_loop.mp4)
if [ "$frames" -eq 720 ]; then
    echo "PASSED: Final duration correctness ($frames frames)"
else
    echo "FAILED: Expected 720 frames, got $frames"
    exit 1
fi

echo "Test: Seam score determinism"
../loopsmith.sh --dry-run --duration 30 good_1.mp4 good_2.mp4 > run1.log
../loopsmith.sh --dry-run --duration 30 good_1.mp4 good_2.mp4 > run2.log
if cmp run1.log run2.log; then
    echo "PASSED: Seam score determinism"
else
    echo "FAILED: Output differs between runs"
    exit 1
fi

echo "Test: Weak-seam detection"
../loopsmith.sh --dry-run --duration 30 bad_1.mp4 bad_2.mp4 > bad_dry.log
if grep -q "REVISAR" bad_dry.log; then
    echo "PASSED: Weak-seam detection (Found REVISAR)"
else
    echo "FAILED: Did not find REVISAR warning on bad seam"
    exit 1
fi

echo "Test: Failure on invalid input"
if ../loopsmith.sh --dry-run missing.mp4 2>/dev/null; then
    echo "FAILED: Expected failure on missing input"
    exit 1
else
    echo "PASSED: Failure on invalid input"
fi

echo "All Tests Passed!"

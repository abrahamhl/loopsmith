# LoopSmith: Engineering Case Study

## 1. CURRENT TRUTH
Generative video models (Kling, Runway, Veo) frequently return videos with inconsistent frame counts and fractional durations. Additionally, when looping these clips or chaining them, the first and last frames often display stutters or texture recoding artifacts. LoopSmith solves this by orchestrating `ffmpeg` to trim the clips intelligently and concatenate them into a mathematically exact duration, hiding the seams either via combinatorial search of low-cost boundaries or by dropping frames during fast-motion segments.

## 2. CHANGES
To transform this into a robust, recruiter-ready reference project:
- Introduced a JSON output flag (`--json`) for machine-readable planning.
- Added strict, meaningful exit codes (2 for usage, 3 for missing dependencies/inputs, 4 for insufficient frames, 5 for constraints limits).
- Implemented a synthetic, deterministic test corpus generator (`tests/generate_fixtures.sh`) that uses `ffmpeg` `testsrc` instead of committing binary video files.
- Built an exhaustive test suite (`tests/run_tests.sh`) checking constraints, errors, output precision, unicode handling, and determinism.
- Added a benchmark script (`tests/benchmark.sh`) evaluating a 100-second recursive combination.

## 3. TEST EVIDENCE
The test suite validates:
- **Exact Frame Assembly:** Ensures `ffprobe` reports the exact mathematical frame target (e.g., 30s @ 24fps = 720 frames).
- **Determinism:** Two identical test runs produce strictly identical combinatorial choices and seam scores.
- **Graceful Failure:** Testing exit codes 3 (missing files), 4 (insufficient frames) and 5 (unsolvable combinatorics).
- **Filename Robustness:** Handling filenames containing spaces and Unicode characters (e.g. `buen archivo 🚀.mp4`).

## 4. ARCHITECTURE DECISIONS
- **Why bash and ffmpeg?** Using raw `ffmpeg` filters (`tblend=all_mode=difference`) avoids pulling in massive Python computer vision dependencies.
- **Why a combinatorial solver?** Instead of arbitrarily slicing off the end of a video, the script distributes the dropped frames across all available seams, checking every permutation to find the transition that closest matches the natural motion baseline.
- **JSON + CLI Output:** Keeping standard terminal stdout for human execution while allowing a `--json` parameter for piping to programmatic workflows.

## 5. KNOWN LIMITATIONS
- **Combinatorial Explosion:** The script recursively evaluates combinations. While perfectly fast for small drops and 2-3 clips, a massive frame drop constraint over 10+ clips might become computationally expensive in bash.
- **Audio:** LoopSmith explicitly drops audio (`-an`) because generative models rarely output synchronized audio worth looping seamlessly with these frame-dropping strategies.

## 6. INTERVIEW DEFENSE
**"Why didn't you just use Python + OpenCV for this?"**
*Because a 300-line bash script that requires zero dependencies beyond `ffmpeg` is infinitely easier to deploy in a media pipeline than a Python environment with OpenCV bindings. By using `ffprobe` to extract raw luminance difference data, I got the exact same mathematical insight OpenCV would provide, but completely decoupled from heavy runtimes. This proves an understanding of underlying toolchains rather than just throwing a heavy library at a small problem.*

## 7. EXACT NEXT STEP
Integrate LoopSmith's JSON output directly into the main Portfolio automation pipeline to generate live before/after loop comparisons dynamically.

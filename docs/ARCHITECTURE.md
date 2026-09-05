# loopsmith Architecture

`loopsmith` is an auditable Generative Media Engineering case study. It solves a specific problem in generative media: constructing exact-duration loops from generative clips, without stutters or jumps.

## FFmpeg/ffprobe Pipeline

The core logic relies entirely on `ffmpeg` and `ffprobe`. This prevents the need for heavy CV frameworks and makes the solution easy to deploy.

- `ffprobe` is used with `lavfi` and `tblend=all_mode=difference` to extract absolute frame differences. This allows for measuring motion energy.
- `ffmpeg` is used with `filter_complex` (`select`, `trim`, `concat`) to non-destructively trim frames and concatenate the resulting clips.

## Cut Search & Exact-Duration Assembly

Generative tools often return an arbitrary number of frames slightly off the target duration (e.g. 361 frames instead of 360).
To achieve exact-duration assembly:
1. `loopsmith` enumerates candidate seams by distributing the total frames to drop (`DROP`) across possible cut points (clip head and tails).
2. It scores the seam cost for each permutation.
3. The lowest-cost permutation is selected.

Alternatively, `loopsmith` can cut on the motion (using `--motion-cut`). In this strategy, seams are preserved intact. Instead, the extra frames are removed from the middle of the clip at the fastest moving points, where motion blur masks the frame deletion.

## Error Handling

`loopsmith` is built to run reliably:
- Validates inputs before running (e.g. checking file existence).
- Returns errors when missing `ffmpeg` or `ffprobe`.
- Handles edge cases when dropping frames is impossible because `MAXDROP` constraints are too tight.
- Exits explicitly and logs errors to stderr when problems arise.

# Generative Media Engineering: loopsmith Case Study

`loopsmith` is an auditable, programmatic toolkit demonstrating advanced generative media engineering.

For creative technology studios or senior video/AI tooling engineers (e.g., at Krea, ElevenLabs, Figma), this repository provides concrete evidence of technical and creative problem-solving in production pipelines.

## The Problem Addressed
Generative video models (Kling, Runway, Sora) do not deliver exact durations. Attempting to concatenate them creates stutters, frozen frames, or jarring jumps. Manual editing is subjective and inefficient at scale.

## The Engineering Solution
`loopsmith` provides a predictable, auditable, CLI-driven pipeline to automate the assembly of fixed-length generative clips.
- Uses `ffmpeg`/`ffprobe` to compute motion-energy and baseline references at candidate cut seams.
- Exhaustively searches the permutation space to drop frames required to hit an exact duration constraint.
- Evaluates seams by comparing seam difference to local motion baselines, targeting a ratio of `1.0` (rather than absolute difference, which causes frozen frames).
- Implements `--motion-cut` functionality to optionally hide dropped frames inside high-motion action sequences instead of at the clip seams.

## paleta.sh: A Creative Control Tool
The repository includes `paleta.sh`, a utility proving that generative tooling isn't just about cutting clips; it's about controlling model conditioning.

Image conditioning in generative models is holistic. Passing an image for color style often overrides negative text prompts, accidentally introducing unwanted subject matter. `paleta.sh` solves this by programmatically extracting the palette from a reference image and converting it into precise prompt language.

It categorizes colors into:
1. **Accents:** High saturation, visually defining colors (the prompt).
2. **Base Tones:** High-area, low saturation colors.

By separating the palette/style conditioning from the scene/content when iterating generative models, it offers the engineer true creative control.

## Documentation & Traceability
This repository incorporates templates (like the ISMAJAKI framework) and detailed creative QA guides to ensure that Human Selection, Creative Direction, and Technical Tooling are easily distinguishable and auditable.

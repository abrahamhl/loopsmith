# Creative Quality Assurance (QA)

When working with generative media, quantitative metrics are essential but human creative evaluation is still necessary.

## The Seam Score Thresholds

`loopsmith` will output seam quality verdicts based on motion-energy ratios:
- **0.75 - 1.35:** "excelente". The cut matches the surrounding motion.
- **0.50 - 1.60:** "correcta". Acceptable.
- **< 0.50 or > 1.60:** "REVISAR" (Review).

## Manual Review Criteria (REVISAR)

When a seam is marked as "REVISAR", you should manually inspect it:

1. **Jumps (>1.6):** Does the cut break spatial continuity? The motion might be too dramatic to hide within the frames.
2. **Stutters (<0.5):** Did the generative model create a still frame, or is the cut artificially freezing the action?
3. **Pacing and Context:** Is this a slow-moving, settling shot? High ratios are more visible in slower scenes. You might need to use `--motion-cut` to shift the deleted frames into a fast-paced segment where motion blur can hide the edits.

## Generating Better Sources

If no cut combination yields a good score, the solution is not more editing. The missing motion was never generated. Go back to the prompt and ensure the camera speeds align at the ends of your generated clips.

# Motion-Aware Seam Scoring

Finding the best cut when joining generative clips is difficult to do by eye. `loopsmith` solves this by programmatically scoring seam quality.

## Methodology

`loopsmith` measures "motion energy" — the absolute mean difference in luminance between two frames downscaled to a low resolution (e.g., 320x180). This suppresses compression noise but keeps large motion continuous.

The core insight for seam scoring is that **a seam must match the motion around it**. A difference that would be invisible during a fast camera pan is glaring during a slow static shot.

The tool calculates a local baseline for motion by averaging the motion energy of standard consecutive frames on *both* sides of the cut.

Then it calculates the cost:
```
cost = |seam_difference / normal_step − 1|
```

## Why 1.0 is the Target

Unlike typical difference minimisation that targets 0, `loopsmith` targets 1.0.

- If the difference is too high (>1.6), it is a visible jump.
- If the difference is too low (<0.5), it is a freeze or stutter.

Minimising absolute difference would actively select for freezes. By targeting a ratio of 1.0, `loopsmith` ensures that the cut moves just as naturally as any other frame in the scene.

# A prompt structure for keeping a logo intact across a generated shot

**Scope:** this is a working structure, not a validated one. It comes from one project where the
mark survived intact across two chained runs, and from looking at a set of earlier attempts on a
different tool where it did not. No ablation was run — I have not removed blocks one at a time to
see which ones actually carry the weight. Read it as a checklist that worked, not as findings.

---

If a shot has to keep a logo or wordmark unchanged from first frame to last, describing it is not
enough. Generative video models treat text in the frame as something they may re-draw, and given
ten seconds they often will.

The structure below is ordered so that each block heads off a specific failure. The ordering is
deliberate: the constraint blocks come before the creative ones, because trailing instructions
tend to get less weight than leading ones.

| # | Block | Failure it targets |
|---|---|---|
| 1 | **Shot declaration** — one continuous take, from the supplied opening frame to the supplied end frame | Internal cuts, shot changes |
| 2 | **Mark shield** — rigid immutable object, letters spelled out individually | Typography mutation, added or dropped characters |
| 3 | **Camera choreography** — a named move with degrees and direction | Aimless drift |
| 4 | **World mechanics** — what moves, in physical language: weight, inertia, secondary motion | Weightless motion that reads as fake |
| 5 | **Atmosphere preservation** — the lights, colours and textures that must stay identical | Colour drift between runs of the same scene |
| 6 | **Landing** — land precisely on the supplied end frame | The model ignoring the end frame |
| 7 | **Tone** — quality and photographic references | Generic output |
| 8 | **Negative list** — what is forbidden, explicitly | Everything else |

## The shield block

```
The metallic wordmark ACME is a single rigid immutable object, exactly four letters
in this order: A-C-M-E. Keep every letter complete, sharp, unobstructed and unchanged
in every single frame.
```

Two ideas are combined here, and I cannot tell you which one matters more without testing.

**Spelling the letters individually** is intended to give a character-level constraint instead of
a word the model re-interprets as a shape.

**Declaring the mark a rigid object** is intended to move it out of the category of things that
may be animated, so motion belongs to the camera and the world instead — which is usually what you
wanted anyway.

What I can say concretely: in a set of earlier attempts made without either device, the mark was
sometimes lost entirely — a finished composition with no lettering in it — and in one case came
back with a character missing. Those attempts used a different tool and entirely different
prompts, so this is circumstantial. It is the reason the block exists, not evidence that it works.

## Phasing the timeline

For a run with both a start and an end frame, stating the arc explicitly seemed to distribute
motion more evenly than leaving it open:

```
0-3 s:  establish, begin the move, start the secondary motion
3-7 s:  the main movement, at its most energetic
7-10 s: decelerate and land precisely on the supplied end frame
```

Be aware of the trade-off: asking a run to decelerate onto its end frame is asking for a slow
final second. If that run is the one that closes a loop, you have deliberately created a speed
mismatch against whatever follows. Ask the closing run to *arrive* at the end frame rather than
settle on it, if the loop matters more than the ending.

## Blocks worth reusing verbatim

The shield and the negative list are the two that carry between projects. The rest is scene-specific.

```
No cuts, crossfade, dissolve, double exposure, letter animation, spelling mutation,
missing or additional characters, cropped logo, liquid metal, camera shake, excessive
sparks, watermark or other text.
```

## On reference images

If the shot must not contain people, do not pass a reference image that contains people, however
firmly you phrase the negative instruction. Image conditioning is holistic, and a strong visual
prior tends to outweigh negative text.

Crop the reference so the unwanted content is not in it, or convert it to colour language and pass
words instead — see `paleta.sh` in this repository.

## What would make this trustworthy

An ablation: the same start and end frames, the same seed where the tool exposes one, running each
block removed in turn, scored on whether the mark survives. That is maybe twenty generations. Until
someone does it, the ordering above is reasoned, not measured.

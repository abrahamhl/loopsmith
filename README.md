# loopsmith

**Assemble a set of video clips into a loop of exactly the duration you asked for, cutting where
it shows least.**

You have several clips. Together they are 722 frames. You need exactly 720. Which two frames do
you drop, and from where?

Drop them in the wrong place and you get a visible tick at the join, or a frame that sits still
long enough to read as a stutter. `loopsmith` measures the actual motion at every candidate cut,
scores each resulting seam against how fast that part of the footage is normally moving, and picks
the combination that hits your frame count exactly while keeping every seam moving naturally.

It only removes frames. No retiming, no interpolation, no invented pixels.

```
./loopsmith.sh --out loop.mp4 --duration 30 clip-1.mp4 clip-2.mp4
```

```
  clip 1  clip-1.mp4                              361 frames  1916x1080
  clip 2  clip-2.mp4                              361 frames  1916x1080
  ----------------------------------------------------------------
  available 722 frames | target 720 (30 s at 24 fps) | surplus 2

  ASSEMBLY PLAN
    clip 1  frames   0…360 = 361   (dropped: 0 head, 0 tail)
    clip 2  frames   1…359 = 359   (dropped: 1 head, 1 tail)
    ----------------------------------------------------
    total 720 frames = 30.000000 s at 24 fps

  RESULTING SEAMS
    join 1→2      ratio 1.39   fine
    LOOP  2→1     ratio 1.71   CHECK
```

---

## The problem

Generative video tools are the obvious source of this, but the problem is older than they are. Any
time you assemble clips into a fixed-length loop, the frame arithmetic rarely lands on the number
you need, and something has to give.

Two things make it awkward to do by hand:

**Exact duration is all-or-nothing.** 30.083 seconds is not 30 seconds. If anything downstream is
synced — a VJ grid, a broadcast slot, a display board on a timer — close doesn't count.

**Where you cut is not obvious.** Any two adjacent frames differ by some amount. What matters is
whether that amount matches how fast the footage is moving *at that point*. A difference that
would be invisible during a fast camera move is glaring during a slow one. Judging that by eye,
across every possible cut, is exactly the kind of thing you should not be doing by eye.

## How it decides

For each candidate cut, the two boundary frames are extracted and compared: mean absolute
difference, downscaled, which gives a single number for "how much changed here". The same number
is computed for ordinary consecutive frames on both sides of the seam, giving a local baseline —
what a normal frame step looks like in that part of the footage.

Each seam is then scored:

```
cost = |seam_difference / normal_step − 1|
```

Three decisions are doing the work here:

**The target is 1.0, not zero.** A seam that changes too much is a jump. A seam that changes too
little is a freeze — two nearly identical frames in a row, which reads as a stutter. Both are
visible, so both are penalised. Minimising raw difference would actively select for freezes.

**The baseline comes from both sides.** Using only the outgoing clip skews the score badly when a
cut joins a slow passage to a fast one — which is precisely what happens at a loop point, where a
settling shot meets a shot already in motion.

**The search is exhaustive, not greedy.** Every way of distributing the frames-to-drop across the
available cut positions is enumerated and scored; the lowest total wins. The search space is small
because the number of frames in question is small.

The tool reports the resulting ratios rather than hiding them. A seam it cannot get close to 1.0
is flagged, because sometimes the footage simply does not contain a good cut and you need to know
that rather than be reassured.

## Install

```
git clone https://github.com/YOURNAME/loopsmith.git
cd loopsmith && chmod +x loopsmith.sh paleta.sh
```

Needs `ffmpeg` and `ffprobe` on the PATH, and Bash 4+. Tested on Windows via Git Bash; the tooling
is portable but Linux and macOS are currently untested.

## Usage

```
./loopsmith.sh [options] clip1.mp4 clip2.mp4 [clip3.mp4 ...]
```

| Option | Default | |
|---|---|---|
| `--out FILE` | `loop.mp4` | Output path |
| `--duration SEC` | `30` | Exact target duration |
| `--fps N` | from source | Output frame rate |
| `--size WxH` | `1920x1080` | Output resolution |
| `--crf N` | `15` | x264 quality |
| `--dry-run` | | Analyse and print the plan without encoding |
| `--no-loop` | | Linear piece; don't optimise the wrap-around seam |

Clips are normalised to the output resolution by cropping to the target aspect and scaling —
useful because generative tools do not always hand back exactly 16:9. The encode profile is aimed
at dark, hazy, gradient-heavy footage, where the usual failure is banding in the shadows.

## What it does not do

- **It cannot add motion that was never generated.** If a clip decelerates to a stop and the next
  one starts already moving, position will be continuous but speed will step. Cutting cannot fix
  that; only interpolation could, and on chains, fog or foliage interpolation tends to produce
  worse artefacts than the problem. The tool reports the seam ratio honestly instead.
- **It does not re-time, stretch or interpolate.** If you need more frames than you have, this is
  the wrong tool.
- **It assumes all clips share a frame rate.** Mixed-rate input is not handled.
- **The cut positions considered are clip heads and the final tail**, up to three frames each.
  Cuts in the middle of a clip are not searched.

## paleta.sh

A separate, smaller utility for an adjacent problem: hand an image model a reference picture "just
for the colour palette" and it will copy the subjects too. That isn't the model ignoring you —
image conditioning is holistic, and a strong visual prior outweighs a negative text instruction.

The reliable fix is to not pass the image. `paleta.sh` reads a reference and returns colour
language you can put in a prompt, separating the **accents** that carry the look from the **base
tones** that carry the area. On a night scene the accents can be a few percent of the pixels and
most of the character, so a plain dominant-colour extraction returns grey and tells you nothing.

```
./paleta.sh reference.jpg
```

```
ACCENTS
  #B86C45   orange          rgb(184,108, 69)
  #7479C5   violet          rgb(116,121,197)

BASE TONES
  #242023   dark grey       rgb( 36, 32, 35)
  #23252A   deep blue       rgb( 35, 37, 42)

  Colour palette: orange, violet accents over a dark grey, deep blue base.
```

## Verification

The assembly logic was checked against a loop cut by hand from manual measurements. Given the same
two clips it selected the same cut points independently, and its output is bit-for-bit identical
to the hand-built version.

That is a consistency check, not a proof of quality — it confirms the tool reproduces a careful
manual process, on one pair of clips.

## Further reading

- [`docs/field-notes.md`](docs/field-notes.md) — what the measurements looked like on one real job,
  and the ffmpeg recipes to take the same measurements on yours
- [`docs/prompt-architecture.md`](docs/prompt-architecture.md) — a prompt structure for keeping a
  logo intact across a generated shot

## Status

Working and in use, on a small sample. Known gaps: no automated tests, no bundled example footage,
untested outside Windows/Git Bash. Issues and clip pairs that defeat it are welcome — the
interesting failure mode is footage where no cut scores well, and I would like more of it.

## Licence

MIT

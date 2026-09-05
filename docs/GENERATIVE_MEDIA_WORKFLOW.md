# Generative Media Workflow

An auditable workflow for creating fixed-length video loops using generative tools.

## 1. Generation
Generate the base media clips via a generative model (e.g., Kling, Runway). These clips may have variable frame durations, slight color shifts, and non-continuous motion at the edges.

## 2. Candidate Clips
Store the output video clips. Note that if you use tools like `paleta.sh`, this is the step where you extract the reference colors from the desired asset before feeding it into the generator to isolate style conditioning.

## 3. Analysis
Analyze the clips using `ffprobe` to determine the motion energy curve and check for variations across frame durations or resolutions. This sets the baseline parameters for cutting.

## 4. Seam Search
Perform an exhaustive combinatorial search for the best seam cuts. The search considers clipping at the beginning or end of clips to find the exact combination of frames that reach the exact target frame count.

## 5. Exact Loop
Assemble the final video based on the selected seams. The resulting sequence will match the exact requested duration, maintaining strict continuity for any synced downstream processes (e.g. VJ Grids).

## 6. QA (Quality Assurance)
Review the seams output ratios. If any ratio falls outside the [0.5, 1.6] bounds, it should be manually reviewed (marked "REVISAR"). See `CREATIVE_QA.md` for criteria.

## 7. Final Output
Output the cleanly assembled, exact-duration clip encoded in the final presentation format.

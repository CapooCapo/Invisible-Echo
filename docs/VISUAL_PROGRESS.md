# Visual production progress — 2026-10-11

## What is actually in the game

This project started the visual pass as a **Node2D code-drawn game**. It now contains original rigged GLBs, procedural school textures, and real 3D Godot SubViewport rooms. Scenes 01 and 03–04 use a `CharacterBody3D` for first-person movement and proximity, collisions, and a flashlight; the player model is hidden in normal view and retained separately for reflections. Scene 01's letter pickup reveals “CỨU TÔI” in a supernatural red world wash. The existing narrative, inventory, puzzle and checkpoint systems remain. This is a **scoped first playable**, not a conversion of all 15 scenes.

| Scene | Current visual status | Most important gap |
|---|---|---|
| 01 — Hallway letter | First-person 3D movement, detailed letter pickup, staged red plea reveal and door implemented | Human camera/playability QA and further environmental density |
| 02 — Classroom plea | Hallway 3D backdrop only | Distinct classroom set/cinematic |
| 03 — Toilet hide | First-person stall entry and staged hide, state-driven hide cue, with three bully GLBs as visual threats | Pursuit/door pounding animation and final fixture/lighting polish |
| 04 — Mirror | Physical mirror proximity and a separate 3D viewport for An | Turn-around motion, exact apparition staging and visual polish |
| 05 — Notice board | Existing 2D scene | 3D board/hallway presentation |
| 06 — Diary | Existing 2D puzzle | 3D book/paper props; keep puzzle algorithm |
| 07 — Electrical cabinet | Existing 2D puzzle | Modeled cabinet, wires and switches |
| 08 — Patrol/chase | Existing 2D scene | Bullies, locomotion and school route 3D |
| 09 — Computer/camera | 3D lab integrated for code-entry beat; controller runtime capture | Interactive 3D task monitor/camera UI, real navigation |
| 10 — Anonymous post | Existing 2D UI | 3D lab context and diegetic screens |
| 11 — Evidence board | Existing 2D UI | Modeled evidence board/photos/strings |
| 12 — Keepsake return | 3D chess club integrated with six-item HUD; controller runtime capture | Physical keepsake placement, emotional animation |
| 13 — Chess challenge | Existing 2D chess puzzle | Chess-piece move animation and 3D-board presentation |
| 14 — Final memories | Existing 2D scene | 3D memory lights/cinematics and black king prop |
| 15 — Next person/endings | Existing 2D scene | Branch-specific 3D cinematics |

The first four entries are **partial**, not scene-complete. Scene 02 still uses the hallway backdrop; lab and club are not scene-complete merely because a 3D capture exists. Character previews and concept art are not gameplay evidence. `VISUAL_QA.md` records runtime checks and their limits; `RELEASE_QA.md` records the earlier gameplay release baseline, which predates this migration.

## Next production milestones

1. Finish the hallway/restroom hero spaces for human review: modular fixtures/props, purposeful lighting and camera adjustments, clear interaction focal points and readable An apparition.
2. Run a human playthrough of scenes 01–04 with real mouse input, camera collision, animation, sound and performance checks; automated path assertions and still captures do not replace this.
3. Stage and animate named characters at their story beats; inspect feet, backpack, turns and interactions in actual runtime.
4. Only after the first playable passes visual review, improve lab/club and convert later scenes/puzzle props in story order; retain regression harnesses and isolated save profiles.
5. Measure performance on target hardware and run full visual/gameplay/audio QA before release.

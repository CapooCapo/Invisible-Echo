# Visual QA — evidence ledger

**Scope:** work-in-progress 3D production, Godot 4.7.2 on Linux, Compatibility renderer. The first-real-playable hallway/restroom captures are 960×540; older integrated lab/chess captures are 941×529. Images in art_references/ are CONCEPT_REFERENCE; neither a Blender preview nor a Godot screenshot alone proves a playable route.

| Evidence | Classification | What it demonstrates | What it does not demonstrate |
|---|---|---|---|
| `qa/screenshots/first_real_hallway_runtime.png` | `GODOT_RUNTIME_CAPTURE`, current first-playable fixture | Post-change Hoàng, physical-room layout, texture and lighting render | Input-driven route, mouse capture, animation continuity |
| `qa/screenshots/first_real_toilet_runtime.png` | `GODOT_RUNTIME_CAPTURE`, current first-playable fixture | Post-change stall/fixture geometry, material and light render | Human-timed hiding or chase AI |
| `qa/screenshots/first_real_mirror_runtime.png`, `first_real_reflection_runtime.png` | `GODOT_RUNTIME_CAPTURE`, current first-playable fixtures | An appears only in the reflection beat; improved low-poly sinks and mirror framing render | Human camera interaction or final reference likeness |
| `qa/screenshots/hallway_3d_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | Hallway mesh, texture, Hoàng, lights and third-person framing render | Collision, full scene path, reference-level quality |
| `qa/screenshots/toilet_3d_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | Bathroom geometry/lighting and three bully models render | Hiding route/timer input or pursuing AI tested in 3D |
| `qa/screenshots/mirror_3d_runtime.png`, `reflection_3d_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | The apparition is rendered via a separate live 3D mirror view in the reflection beat | Full mirror movement, disappearance after turn, animation |
| `qa/screenshots/lab_3d_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | 3D lab, rows of CRTs, Hoàng and lighting render | Code/camera/post puzzles on top; input flow |
| `qa/screenshots/chess_3d_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | Modeled club, pieces, characters and lights render with six returned keepsakes | Inventory flow, chess gameplay in 3D, visual reference match |
| `qa/screenshots/lab_integrated_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | Actual scene-09 code-entry controller draws readable HUD over the 3D lab | Entering code through actual user input or later 2D puzzle visuals |
| `qa/screenshots/chess_integrated_runtime.png` | `GODOT_RUNTIME_CAPTURE`, `VISUALLY_VERIFIED` | Actual scene-12 controller draws six-item HUD over the 3D club | Returning items by actual user input or chess-boss 3D visuals |
| `qa/blender_previews/*.png` | `BLENDER_PREVIEW` | Exported mesh silhouettes before import | Godot rendering or runtime behavior |

## Reference comparison — current verdict

| Target | Similarity achieved | Gap that blocks visual signoff |
|---|---|---|
| Hoàng | Correct broad outfit, hair/backpack silhouette; regenerated rigged GLB and locomotion clips | Face, clothing folds, hands/feet and motion remain simpler than concept; human motion review pending |
| Hallway | Corridor composition, classroom doors, lamps, red depth cue, rail and worn-material variation | Still sparser and more evenly lit than concept; flashlight and camera feel need human review |
| Restroom | Recognizable low-poly toilets/sinks/stalls, cool/red lights, separate An reflection now legible | An remains relatively small; stall architecture remains box-heavy and spectral staging needs human camera proof |
| Computer lab | CRT rows/green screens and center aisle | Props/decals/posters, screen detail, floor variation and atmosphere sparse |
| Chess club | Tables, chess pieces, shelves, trophies, moon/warm lights | An is tiny in current framing; lacks rich memorial props and warm transformation cinematics |

## Verification limits

- The fixture captures actual rendered SubViewport images after scene instantiation, not AI images or Blender renders. It sets beats/state directly. This **does not validate a human route** through the scenes.
- The scene-12 integrated-capture harness does not seed inventory or return flags; its six-item HUD depends on the loaded save. The existing screenshot is visual evidence, but a fresh, deterministic recapture of that exact state is **not verified**.
- Scenes 01 and 03–04 now use a physical `CharacterBody3D`, but the automation is not a human GUI playthrough. OS-level mouse capture, camera/wall clipping during varied play, sound and frame rate are **not verified**.
- The actual Hoàng portrait photo and four additional beyond these concepts were not present in accessible input; identity matching is limited to the supplied stylized reference.

## Earlier visual-slice verification — 2026-10-11

The independent tester used Godot 4.7.2.stable.arch_linux.ed1daf0bf and preserved the pre-existing worktree. A bounded headless editor import and main-scene smoke both exited 0 without reported errors or warnings. Seven bounded headless harnesses exited 0 with pass markers: first slice 16, school chapter 27, digital mystery 16, GameState 10, chess rules 18, resolution 10, and audio resources 8 — **105 assertions total**. This covers progression logic, not human input through every 3D scene.

The Linux/X11 data pack exported successfully from the current tree into builds/visual-qa/final-20261011/an-tieng-gay-trong-dem-linux.pck. Paired with the Godot 4.7.2 official release template an-tieng-gay-trong-dem-linux.x86_64, the executable exited 0 under --headless --quit-after 5 with isolated HOME/XDG directories and no --path or --main-pack override. Its new save recorded scene_01 / hallway_letter, confirming that the exported game, not Project Manager, loaded. PCK SHA-256: cd3a9c6dc87652ec783dc7eb4a366a5eab6490f3ae2d993b19d7ad23cfa5e66f. The export inventory included the four 3D scenes, imported GLBs and textures; reference images and Blender source archives did not appear in that inventory. This is a Linux headless package check, **not** exported-GUI or Windows-runtime verification.

Independent code review was attempted but **not verified** because the review provider returned a billing/rate-limit error. A focused integration inspection found no blocking defect; it does not replace that review. Human playthrough, sound/listen test, performance and full 3D navigation remain **not verified**. The earlier RELEASE_QA.md release gates remain open.

## First real 3D playable — current-tree verification, 2026-10-11

The pre-change worktree (98 modified/untracked source and evidence files) was preserved at `builds/checkpoints/first-real-3d-prechange-20261011/`; no save was deleted. The renewed Hoàng GLB is a real mesh/skin with 12 clips; Blender preview is not Godot evidence. Godot 4.7.2 editor import and main-scene headless smoke exited 0 after the controller/model change. A later editor import after the restroom fixture pass also exited 0.

Independent tester ran eight bounded headless scripts sequentially after the final restroom change; all exited 0: `test_real_3d_playable.gd` **46**, `test_first_slice.gd` **19**, school chapter **27**, digital mystery **16**, GameState **10**, chess rules **18**, resolution **10**, audio assets **8** — **154 assertions total**. The new harness exercises physical hallway wall blocking, opening and crossing the end door, stall collision opening and entry, 0.65 s Interact staging, 1.4 s Hide staging/frozen timer, camera orbit forwarding, flashlight, scene 03/04 checkpoints, and An visible only in the mirror beat. Idle/Walk/Run looping and sustained movement were checked after an independently found animation-freeze defect was fixed. `git diff --check` passed.

Four post-change 960×540 images listed above were captured from a real Godot GUI session via Wayland/Intel Compatibility rendering; they use fixture-set beats and are **not** captures of a human traversing the route. The graphical run logged an XDG toplevel icon warning and Mesa's failed NVIDIA DRI2 attempts before successfully selecting the Intel renderer. Independent code review **approved the first playable milestone**, but not final visual quality or release. OS-level mouse capture, full human GUI playthrough, Windows runtime, audio listening and frame-rate measurement remain **not verified**. No new build was exported for this milestone.

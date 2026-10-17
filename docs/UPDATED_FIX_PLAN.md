# Updated Environment Fix Plan

**Gate:** Batch 1 is not complete until production navigation, physics, interaction, camera, and visual checks have evidence. The owner separately authorized the limited Level-1/2 side-room correction below; this is not permission to begin wider whole-school rollout, which remains gated on Batch 1 acceptance.

**Global architectural rule recorded from the owner:** adjacent rooms must meet with a shared wall and no unintended gaps; intentional door/window openings remain functional. Future batch work must apply this after confirming the approved plan.

## Batch 1 — Stair B → L3 east wing → WC Nam

1. **P0 connector / atrium safety — PASS — gameplay route.** The local Stair B connector, east-wing rail opening, and south-edge guard remain; U-plan/courtyard and 3.2 m floor height are unchanged. Fresh production `CharacterBody3D` route after the L3 bench reposition passed through the gallery and WC using input actions; the grounded edge probe remains in the trace. After the hide-camera aim change, the legacy world-axis helper failed because it assumed `move_right` always increments world X; the adapted camera-relative full route completed exit 0, opened the WC, hid/exited, reached the grounded mirror trigger, and sent real E to `mirror_ghost`. The latest post-sky-change trace is `builds/visual-qa/environment-recovery-20261016/production_route_after_procedural_sky.log`; the pre-sky full-route trace and original post-bench trace remain available.
2. **Mapped WC integration / door prompt — PASS — interaction regression.** `WC NAM` at `(19,6.4,1)`, size `10×6 m`, remains the sole shell. A production HUD defect hid the “E · Mở cửa” Label inside the invisible dialogue panel; the prompt now moves to a bottom-center gameplay HUD and returns to the dialogue column when needed. The test verifies story-overlay suppression, prompt reparenting, visible-in-tree state at the measured approach, and real `KEY_E` opening. Reviewer approved the overlay guard.
3. **Cubicle/hide interaction — PASS — real-controller route.** The first mapped cubicle has a closed collidable leaf; the hide bounds are inside its mapped floor area and `set_hidden(true)` does not teleport Hoàng. Fresh input-driven run opened the main door, crossed the threshold grounded, opened the stall, reached the hide trigger, completed the timed hide/exit, and continued to the mirror event.
4. **Mirror/fixtures — IMPLEMENTED; interaction state PASS; visual acceptance pending.** The story mirror reuses the existing mirror viewport; project-authored low-poly toilet/cistern, basin/faucet, and urinal GLBs are integrated. The real E route reaches `mirror_ghost` with the apparition visible/in-tree; this does not by itself prove in-game visual readability or a physically synchronized reflection.
5. **L3 corridor furniture — IMPROVED; static review APPROVED.** Only the Level-3 gallery benches were rotated and moved into wall-side gaps between door openings. No structure, opening, collision, or other floor placement changed. The current production screenshot shows a clear center walking line; the post-change real-input route passed.
6. **Camera / visual acceptance — STILL PENDING.** X11 QA sampled 12 grounded production-camera poses with no 55 mm camera-volume overlap; clearance between samples is not verified. Captures and report are in `builds/visual-qa/environment-recovery-20261016/camera-qa-20261016/`. The production east-corridor sky now uses a dark procedural gradient plus generated star cover; its same-view X11 capture has no bright disk or cyan horizon band, while ambient energy `.46` and authored local lights remain unchanged. The prior panorama `.04` and Qwantani `.01` captures are retained as rejected comparisons. A scoped correction faces the actual mirror during An's reveal and lowers the WC plaque (new X11 approach image shows it legibly). The real-E regression passes first-E facing and second-E turn-away after a simulated 400 px mouse orbit; the earlier reviewer approved the re-aim-before-turn fix. Hide-state auto-aim faces the stall opening; the latest X11 frame shows restroom context but retains a substantial partial partition foreground. Full-slice appearance, between-pose camera sweep, FPS/draw calls, and a reproducible matched plan overlay remain open. Four supplied schematic floor plans are accessible in inbound attachments and were reviewed; no room dimension/elevation schedule is defined. Detailed stair drawings are still missing. The supplied Level-3 plan omits the story-required WC Nam, so the plan amendment remains unresolved.
7. **Documents — UPDATED FROM FRESH EVIDENCE.** Navigation report, room matrix, visual comparison, asset inventory, and this plan record the latest route/HUD results and remaining gaps.

### Harness caveat

The older `tests/test_production_stair_b_wc_route.gd` run still exits 1 at its mapped-school-entry waypoint (`x=-9.415028`) before reaching Stair B. This is a stale scripted yard path, not accepted route evidence. The accepted current evidence is the camera-relative full-route harness `builds/visual-qa/environment-recovery-20261016/production_route_camera_relative_controls.gd`, with latest trace `production_route_after_procedural_sky.log`; keep the stale failure visible until that older helper is corrected or retired.

## Deferred batches

- Batch 2: sample classroom/hallway on Floor 1.
- Batch 3: Principal, Youth Union and Teachers’ rooms (requires exact source plan comparison).
- Batch 4: library/computer/science labs.
- Batch 5: clubs and vocational classrooms (resolve room IDs first).
- Batch 6: remaining corridors, stairs A/C, rooftop and yard.

Do not proceed to these until Batch 1 satisfies all quality gates and matched visual review. Stair A/C axes, floor-1 office identities and chess-club placement remain governed by `docs/architecture_audit/DESIGN_CONFLICTS.md`.

## Owner-requested Level-1/2 room-bay correction — IMPLEMENTED, PRODUCTION REVIEW PENDING

- Ground Principal's Office and Class 1 remain recessed to x `[-18,-14]` and `[14,18]` respectively, but deepen to z `[-17.9,-9.5]` (`4×8.4 m`). This preserves the existing ground-floor west/east return routes at z≈−15/−14.
- Ground Đoàn office and Class 2 use x `[-24,-14]` / `[14,24]`, z `[-9.5,-1.1]` (`10×8.4 m`). The Principal's Office now has a distinct larger corridor plaque and interior board plus meeting furniture.
- Level-2 west clubs use two adjoining `10.5×8.4 m` bays, x `[-24,-13.5]`, z `[-17.9,-9.5]` and `[-9.5,-1.1]`.
- Level-2 practice stays recessed at x `[14,18]` and deepens to `4×8 m`, z `[-17.9,-9.9]`; IT grows to `10×8 m`, x `[14,24]`, z `[-9.9,-1.9]`. No geometry enters the Stair-C bypass x `[20.6,23.4]`, z≈−14.
- At each adjoining seam the southern shell owns the single collidable north partition (and its trim); the northern shell suppresses its duplicate. Expanded room fixtures/seating are denser but stay within the bounds. Facade infill follows new outer-room extents without covering room windows.
- Godot 4.7.2 editor parse/import succeeded after this source change. Runtime route/physics and GUI visual checks are still required; do not infer a pass from headless parsing. Exact plan dimensions remain uncertain because the approved image files are not locally present.

## Source limitations

- The floor 1/2/3/rooftop plan images are accessible from the inbound attachments documented in `docs/architecture_audit/ROOM_MAPPING.md`, but are not stored in the checkout; plan-overlay capture/review remains pending. The detailed stair drawings are not available and remain `REFERENCE_MISSING`. Do not infer structural design intent from concept art.
- No external assets were acquired. Any future acquisition must be free, provenance/license-checked, and documented before import.

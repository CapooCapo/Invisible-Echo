# Visual Comparison — Batch 1

**Current verdict: `VISUAL_UNVERIFIED` (not a pass).**

Capture method: Godot 4.7.2, actual production main scene, X11 renderer, 960×540 `NightSchoolViewport`; no generated AI images substituted for scene captures.

## References viewed

- `docs/art_references/hallway_concept.png`: open corridor with glazed timber classroom doors/windows, repeated fluorescent fixtures, worn wall and floor texture, and subtle red spill. The art is PS2-inspired rather than photorealistic.
- `docs/art_references/restroom_mirror_concept.png`: twin basins below a broad mirror, Hoàng and An visibly composed in reflection, tiled/damp surfaces, cold ceiling light and a restrained red accent.

## Production captures

Latest staged GUI evidence for the mapped WC fixture/readability pass:

- `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/wc_entry_sign_closed_approach.png`
- `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/wc_open_threshold.png`
- `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/wc_mapped_stall_interior.png`
- `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/wc_mirror_event_at_mapped_vanity.png`
- `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/mirror_viewport_event.png` (isolated SubViewport composition, not proof of a live mirror in gameplay)
- `builds/visual-qa/environment-recovery-20261016/wc_prompt_hud_after_bench.png` (941×529 actual production main-scene capture at the measured WC approach; setup positions the actor for UI composition, while route navigation is verified separately by input-driven harness)
- `builds/visual-qa/environment-recovery-20261016/camera-qa-20261016/contact_sheet.png` and `CAMERA_QA_REPORT.md` (actual first-person production-camera endpoint captures; staged positions, not a continuous route or full visual pass)

Level-1/2 room-bay survey from the same production main scene, captured from staged viewpoints (composition evidence, not a route test):

- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/exterior_yard.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/principal_sign.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/principal_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/classroom_1_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/classroom_2_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/level2_club1_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/level2_practice_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/level2_it_interior.png`
- `builds/visual-qa/environment-recovery-20261015/final-followup-20261015_01/principal_sign_orientation_after_20261015_corridor_view2.png` (941×529 follow-up after correcting the hallway-facing plaque orientation)

## Observations and gaps

| Element | Current evidence | Comparison / action |
|---|---|---|
| Gallery | Dark but readable tiled route, classroom opening and protected courtyard rail visible | Geometry reads as a connected school gallery, but the capture is dominated by simple repeated floor cells and sparse facade detail; concept doors/windows, fixture rhythm, surface variation and stronger controlled warm/red depth cues are still missing or underdeveloped. |
| L3 east-gallery walking line / night sky | Production capture `builds/visual-qa/environment-recovery-20261016/camera-qa-20261016/level3_east_corridor.png` uses a dark `ProceduralSkyMaterial` gradient plus generated 2K star cover; no bright disk or cyan horizon band remains in this same camera pose | The prior Kloppenheim energy comparison (`0.35` → `.04`) retained a bright disk. A CC0 Qwantani Night Pure Sky comparison retained an overly bright cyan-white horizon even at `.01`, so it was not adopted. The selected gradient keeps the sky dark while authored ambient (`.46`) and local lights remain unchanged; the corridor floor, rail and far facade remain visible. Hide-state capture is separately recorded; broad lighting/art acceptance remains pending. This verifies the sky change at one viewpoint only. |
| WC interaction HUD | `E · Mở cửa` is legible at the measured door approach and sits above the inventory bar. The dialogue-overlay regression keeps it hidden during opening subtitles and restores it afterward. | The old label was inside a hidden dialogue panel, so the interaction worked while the prompt was invisible. The gameplay HUD correction is now captured and regression-tested; this resolves prompt visibility, not the room's broader visual-completeness gate. |
| WC approach | New first-person capture shows “WC NAM” legible above the centered door after lowering the plaque/label together | A duplicate mapped leaf is hidden in production while opening/jambs remain. This confirms readability at one close approach pose only, not overall route/visual acceptance. |
| Hide-state camera | New X11 production capture after the real hide API completes its 0.55 s aim shows the WC fixtures and stall opening; actor position is unchanged | The former default yaw placed a close partition across nearly the whole frame. Current yaw improves orientation/context, but a dark partition still occupies the lower foreground; this is a scoped composition improvement, not full camera or visual acceptance. Evidence: `builds/visual-qa/environment-recovery-20261016/camera-qa-20261016/hide_camera_auto_aim.png`. |
| WC interior | Staged interior shows the authored toilet in a cubicle and the twin-basin vanity under the mirror | Project-authored toilet/cistern, basin/faucet and urinal GLBs are integrated. Surface richness, fixture fit and full visual comparison against the reference remain open; this is not a finished-room claim. |
| Mirror/event | The event now aims the production first-person camera at the physical mirror before showing An; real-E state/camera regression passes | The test confirms view direction and turn-away after the simulated orbit (`facing_dot=1.0000`, then `−0.9998`), while `wc_mirror_apparition_looked_at.png` shows the corresponding composition. The reflection remains a stylized fixed composition rather than a physically synchronized reflection; full visual acceptance is still `VISUAL_UNVERIFIED`. |
| Principal's Office entrance | The original staged hallway view had an unreadable edge-on plaque; the later view shows `PHÒNG HIỆU TRƯỞNG` legibly facing the corridor | The orientation defect is corrected. This verifies sign readability in one staged view only, not whole-room visual acceptance. The room remains 4×8.4 m and its perceived spaciousness is unresolved. |
| Level-1 rooms | The Principal, Class 1 and Class 2 interior captures show office/classroom furniture and room identities | The 4 m Principal/Class-1 bays still read narrow in the staged views; Class 2 is broader. Lighting/material variation and room-by-room furnishing adequacy are not approved. Supplied plans identify bays/circulation but do not show internal furnishings. |
| Level-2 rooms | Club, practice and IT captures show noticeboard, workstations and class furniture | The Club and IT shells look broad; the 4 m practice bay remains constrained. Images are dark and do not establish visual completeness, furniture clearance or route access. Only limited room concepts exist; the plan references show room identities/bays, not detailed furnishing schedules. |

## Capture limitations

- Staged viewpoints call `teleport_to` only in this visual-capture helper, then invoke the actual production scene/mirror methods. This evidence checks composition, not navigation or story progression.
- Story interaction progression, stall occupancy, camera clearance and perception on a normal play session require their separate production-input checks.
- Staged camera placement in a production-scene capture helper checks composition, not gameplay navigation. Do not infer door, room or camera clearance from these stills.
- The fixed-position mirror composition remains intentional and non-physical; it is not a synchronized physical reflection. Do not infer `VISUAL_PASS` from the staged mirror image.
- The 2026-10-16 WC-approach capture uses a staged actor position for a repeatable HUD frame. It is real production-scene rendering, but it is not a live human playthrough or a substitute for the independent controller route trace.
- The floor 1/2/3/rooftop plan images are accessible from inbound conversation attachments and were reviewed, but are not stored in this checkout. A reproducible matched scene overlay is still pending; the plans are schematic and do not provide exact dimensions/elevations. Detailed stair drawings remain `REFERENCE_MISSING`, and the supplied Level-3 plan does not show the story-required WC Nam.

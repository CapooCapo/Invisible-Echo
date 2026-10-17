# Environment Design Spec — Batch 1 plus Level 1/2 bay correction

**Status:** Batch 1 implementation in progress; not a whole-school sign-off.
**Production scene:** `res://scenes/01_hanh_lang.tscn` → `night_school_visual` → `NightSchoolViewport/NightSchool`, with the mapped campus under `MappedSchoolEnvironment`.
**Scope boundary:** Stair B landing connector, north gallery/east-wing turn, WC Nam approach and interior; plus the explicitly requested Level-1/2 side-room enlargement and Principal's Office identity/furnishing. Level 3, rooftop, story beats, save state, and controller behavior remain unchanged by the room-shell batch.

## Fixed architectural decisions

- Keep 3.2 m floor-to-floor elevation used by the production campus.
- Room shells on the approved plan are contiguous: adjacent rooms share a separating wall, with no unintended air gaps between their bounds. Doors/windows are intentional openings; partitions and adjoining wall ends must meet cleanly. Apply this rule to future school batches as well as this WC; do not use it to justify changing approved room positions.
- Preserve the open-to-courtyard U plan. No bridge across the courtyard and no deletion of the atrium guardrail.
- Treat mapped `WC NAM` at `(19, 6.4, 1)` with a `10 × 6 m` footprint as the only authoritative room shell. Story code may add interaction-only objects, not a second floor/wall/cubicle shell.
- Provide only the local connector and guardrail opening needed to link Stair B’s L3 landing to the north gallery. Protect the exposed south edge with a local guard.
- Keep the current doorway, story thresholds, and room footprint stable while the vertical slice is tested.
- For the current Level-1/2 side-room correction, use game-scale dimensions as a provisional blockout because the supplied schematic plan images have no exact surveyed dimensions or elevation schedule. Keep all three stair alignments, landings, access returns, corridor door openings, and the east Level-2 bypass clear.

## Visual direction for this slice

- Older Vietnamese public high school at night; PS2-inspired low-poly silhouettes, restrained saturation, worn but readable surfaces.
- Corridor: concrete/tile surfaces, open-air courtyard edge, guarded rail, classroom openings and readable wayfinding. Keep the walking line and turn visible.
- WC: aged ivory plaster over blue-grey damp dado; worn ceramic floor; painted-metal partitions; concrete ceiling; paired vanity fixtures around a clear central aisle; readable WC Nam sign.
- Lighting: cold fluorescent fill with restrained emergency red accent. Preserve sufficient light for the door, threshold, floor edge, and puzzle affordances; do not use fog to hide unfinished geometry.
- Exterior night backdrop: dark navy Godot procedural gradient with a sparse project-generated equirectangular star cover. Keep the celestial background subdued; the authored ambient level and local school fixtures remain responsible for architecture readability.
- Keep props at perimeter and preserve the hide route and camera envelope.

## Current implementation notes

- The P0 connector, mapped WC shell, cubicle partitions, and fixture placements are generated in `scripts/visual/school_environment_3d.gd`; the overlay in `scripts/visual/night_school_3d.gd` owns only story interactions, the door/mirror-event surface, wayfinding, and local lighting.
- The WC uses existing project-owned school textures: `floor_ceramic.png`, `old_plaster.png`, `damp_base.png`, `painted_metal.png`, and `ceiling_concrete.png`.
- The WC main door fills the mapped `1.55 m` west-wall aperture until its jamb interaction opens it. The mapped first cubicle has a closed door leaf/collider and aligned hide bounds; toilet/cistern, basin/faucet, and urinal visuals are project-authored low-poly GLBs. The twin basin assets are integrated into one continuous vanity top with basin cutouts.
- The gameplay prompt for the production WC door was previously parented under a hidden dialogue panel. It now moves into a bottom-center gameplay HUD when no panel is shown and returns to the dialogue column for panel beats. The HUD is suppressed while opening/dialogue/death overlays are active; the targeted regression checks the WC approach, overlay state, panel state, and real KEY_E interaction.
- Level-3 corridor benches were moved to a wall-side strip and rotated along the corridor axis, into wall segments between the classroom/WC door openings. Only visual, non-colliding bench geometry on Level 3 changed; other floors, openings, and structural geometry did not.
- Blender source fixtures use a +90° X root conversion to reconcile their Y-up authored dimensions with Blender's Z-up scene convention before GLB export. Production inspection confirmed the two basin models at `(16.2,6.4,3.68)` and `(18.2,6.4,3.68)`; their rim tops are approximately `y=7.27`, while the event mirror center is at `y=7.96` above the mapped floor `y=6.4`.
- A fresh X11 production capture set is present at `builds/visual-qa/environment-recovery-20261015/gui_wc_final_20261015/`. It shows the opened threshold, a toilet inside the mapped stall, and both basins beneath the reflection/writing event. The 2026-10-16 gameplay-HUD frame is `builds/visual-qa/environment-recovery-20261016/wc_prompt_hud_after_bench.png`; it shows the E prompt and the corrected wall-side bench placement. These are staged visual-composition captures, not input-driven gameplay evidence; whole-slice visual acceptance remains pending.
- The fresh post-bench real-input production route trace is `builds/visual-qa/environment-recovery-20261016/production_route_after_bench_reposition.log`; it reaches the WC, first-stall hide event, and mirror trigger. This is gameplay/navigation evidence, not a camera sweep or visual-pass claim.
- Reusable architecture module library (wall/door/window/stair scenes) has **not** been extracted by this batch. The restroom fixture GLBs are room-specific reusable props, not an architecture module library.

## Requested Level-1/2 room-bay correction

These are implementation dimensions, not measurements transcribed from the supplied schematic plan images. The side-room shells still follow the mapped room functions; the recessed north bays remain behind their existing return planes.

| Level / room | Approximate bounds (X, Z) | Size |
|---|---:|---:|
| Ground — Principal's Office | x `[-18,-14]`, z `[-17.9,-9.5]` | `4×8.4 m` |
| Ground — Đoàn office | x `[-24,-14]`, z `[-9.5,-1.1]` | `10×8.4 m` |
| Ground — Class 1 | x `[14,18]`, z `[-17.9,-9.5]` | `4×8.4 m` |
| Ground — Class 2 | x `[14,24]`, z `[-9.5,-1.1]` | `10×8.4 m` |
| Level 2 — Club 1 | x `[-24,-13.5]`, z `[-17.9,-9.5]` | `10.5×8.4 m` |
| Level 2 — Club 2 | x `[-24,-13.5]`, z `[-9.5,-1.1]` | `10.5×8.4 m` |
| Level 2 — Practice | x `[14,18]`, z `[-17.9,-9.9]` | `4×8 m` |
| Level 2 — IT | x `[14,24]`, z `[-9.9,-1.9]` | `10×8 m` |

At each adjacent seam, the southern shell emits one collidable north partition across its footprint; the northern shell suppresses its duplicate south end wall, cornice, skirting, and exterior corner pier. Where adjoining bays have different widths, that single end-wall continuation also closes the wider room's unmatched end without overlapping a second collider. Ground north bays remain recessed to x `±18` to preserve the existing ground-floor A/C returns. The Level-2 practice bay remains at x `[14,18]`, leaving the bypass at x `[20.6,23.4]`, z `≈−14` unobstructed; the outer facade remains at x=24 and its infill stops at the exact IT room bounds to avoid duplicate window/wall geometry.

The ground Class-1 deeper bay uses two separated exterior windows so no pane crosses the east return at z≈−14. The expanded wider classrooms, Level-2 clubs, practice room, and computer room receive additional desks/seats/stations. The Principal's Office now has a larger corridor identity plaque, an interior `PHÒNG HIỆU TRƯỞNG / BAN GIÁM HIỆU` board, and consultation seating. This source-level change has only received Godot parse/import validation; gameplay clearances and visual review remain pending.

## Reference status

- Viewed project references: `docs/art_references/hallway_concept.png` and `docs/art_references/restroom_mirror_concept.png`.
- The floor 1/2/3/rooftop plan images are accessible from the inbound conversation attachments documented in `docs/architecture_audit/ROOM_MAPPING.md` and were reviewed, but are not copied into the repository. A reproducible matched runtime-overlay review is still pending because these are schematic plans without a dimension/elevation schedule. Detailed stair drawings remain `REFERENCE_MISSING`; the supplied Level-3 plan also omits the story-required WC Nam, so its plan amendment is unresolved.
- Concept images guide material, lighting, and composition only; they do not override the approved room/stair layout.

## Acceptance state

See [`ROOM_COMPLETION_MATRIX.md`](ROOM_COMPLETION_MATRIX.md), [`VISUAL_COMPARISON.md`](VISUAL_COMPARISON.md), and [`NAVIGATION_TEST_REPORT.md`](NAVIGATION_TEST_REPORT.md). Fresh GUI composition and an independent input-driven production route through Stair B, WC Nam, hide/exit, and mirror E have been verified. Full visual review remains pending; no visual PASS is claimed.

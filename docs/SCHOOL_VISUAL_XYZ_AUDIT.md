# School 3D visual/XYZ audit — 2026-10-14

Status: **measured and partially corrected, not final art sign-off**. Values below
are Godot metres in the playable `MappedSchoolEnvironment` attached to the real
`01_hanh_lang` main scene. +X is east, -Z is north; Y is height. The four supplied
floor plans are approximate references, not CAD measurements.

## Scale and collision

| Element | Current measured/declared value | Review |
| --- | --- | --- |
| Storeys | floor Y = 0, 3.2, 6.4; rooftop Y = 9.6 | Consistent 3.2 m floor-to-floor spacing. |
| Room outer walls | 3.12 m high, 0.20 m thick; room ceilings at Y + 3.08, 0.12 m thick | Inside art-bible 2.8–3.5 m range. |
| Corridor-facing walls | 3.0 m high, 0.20 m thick | Collidable geometry, separated around entrances. |
| Room doors | north rooms: 1.50 m opening; side rooms: 1.55 m opening; leaf/jamb ~2.25–2.30 m high | Wider than the 0.46 m player capsule; movement checks remain required. |
| Classroom 1 | 4 × 6 m at (16, 0, -17); board 2.75 × 1.20 m, centre Y 1.82 | Imported GLB furniture root rotated +90° about X: tabletop now horizontal at Y 0.785–0.895, rather than vertical and below floor. |
| Other classrooms | student top ~0.78 m high, 0.82 × 0.62 m; teacher top ~0.82 m; benches ~0.46 m seat height | Replaced floating slab-only desks with top, legs, apron, and bench. Narrow 4 m rooms use one desk column so it remains inside walls. |
| Gate | pillars X ±2.70, Z 34, 0.75 × 3.40 × 0.75 m; clear entrance ~4.65 m | Outward-facing name board at Z 34.30 and lanterns now render from outside; leaves open inward, decorative/non-colliding. |
| Stage/fountain/flag | stage 15 × 6 m, top Y 1.30; fountain radius ~3.2 m at Z 10; pole top Y 10.6 | Canopy now has four collidable posts; aged curtain/motto and outward-facing yellow flag star are visible. Composition still needs art review. |
| Trees/grass | four planted positions X -21/-15/15/21 at Z 12; ~4–4.7 m tree height; two 1.3 × 31 m planted verges near X ±24.1 | Cylindrical trunks, varied canopy clusters, planter soil and 452 narrow three-blade grass tufts in one MultiMesh; no grass collision or blocked central axis. |

## Texture/material audit

All seven source school textures are 256 × 256 PNGs. The project applies world-
space triplanar UVs to these materials so neighboring modular pieces share a
scale. Tile is 2 repeats/metre (~0.5 m motifs); all other textured materials are
0.5 repeats/metre. Albedo tint multiplies each texture; wood and iron tints were
raised after a GUI image showed furniture sinking into black.

| Texture | Used on | Current observation |
| --- | --- | --- |
| `old_plaster.png` | upper walls | Mottled plaster reads, but large uninterrupted facades remain plain. |
| `damp_base.png` | lower wall band | Continuous muted blue-gray lower register. |
| `floor_ceramic.png` | rooms and level corridors | Previous 1 m tile motif looked overscale; now ~0.5 m. |
| `ceiling_concrete.png` | ceilings, roof and yard hardscape | Matte/weathered; stage is still visually sparse. |
| `worn_wood.png` | school desks, doors, stage | Brighter tint restores visible grain on student furniture. |
| `painted_metal.png` | furniture legs, gate, fixtures | Brighter tint restores leg visibility without glossy finish. |
| `notice_felt.png` | green classroom boards | Board surface/wood frame/tray visible, but generic boards are still blank. |

The stage backdrop also uses an existing 1024² weathered concrete asset. This
audit has not independently rechecked that asset's source/license.

## Runtime image evidence

`tests/visual_school_runtime_capture.gd` instantiates the actual main scene,
requires `MappedSchoolEnvironment` in its `NightSchoolViewport`, and writes 960 × 540 PNGs in the Git-ignored
`builds/visual-qa/` folder. It must run with a GUI display, not `--headless`.

Checks actually run: `test_school_environment_3d.gd` passed 67/67 on the
final geometry/grass state; `test_classroom_1_exploration.gd` passed 15/15
and `test_live_school_entry_regression.gd` passed 46/46 before the later
decorative stage/grass additions. The GUI capture completed all seven views
after those additions and fails if the mapped school is absent.

| Image | What the image proves / does not prove |
| --- | --- |
| `school_gate_main_runtime.png` | Gate now has legible Vietnamese school name and two warm lamps. It remains a simple low-poly concrete portal. |
| `school_yard_main_runtime.png` | Building wings, stage, flag/star, fountain, and varied trees render. Yard is still broad/empty and distant facades lack composition/detail. |
| `school_stage_main_runtime.png` | Canopy posts, stairs, fascia, curtain and school motto render at close range. Large dark overhang and sparse stage dressing remain. |
| `courtyard_tree_main_runtime.png` | Irregular low-poly canopy clusters, branches, planter soil and verge/planter grass render close up. Tree bark/leaf/grass are still flat-color, not final authored assets. |
| `classroom_1_main_runtime.png` | Authored furniture lies flat and the board, windows, fixture, and material textures render. Camera angle is a single viewpoint, not a full room review. |
| `classroom_3_main_runtime.png` | Formerly near-black generic room now shows six complete student desks/benches, teacher desk, board, and floor tile. It still reads as repeated low-poly props rather than finished dressing. |
| `north_gallery_main_runtime.png` | Circulation and floor/wall textures are visible; broad facades and corridor repetition still need art direction. |

## Remaining quality gates

- The current geometry is an **early PS2-style slice**, not a complete environment.
  Dress the large blank facades, stage, corridor, classrooms and service rooms
  with believable reuse/variation, while keeping story routes clear.
- Inspect all rooms and storeys from multiple gameplay camera positions; the seven
  images above do **not** prove every wall/desk/texture or gameplay sightline.
- Profile compatibility renderer draw calls and light overlap on the target
  machine. The procedural school has thousands of MeshInstance3D nodes; the new
  room lights are local, non-shadowed, and may still require batching/LOD.
- Compare side-by-side with the user's courtyard/corridor/classroom A–C images
  once those reference images are available as files. This report cannot claim
  that match from the current captures alone.
- The Windows export and the user's running Editor/F5 instance were not
  observed during this audit. A process launched before these disk edits may
  need an Editor filesystem rescan/restart before its F5 view updates.

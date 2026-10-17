# School Architecture Audit — Visible Echo checkout

**Audit status: `AUDIT_COMPLETE — ARCHITECTURE_FAIL`**  
**Mode:** `READ_ONLY_ARCHITECTURE_AUDIT_FIRST`  
**Audit date:** 2026-10-15  
**Repository:** `/home/giahoang/dev/invisible-echo`, branch `main` tracking `origin/main`  
**Engine:** Godot 4.7.2 (project feature string: 4.7)

This is an evidence report, not a geometry sign-off. No scene, gameplay, import, or save file was changed for this audit. Four source floor-plan images and existing runtime captures were inspected. The floor plans are schematic, top-down drawings; they do not define floor elevations or most room dimensions.

## Executive findings

| Severity | Finding | Status |
|---|---|---|
| P0 | The main-story route from Stair B’s level-3 landing into the east-wing gallery is physically blocked by the full-width `North Atrium Rail`; the actual player controller stalls on its collision. | OPEN — route fails |
| P1 | Staircase A and C switchback flights run north/south in code, while all three supplied plans show their travel direction east/west. Stair B agrees with the plans. | OPEN — plan mismatch |
| P1 | On floor 1, the active source assigns the north west-wing room to the Principal and the south room to the Đoàn office, opposite the supplied plan. | OPEN — rooms swapped |
| P2 | Floor 2’s third club room is present at the planned bay but named only `PHÒNG CLB`, omitting the plan’s ordinal identity `CLB 3`. | OPEN — label/identity gap |
| CONFLICT | The plans contain no floor elevations. The active code uses 3.2 m floor-to-floor, while the request cites historical candidates 4.2/3.6/3.7 m. Which elevation is approved is unresolved. | DECISION NEEDED before height changes |
| CONFLICT | The floor-3 plan does not label a men’s WC, while the current story requirement mandates one. Current code places it at the east-wing end after Class 2; this is a proposed/localized story addition, not present in the drawing. | Proposed location documented; approval of plan amendment not evidenced |

The standalone school harness demonstrates that each stair’s ramp and switchback geometry can be climbed and descended by `HoangController3D`. That does **not** establish that the intended main-story route works: the production story route is blocked at the north gallery/east-wing junction. No overall architectural `PASS` is warranted.

## Repository and runtime provenance

- The brief’s `/home/giahoang/dev/an-tieng-gay-trong-dem` path does not exist in this workspace. The actual checkout is `/home/giahoang/dev/invisible-echo`.
- Before audit documentation was added, `git status` already showed extensive modifications and untracked files, including the active school scripts/scene, controller/gameplay, tests, assets, and two school mapping/audit documents. Those pre-existing changes were left untouched. The five files in this directory are the only audit deliverables added by this audit.
- Current scene and activation chain are verified from source: `project.godot:14` selects `res://scenes/01_hanh_lang.tscn`; `scripts/game.gd::_ready()` calls `_build_night_school_visual()`; this builds the `NightSchool3D` `SubViewportContainer` and loads `scripts/visual/night_school_3d.gd`; its `_ready()` instantiates `MappedSchoolEnvironment` from `res://scenes/visual/school_environment_3d.tscn`. That script generates the active school geometry and colliders. The imported `TestNEHSchoolCampus` is retained in the runtime tree but hidden and has collision disabled; the legacy blockout is also not the active architecture. Thus the mapped procedural environment, not the imported campus scene, is the school being audited.
- Active architecture source: `scripts/visual/school_environment_3d.gd`; scene wrapper: `scenes/visual/school_environment_3d.tscn`; production story wrapper: `scripts/visual/night_school_3d.gd`; player: `scripts/visual/hoang_controller_3d.gd`.
- No active `NavigationRegion3D`/navigation mesh was found in the audited school scene path. Physical corridor/stair traversal, rather than navmesh routing, is the relevant evidence here.
- Supplied plan images are conversation attachments, not repository assets. The plan interpretation and coordinate convention are recorded in [ROOM_MAPPING.md](ROOM_MAPPING.md). No source image was copied or edited.

## Runtime and geometry model

The active builder sets `FLOOR_HEIGHT = 3.2`, floor origins at Y=0, 3.2, and 6.4, and rooftop origin at Y=9.6. The map coordinate convention is +X east, -Z north, Y up. Main building cores are nominally at X=-21/0/+21, Z=-22.5. The U-shaped footprint has a north bar, west/east wings, and an open central courtyard/lightwell on upper floors. The courtyard objects (stage, fountain, flagpole) are generated once on the ground.

Room dimensions below are generated implementation dimensions, **not** dimensions read from the schematic plan. The actual floor-plan artwork provides a scale bar but no elevations and no per-room dimension schedule. See [ROOM_MAPPING.md](ROOM_MAPPING.md) for each room bay and its classification.

## Defects

### ARCH-001 — Production story route blocked at the north gallery rail

- **PRIORITY:** P0
- **BUILDING:** School
- **FLOOR:** Floor 3 / level 3 (`Level3`, Y≈6.4 m)
- **ROOM_ID:** `F3-GALLERY-EAST-JUNCTION`
- **SCENE_PATH:** `res://scenes/01_hanh_lang.tscn` → runtime-generated `NightSchool3D/NightSchoolViewport/NightSchool/MappedSchoolEnvironment/Level3`
- **NODE_PATH:** `Level3/North Atrium Rail topBody`
- **EXPECTED:** From Stair B’s level-3 landing, the playable gallery connects around the courtyard edge to the east-wing corridor and the story-mandated WC Nam route. The rail protects the atrium edge without sealing the corridor connection.
- **ACTUAL:** With the real `HoangController3D` in the production story wrapper, the player reaches the north gallery, moves east to X≈11.94, then stalls when moving south toward the east wing. Last recorded player position `(11.93639, 6.51984, -18.18984)`; contact `(11.93639, 7.78, -17.96)`; collision normal `(0,0,-1)`. Collider path is `.../MappedSchoolEnvironment/Level3/North Atrium Rail topBody`.
- **EVIDENCE:** Main-scene input-driven trace; the controller was not teleported during this route. Source `scripts/visual/school_environment_3d.gd:1188-1191` creates the north rail at `z=-17.9`, width 40 m, height 1.35 m; `_rail()` at `:1325-1332` creates colliders for top rail and balusters. The geometry spans the junction rather than leaving a corridor gap. The story code at `scripts/game.gd:566-569` switches to `upper_hall` as soon as player Y reaches 6.0 and tells the player to turn right toward WC Nam before the route is proven clear. Separately, an immediate east turn from the B landing dropped into the courtyard void; the southbound rail contact is the measured blocker. **Reproducibility limit:** the temporary raw trace harness/log was not retained as a repository artifact; the coordinates and collider path were recorded during the runtime investigation and are cross-checked against the source geometry.
- **ROOT_CAUSE:** One continuous collision-enabled north atrium guardrail crosses the north gallery/east-wing junction. Story phase promotion is based only on elevation and can issue a route prompt before a traversable gallery position is established.
- **PROPOSED_FIX:** Preserve fall protection on the exposed atrium boundary but design an intentional protected opening/turn/connector at the wing junction; do not simply remove safety rails wholesale. Start the WC objective only after the player reaches a stable gallery waypoint. Keep WC Nam at a corridor-accessible location unless the plan owner approves a different placement.
- **DEPENDENCIES:** Approved floor-3 circulation drawing; approved railing/opening treatment; reconciliation of current 3.2 m floor height; confirm story waypoint/route contract.
- **VERIFICATION_METHOD:** In the production main scene, use the real controller and input only from the yard checkpoint; record a continuous route Floor 1 → B → Floor 3 north gallery → east wing → WC door, with no falling, teleport, collision stall, or hidden wall. Then test return and C/A entry routes and check rail safety at the remaining void edges.
- **STATUS:** OPEN — production route fails at a measured collider. No geometry fix has been applied.

### ARCH-002 — Floor-1 west-wing offices assigned to opposite bays

- **PRIORITY:** P1
- **BUILDING:** School
- **FLOOR:** Floor 1 (`Ground`)
- **ROOM_ID:** `F1-PRINCIPAL`, `F1-DOAN`
- **SCENE_PATH:** `res://scenes/visual/school_environment_3d.tscn` → generated `Ground`
- **NODE_PATH:** `Ground/PHÒNG HIỆU TRƯỞNG`; `Ground/PHÒNG ĐOÀN`
- **EXPECTED:** Supplied floor-1 plan puts the Đoàn office in the north west-wing bay and the Principal office in the south west-wing bay.
- **ACTUAL:** Source creates `PHÒNG HIỆU TRƯỞNG` centered at `(-16,0,-18)` with 4×6 m footprint (north bay), and `PHÒNG ĐOÀN` at `(-18.75,0,-8)` with 10.5×6 m footprint (south bay).
- **EVIDENCE:** Four floor plan attachments inspected; code `scripts/visual/school_environment_3d.gd:1203-1207`; current runtime room manifest `builds/visual-qa/rooms-audit-release-20261015-v8/rooms_manifest.json` records both room centers and captured views `01_ground.png`/`02_ground.png`.
- **ROOT_CAUSE:** The two room identities/locations in the level-0 builder do not follow the north/south assignment in the approved plan.
- **PROPOSED_FIX:** After verifying the plan’s exact bay dimensions and door orientation, swap room identities/footprints to the approved bays without changing the west-wing circulation or stair A access.
- **DEPENDENCIES:** Confirmed plan image and no newer approved revision; preserve required stair-A passage.
- **VERIFICATION_METHOD:** Compare plan overlay and runtime top-down measurements, inspect both entrances from corridor, and input-walk each office door in the production scene.
- **STATUS:** OPEN — direct plan/source mismatch; not corrected.

### ARCH-003 — Stair A/C flight axes disagree with plan arrows

- **PRIORITY:** P1
- **BUILDING:** School
- **FLOOR:** Floor-to-floor flights on Floors 1–3 and to roof
- **ROOM_ID:** `STAIR-A`, `STAIR-B`, `STAIR-C`
- **SCENE_PATH:** `res://scenes/visual/school_environment_3d.tscn` → generated `Ground/Level2/Level3/StairCore*`
- **NODE_PATH:** `StairCoreA/ContinuousWalkRamp A L*`, `StairCoreB/ContinuousWalkRamp B L*`, `StairCoreC/ContinuousWalkRamp C L*`
- **EXPECTED:** Supplied floor-plan arrows indicate Stair A and C travel east/west (+X axis) and Stair B north/south (-Z axis) on each floor plan.
- **ACTUAL:** `_build_stair_core()` creates every run along Z using ramp box size `(1.8,0.2,sqrt(rise²+run²))` and `rotation.x`; A/C therefore do not follow their plan axes. B follows the north/south axis. Cores are otherwise located at aligned X=-21, 0, and +21.
- **EVIDENCE:** Floor 1, 2, and 3 supplied plan arrows; code `scripts/visual/school_environment_3d.gd:1333-1392`, especially `:1375-1390`. The captures `builds/visual-qa/stairs-audit-20261015-v1/stairs_contact_sheet.jpg` and individual A/B/C views show generated staircases, but do not override the plan’s directional requirement.
- **ROOT_CAUSE:** Stair builder uses a shared Z-axis switchback for all core labels rather than a per-core orientation transform.
- **PROPOSED_FIX:** Introduce per-core orientation only after validating that each plan arrow denotes flight axis (and reconciling the separate detailed stair drawings). Rotate full stair assembly, landings, railings, openings, and labels as a unit; do not rotate only the ramp mesh.
- **DEPENDENCIES:** Reconcile plan arrows against detailed stair A/B/C diagrams; preserve aligned core locations and shared floor elevations.
- **VERIFICATION_METHOD:** Compare each oriented core in a top-down overlay and run the actual controller up/down each flight in the production scene, including landings and roof exits.
- **STATUS:** OPEN — visible source mismatch, pending drawing reconciliation.

### ARCH-004 — Floor-2 third club room loses its planned identity

- **PRIORITY:** P2
- **BUILDING:** School
- **FLOOR:** Floor 2 (`Level2`, Y=3.2 m)
- **ROOM_ID:** `F2-CLUB-3`
- **SCENE_PATH:** `res://scenes/visual/school_environment_3d.tscn` → generated `Level2`
- **NODE_PATH:** `Level2/PHÒNG CLB`
- **EXPECTED:** Plan identifies this north-bar bay as the third club room (`CLB 3` / `Phòng CLB 3`). Do not silently convert it to the chess club unless the story source requires it.
- **ACTUAL:** Correct bay exists at center `(-4,3.2,-27)`, 4×7 m, but source labels it only `PHÒNG CLB`.
- **EVIDENCE:** Supplied floor-2 plan; `scripts/visual/school_environment_3d.gd:1215-1223`; runtime view `14_level2.png` and room manifest.
- **ROOT_CAUSE:** Generic runtime label drops ordinal identity from the plan.
- **PROPOSED_FIX:** Preserve the room use and footprint; after checking authoritative story naming, label it `PHÒNG CLB 3` or keep an explicit documented alias.
- **DEPENDENCIES:** Resolve the source-of-truth for chess-club placement in [DESIGN_CONFLICTS.md](DESIGN_CONFLICTS.md).
- **VERIFICATION_METHOD:** Check runtime sign/interaction identity and confirm no other floor-2 room has been repurposed.
- **STATUS:** OPEN — room shell present; naming/identity unresolved.

## Tests and runtime evidence

| Check | Result | What it proves / does not prove |
|---|---|---|
| `godot --headless --path . --script res://tests/test_school_stairs_physics.gd` | PASS: `SCHOOL_STAIRS_PHYSICS_PASS checks=18` | Real `CharacterBody3D` uses InputMap from ground spawn, climbs and descends A/B/C to roof in standalone `school_environment_3d.tscn`. Does not include main story wrapper’s north gallery rail/corridor route. |
| `godot --headless --path . --script res://tests/test_stair_b_gate_route_regression.gd` | PASS: `STAIR_B_GATE_ROUTE_PASS` | Gate to Stair B and first landing route. Not full route to WC. |
| Corrected temporary controller-input Stair-C→WC route | PASS, standalone geometry | Actual controller reaches floor 3 and physically enters the modeled WC through its corridor opening. Not the production story overlay, not a main-scene end-to-end pass. |
| Production story B→east-wing route trace | FAIL at `North Atrium Rail topBody` | Exact P0 collider and player/contact position above; no teleport used during movement. |
| `tests/test_live_school_entry_regression.gd` | FAIL: 9 of 46 checks | Contains stale direct-path assumptions for room/door nodes; confirms some route checks but is not proof of nine missing rooms. Preserve the failures as test-suite maintenance work. |
| `tests/test_school_environment_3d.gd` | FAIL on stale direct door-body path and final WC route assertions | Door body is nested under the generated hinge pivot, not the old flat path. A corrected manual C→WC input trace succeeds; the original failing assertion remains a real test failure, not silently treated as pass. |

Existing runtime captures: `builds/visual-qa/rooms-audit-release-20261015-v8/` contains 28 room views and a manifest; `builds/visual-qa/stairs-audit-20261015-v1/` contains A/B/C views and a contact sheet. They establish that captured views rendered. They do not establish every route, room’s interactivity, complete visual parity, or target-hardware performance. The WC yaw views are too dark/occluded for visual sign-off. No architecture `PASS` is inferred from headless scene loading or capture generation.

## Unverified / not a defect claim

- Complete playable access to every room has not been traversed; see room classification in [ROOM_MAPPING.md](ROOM_MAPPING.md). “Modeled” and “captured once” are not equivalent to “playable”.
- Visual comparison against the historical stair-specific concept photos could not be completed to the same confidence as the plan/runtime comparison; only project captures/contact sheet and the in-repository school art direction were directly available in this audit. Mark stair style parity `VISUAL_UNVERIFIED` pending source images and matched viewpoints.
- Production story restroom overlay/collision behavior was not proven end-to-end after the B corridor junction; standalone map access is not equivalent.
- Exact intended camera clip clearances at all turns/landings have not been measured. Controller config is known (`Camera3D`, first-person, spring length 0, FOV 76°), but no camera sweep or production visual sign-off was run.
- Independent read-only review returned **APPROVED** on 2026-10-15; see [FIX_PLAN.md](FIX_PLAN.md). The reviewer did not run tests or modify files. The detailed A/B/C source drawings were not available among verifiable repository references, so the axis reconciliation remains unresolved.

## Related audit documents

- [Room and floor mapping](ROOM_MAPPING.md)
- [Staircase structural and route audit](STAIRCASE_AUDIT.md)
- [Design conflicts and source gaps](DESIGN_CONFLICTS.md)
- [Prioritized fix plan](FIX_PLAN.md)

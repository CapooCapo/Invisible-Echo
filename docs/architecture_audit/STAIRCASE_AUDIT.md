# Staircase A/B/C structural and traversal audit

**Status:** stairs’ isolated continuous traversal passes; integrated production circulation does not.  
**Active builder:** `scripts/visual/school_environment_3d.gd::_build_stair_core()`  
**Player:** `scripts/visual/hoang_controller_3d.gd` (`CharacterBody3D`, production controller).

## Shared elevation schedule — as implemented, not approved

| Level | Code node | Floor origin Y | Notes |
|---|---|---:|---|
| Floor 1 | `Ground` | 0.0 m | Floor mesh top approximately +0.12 m. |
| Floor 2 | `Level2` | 3.2 m | Current code’s uniform `FLOOR_HEIGHT=3.2`. |
| Floor 3 | `Level3` | 6.4 m | Current code’s uniform `FLOOR_HEIGHT=3.2`. |
| Rooftop | `Rooftop` | 9.6 m | `LEVELS * FLOOR_HEIGHT`. |

This is a single internally consistent code schedule. It is **not confirmed as the approved architecture**, because the supplied plans contain no elevations and the request cites previous 4.2/3.6/3.7 m alternatives. See [DESIGN_CONFLICTS.md](DESIGN_CONFLICTS.md); no height was changed.

## Implemented stair geometry

- Core bases align at `A=(-21,0,-22.5)`, `B=(0,0,-22.5)`, `C=(21,0,-22.5)`; the builder places corresponding cores at each floor root.
- Each inter-floor switchback flight uses `rise=3.2 m`, `run=6.0 m`, 18 visible treads, tread box size 1.8×0.16×0.42 m, and a smooth collision ramp 1.8 m wide, 0.2 m thick, and about 6.8 m long. Nominal angle is `atan(3.2/6.0) ≈ 28.1°`.
- Landings are split slabs with a 5.0 m overall width, 2.8 m depth, and transfer-lane pads. The active code leaves space between switchback ramp lanes to avoid underside collisions.
- Side-rails are built per flight and contain colliders. Floors 2/3 cut stair openings from the slabs. Rooftop cutouts are present and roof-level guardrails/exit frames are generated.
- Per-core locations align; **flight axis does not**: shared geometry runs along Z for all cores. The supplied plans show A/C travel east and B north/south. See ARCH-003.

## Checks by core

| Core | Plan axis | Actual generated axis | Isolated climb/descent | Integrated production route |
|---|---|---|---|---|
| A | East/west (+X) | North/south (Z) | PASS in standalone test to roof and back | Not completed from story wrapper; full corridor access not proven |
| B | North/south (-Z) | North/south (Z) | PASS in standalone test to roof and back | Reaches level-3 north gallery; east-wing route blocked at `North Atrium Rail topBody` (P0) |
| C | East/west (+X) | North/south (Z) | PASS in standalone test to roof and back; separate corrected route reaches WC | Standalone C→WC passes; equivalent production story route is not verified |

“PASS” in isolated test covers continuous input-driven ramp/landing traversal inside the standalone school environment. It is not a pass for the actual production story route or for plan orientation.

## Real player and collision configuration

`HoangController3D` is a real `CharacterBody3D`; it has a 0.23 m radius / 1.55 m height capsule, collision mask 1, gravity 18 m/s², floor snap 0.25 m, and uses `move_and_slide()`. Its camera is first-person at a 1.42 m pivot, spring length 0, FOV 76°, near clip 0.08 m. The actor is instantiated in the main story `SubViewport` and receives the yard spawn. No teleport was used during the recorded travel tests; the test harness begins at the actual standalone yard spawn.

## Evidence and failure localization

1. **Standalone stair physics:** `godot --headless --path . --script res://tests/test_school_stairs_physics.gd` emitted `SCHOOL_STAIRS_PHYSICS_PASS checks=18`. The harness drives actual input from gate/yard, climbs A/B/C to rooftop, then descends.
2. **Stair B gate regression:** `godot --headless --path . --script res://tests/test_stair_b_gate_route_regression.gd` emitted `STAIR_B_GATE_ROUTE_PASS landing=true level2=(-1.184595,3.320188,-26.10839)`. This covers only the entry/first landing behavior.
3. **Standalone Stair-C to WC:** a corrected temporary controller-input trace, not saved in the repo, traveled from yard through Stair C, around the level-3 east-wing classroom to the corridor and into the WC. Last position `(15.56449,6.520232,1.485276)`, grounded. No mid-route teleport. This proves the standalone geometry’s C-side route, not the story overlay.
4. **Production story Stair B:** the real main-scene wrapper advances to `upper_hall` when player Y reaches 6.0. From the north gallery, an input-driven south move toward east wing stalls on `Level3/North Atrium Rail topBody`: player `(11.93639,6.51984,-18.18984)`, contact `(11.93639,7.78,-17.96)`, normal `(0,0,-1)`. Source `school_environment_3d.gd:1188-1191` constructs a 40 m north rail across that junction, and `_rail()` at `:1325-1332` gives it collision. This is an observed collider block, not an inference from node presence.
5. An immediate east turn from the B landing was also observed falling into the open courtyard void. The measured rail collision remains the localized reproducible blocker; the fall reinforces that the transition/wayfinding is unsafe but was not separately tied to a single collider.

## Other structural checks

- **Direction:** A/C plan arrows conflict with builder axis (ARCH-003). Need reconcile arrows against detailed stair drawings before rotating full cores.
- **Floor-to-floor height:** implementation consistent at 3.2 m; approval not verified.
- **Steps/rise:** 18 visual treads and smooth ramps exist; calculated rise increment is about 0.178 m. Treads are visual, while the continuous ramp is the collision surface. Do not claim discrete-step collision behavior.
- **Width:** 1.8 m ramp width is implemented. Clearance at every rail post/turn has not been completely measured.
- **Landings:** split collision slabs and transfer pads pass the standalone harness. Production landing-to-corridor connection fails at the P0 rail.
- **Floor intersection/openings:** standalone harness demonstrates ascent through floors. Topology still needs production path validation at gallery/wing joints.
- **Handrail:** rails/colliders exist. At a Stair-B landing, one east vertical post required a small lateral bypass in a trace; it was bypassable and is not classified as the P0 blocker. Verify hand clearance and egress after approved axis changes.
- **Wall/rail obstruction:** exact P0 collider above. Other wing-wall contacts were not localized sufficiently to report as defects.
- **Camera clipping:** controller config is known, but no full camera sweep/runtime sign-off was performed. `VISUAL_UNVERIFIED` for every landing turn and roof transition.
- **Navigation regions:** none were found in the active school path; traversal is physical-controller based.

## Required follow-up verification (after an authorized geometry fix)

Use the production story scene and actual controller input from saved story entry/checkpoint; record world coordinates at every landing, collision node path, contact point and normal when blocked. Execute Floor 1→2→3→roof and reverse using A, B, and C. Then execute the story route to WC Nam, each room door/corridor, and school exit. Do not teleport between checkpoints or treat an isolated harness as end-to-end proof. Capture matched camera views and verify rail protection remains continuous around exposed voids.

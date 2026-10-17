# Architecture audit fix plan

**Planning only.** No geometry, gameplay, save, or test code was modified. The order below is dependency-aware; resolve conflicts before a broad architecture change.

## Review state

- Independent review: **APPROVED** (2026-10-15), read-only reviewer. Reviewer verified the runtime activation chain, key source mismatches, defect schema, conflict handling, and that tests/captures were not overclaimed. Reviewer ran no tests and changed no files. Limitation retained: detailed stair drawings were unavailable in the repository references, and the temporary raw P0 trace harness/log is not preserved as a repo artifact.
- No architecture fix is authorized by this audit-only scope.
- Never interpret a passing isolated stair harness as proof that the main story route is fixed.

## Priority sequence

| Order | Scope | Expected files/nodes | Gate / acceptance evidence |
|---:|---|---|---|
| 0 | Confirm one approved vertical schedule; reconcile plan arrows with detailed stair A/B/C drawings; approve the F3 WC plan amendment and canonical chess bay. | Decision/source docs first; likely `docs/SCHOOL_ARCHITECTURE_MAP.md` only after approval. | Written source decision for each conflict in `DESIGN_CONFLICTS.md`; no geometry edits until resolved. |
| 1 | Restore continuous level-3 gallery circulation while retaining safe atrium protection. Fix the premature story route phase/wayfinding if it prompts before a safe connector. | `scripts/visual/school_environment_3d.gd` (`_build_level`, north rail/wing joint) and `scripts/game.gd` (`_process_night_school` upper-hall transition), possibly `scripts/visual/night_school_3d.gd` only if the overlay adds a separate collision. | Production scene, actual-input route from yard → Stair B → level-3 gallery → east wing → WC; no teleport/fall/stall; record collision trace; return route works; edge protection remains safe. This is the P0 gate. |
| 2 | Correct floor-1 office identities/placement. | `scripts/visual/school_environment_3d.gd` room calls around lines 1203–1207; generated `Ground` office shells/doorways. | Approved plan overlay; both offices open to corridor; Stair A path remains clear; real-controller entry/exit. |
| 3 | Orient full Stair A and C structures to approved axes, only after stair-plan reconciliation. | `scripts/visual/school_environment_3d.gd::_build_stair_core`, core transforms, landing/floor openings and rails; tests under `tests/`. | Match plan direction at each level; actual input ascent/descent A/B/C through roof; validate floor openings, side clearance and protected edges. |
| 4 | Preserve/clarify club identities without repurposing a room. | Room label call around `school_environment_3d.gd:1220-1223`; canonical narrative/map source if supplied. | Confirm story authority; runtime sign/node identity matches approved use. |
| 5 | Full room-route and visual QA after structural fixes. | Test scripts and runtime captures; only modify production code for proven defects. | Each required room doorway and story route walked; matched camera views against approved references; visual/camera sign-off; target runtime check. |

## Expected change surface (estimate, not an edit)

- **Likely production geometry:** `scripts/visual/school_environment_3d.gd` (floor openings/rail connector, office assignment, per-core orientation) and possibly `scenes/visual/school_environment_3d.tscn` only if serialized settings are needed. Current active architecture is script-generated.
- **Likely story logic:** `scripts/game.gd` only if the upper-hall state/route prompt is re-timed to a verified connector; inspect and preserve the current story flow.
- **Possible story overlay:** `scripts/visual/night_school_3d.gd` contains `StoryRestroomGameplayOverlay`; inspect its collisions/transform before modifying, because it is not yet proven to cause the current gallery blocker.
- **Tests after approval:** update/add route regression coverage in `tests/test_school_stairs_physics.gd`, `tests/test_stair_b_gate_route_regression.gd`, and an explicit production-story route test. Existing `test_school_environment_3d.gd` and `test_live_school_entry_regression.gd` have stale node-path assumptions; update assertions only after checking actual runtime hierarchy.
- **Decision documentation:** do not overwrite pre-existing docs as part of this audit. After the owner approves resolutions, update the relevant design docs as a separate scoped change.

## Verification contract

For each future fix, capture before/after evidence and log:

1. Production scene path and checkpoint used.
2. Actual player positions at stair entry, each landing, gallery junction, room entrance and exit.
3. Collision node path, contact point and normal for every blocked move.
4. Directional traversal both upward and downward with real controller input. No teleport between route segments.
5. Plan-overlay alignment and one runtime view per affected floor/landing.
6. Regression results, including unchanged save hash and unchanged unrelated dirty files.

The audit remains **not PASS** until the P0 production route succeeds, unresolved design conflicts are decided, and affected visual/runtime views are verified. No commit or push is part of this plan.

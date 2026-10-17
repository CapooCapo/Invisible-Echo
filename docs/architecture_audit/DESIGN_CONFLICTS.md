# Design conflicts and unresolved source gaps

**Rule:** do not silently resolve an architecture-affecting discrepancy by choosing the easiest implementation. This log separates code facts from design authority. No decision below was applied as a code change.

## CONFLICT_FOUND — floor-to-floor elevations

- **Sources:** current request cites historical 4.2 m, 3.6 m, and 3.7 m values; the four supplied plan images are top-down without floor elevations; active `scripts/visual/school_environment_3d.gd:5` defines `FLOOR_HEIGHT := 3.2`, with `Ground`, `Level2`, `Level3` at 0/3.2/6.4 m and roof at 9.6 m. The pre-existing architecture map describes 3.2 m as a starting/current implementation choice, not an elevation approved on an architectural section.
- **Current implemented value:** uniform 3.2 m between each floor.
- **Conflict/gap:** there is no approved vertical section/elevation schedule establishing which historic dimension, if any, is authoritative. The present builder is self-consistent but cannot be called design-approved.
- **Gameplay impact:** any change affects all ramp rises, floor slabs, doors/windows, landings, lighting, roof height, player route and story triggers. Applying different values to different floors would break the shared core geometry.
- **Proposal:** keep the current 3.2 m value as an explicitly unapproved audit baseline; before architectural changes, approve one floor-to-floor schedule for all three storeys and rooftop. Recompute stairs and thresholds together.
- **Status:** OPEN; no height edit made.

## CONFLICT_FOUND — floor-3 men’s WC absent from plan, required by story

- **Sources:** supplied floor-3 plan labels classrooms, vocational rooms, stairs, board and an unlabeled room but no men’s WC. The current request explicitly requires a floor-3 WC Nam with a corridor approach and says not to connect Stair C directly into it. The active builder adds `WC NAM` at `(19,6.4,1)`, after Class 2 at the east-wing end (`school_environment_3d.gd:1239-1241`). Existing architecture map calls this a localized gameplay addition, but no revised floor-plan image incorporating it was found in the audited source set.
- **Current implementation:** 10×6 m room in the east-wing terminal bay with a west/corridor-side opening; a separately instantiated story overlay also participates in the main scene.
- **Gameplay impact:** it is a required story objective. Removing it to match the old drawing would violate the current story requirement; retaining it changes approved-plan use/area and requires the route junction to work.
- **Proposal:** record an explicit plan amendment at the current east-wing terminal location as the least disruptive candidate, keep room/corridor/stair separation, and route from the gallery. Confirm against a revised approved drawing before changing its footprint or displacing another room. There is no evidence here that an existing approved room was deleted to make space.
- **Status:** `CONFLICT_FOUND`; current implementation is modeled, but approved drawing amendment is not verified.

## CONFLICT_FOUND / SOURCE_GAP — chess club identity and level

- **Sources:** supplied floor-2 plan names a `CLB 3` bay, not a chess club. Floor-3 plan shows a bay at `(east end of north bar, immediately west of Stair C)` without a chess label. The pre-existing `docs/ART_BIBLE.md` says canonical Night 1 puts chess on level 3; pre-existing `docs/SCHOOL_ARCHITECTURE_MAP.md` repeats that override but also says the source plan labels a chess club on level 2, which does not match the supplied floor-2 image. `docs/GAME_FLOW.md` identifies Scene 12 as the chess club but does not specify a floor or room bay.
- **Current implementation:** floor 2 bay `(−4,3.2,−27)` is `PHÒNG CLB`; floor 3 east-end north-bar bay `(14,6.4,−27)` is `CLB CỜ VUA`.
- **Gameplay impact:** moving chess changes the canonical story destination; renaming another club room as chess can misidentify both plan and gameplay locations.
- **Proposal:** preserve the current placement during audit; treat level 3 as the existing Art Bible direction, not as an independently verified floor assignment in the canonical flow file. Confirm the authoritative story excerpt/approved location before moving rooms or changing room use. Rename F2 `PHÒNG CLB` to `PHÒNG CLB 3` only if it does not conflict with story assignment.
- **Status:** source conflict/gap; no relocation or reassignment performed.

## CONFLICT_FOUND — stair plan arrows vs shared builder axis

- **Sources:** floor 1–3 plan arrows indicate A and C east/west and B north/south; active stair builder builds all flight geometry along Z. Detailed stair A/B/C drawings are named by the request as a higher-priority source than style images, but were not present as repository files in this audit’s accessible reference set.
- **Gameplay impact:** rotating stairs changes stair openings, landing positions, rails, corridor connections, and route triggers. Rotating only the ramp would introduce new structural/collision defects.
- **Proposal:** retain core centers; before changing axis, compare the full-resolution detailed stair diagrams against plan arrows and approve one axis per stair. Then transform every dependent component as a unit and rerun all route tests.
- **Status:** `CONFLICT_FOUND`; plan/source mismatch is visible, exact intended detailed geometry is not independently verified.

## Explicitly reconciled checks (not conflicts)

- The floor-1 plan shows a WC; the active floor-1 `WC TẦNG 1` exists in the north bar.
- Current requirements prohibit floor-2 teachers’ room and student WC; active source does not add them. Floor-2 teachers’ WC exists as required.
- Current requirements place courtyard, stage, fountain and flagpole on ground only; active builder generates those objects once at ground level. Upper floors use the open atrium.
- Current requirements require three stairs aligned by core; active core centers remain X=-21/0/+21, Z=-22.5 across storeys. Flight direction and traversal-to-gallery remain separate defects.

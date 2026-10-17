# School Architecture Map — Mapping Reference

**Status:** architecture transcription for the next 3D school blockout

**Source:** four user-supplied top-down plans received 2026-10-13 (floors 1–3 and rooftop).
**Style authority:** [`ART_BIBLE.md`](ART_BIBLE.md) remains the visual/style guide. This file records spatial layout, circulation, and scene-mapping decisions; it does not replace the Art Bible.

> The plans are architectural references, not finished game levels. Their scale bars suggest dimensions, but no exact surveyed measurements or CAD source were supplied. Treat all derived dimensions as approximate until measured in a blockout.

## Shared orientation and footprint

- Read each plan with **north at the top**, **east to the right**, and **south at the bottom**.
- For Godot mapping, use **+X = east, -X = west, -Z = north, +Z = south**; Y is elevation. This is a mapping convention, not an existing scene requirement.
- The school has a broadly symmetrical, three-storey main block arranged around a central open courtyard/void, with west and east classroom wings and a north-side central stage/auditorium feature.
- The principal outdoor axis is **south gate → flagpole/fountain → stage → central building/stair B**. Keep this axis legible from the gate.
- Three stair cores repeat vertically: **A** at the west end, **B** near the center of the north block, and **C** at the east end. Treat them as connected vertical circulation, subject to later gameplay gating.
- The attached scale bars are marked 0, 2, 5, 10 m. Use them for a first approximate footprint estimate only; verify clearances, corridor widths, room proportions, and floor heights against the player capsule before locking geometry.
- A practical first blockout may use the Art Bible's 2.8–3.5 m interior-floor guidance and roughly 3.2 m floor-to-floor spacing, but these are implementation starting points, not dimensions stated by the drawings.

## Floor-by-floor room program

| Level | West side / west wing | North block, west → east | East side / east wing | Central feature |
|---|---|---|---|---|
| **1 — Ground** | Principal's office; Đoàn office; stair A | Noticeboard; classroom 3; teachers' room; stair B; classroom 4; shared mid-floor WC; stair C | Classrooms 1 and 2 | Open schoolyard with flagpole/fountain, planted edges and benches; stage/auditorium on the north side; main gate to the south |
| **2** | Stair A; clubs 1 and 2 | Staff WC; library; general club room; stair B; chemistry practice room; storage; stair C | General practice room; computer/news room | Open-to-below atrium overlooking the stage/schoolyard; preserve its void and railing edge. No teachers' room or student WC on this level. |
| **3** | Stair A; vocational practice rooms 1 and 2 | Noticeboard; classrooms/study rooms; stair B; **chess club at the east end of the north block** | Classrooms, stair C, then **men's WC at the end of the right wing** | Courtyard/atrium remains open below; stage and schoolyard are visible from above |
| **Rooftop** | Stair A enclosure and west roof walk | North roof walk; stair B enclosure; stage roof | Stair C enclosure and east roof walk | Open roof/lightwell around the stage roof; perimeter safety rail, no room program shown |

Room labels are transcribed from the supplied drawings. Where labels are blurred or absent (notably some level-3 rooms), keep the space generic rather than inventing a function.

## Circulation and architectural landmarks

1. **Arrival:** south-facing gate opens onto the schoolyard; the fountain and Vietnamese flagpole are the courtyard's central landmark.
2. **Courtyard route:** retain clear routes on both sides of the fountain toward the stage and the surrounding building corridors. The red dashed arrows on the drawings are the intended main pedestrian paths.
3. **Stage:** a raised platform with steps faces south into the courtyard; its roof/overhang is also visible on upper-level plans.
4. **Perimeter corridors:** classroom and office doors open from corridors that run around the courtyard-facing edges. Preserve the repeated bays and sightlines shown on each floor.
5. **Vertical links:** stairs A/B/C align between levels and rooftop. Keep landings, door swings, and stair openings connected rather than treating each plan as an isolated floor.
6. **Upper levels:** maintain the central atrium void and railings; do not fill it with a floor slab. The courtyard/fountain continues visually below.
7. **Rooftop:** perimeter railings define walkable roof routes; the central stage roof divides the large roof area into west and east paths.

## Mapping plan for the new Godot scene

- Build a **standalone architecture/environment scene**, organized into floor groups (`Ground`, `Level2`, `Level3`, `Rooftop`) with named subgroups for the three stair cores, central courtyard/atrium, stage, wings, and major room shells.
- Keep the static floorplan separate from gameplay logic: collision, navigation, door interaction, triggers, and story beats should be attachable/replaceable without changing decorative meshes.
- Block out the footprint, courtyard void, corridor loop, wings, stage, gate, and aligned stairs first. Validate player-scale movement and route connectivity before adding furniture, planting, signage, and lighting.
- Reuse the Art Bible's school materials, Vietnamese public-school visual language, low-poly geometry, matte/worn surfaces, and night-lighting direction. The bright plan colors are category cues, not a requirement to make the game bright.
- Keep the school map's architectural scale and room names distinct from the older three-storey/night-horror concept boards. Use the current floor plans as the **layout authority**; use `ART_BIBLE.md` as the **rendering/style authority**.
- Existing checkout already contains an untracked `scenes/visual/test_neh_school_campus.tscn` plus related test assets. Inspect and preserve that work before deciding whether to reuse pieces or make a clean presentation scene; do not overwrite or silently fold it into the new scene.

## Locked gameplay-specific architecture addition

The approved floor plans do not label a student WC on level 3, but the user's latest production direction explicitly integrates the **Nam WC** required by story Scenes 03–04 at the end of the east/right wing, after the final classroom. This is a deliberate, localized gameplay addition to the architecture map: its entrance opens to the corridor, stair C does not open directly into it, and a continuous corridor route from the stair-C landing reaches its door. The adjustment must not cut off the main corridor. Keep level-1 shared WC and level-2 staff WC in their mapped positions; do not add a student WC or teachers' room to level 2.

Other latest constraints: all three stair cores remain aligned through roof; stairs connect only to landings/corridors, never directly into a room; the courtyard, gate, stage, fountain, flagpole, trees, and benches exist only at ground level; upper stories retain the open atrium and look down to that single courtyard; rooftop contains only its floor, safety rail, and stair exits.

### Story placement override: chess club

The source plan labels a chess club on level 2, but the canonical Night 1 story places Scene 12 in the chess club on level 3. For the playable school, the story is authoritative: keep a generic **PHÒNG CLB** in the level-2 north-block room and use the east-end north-block room on level 3 for **CLB CỜ VUA**. This does not move the men's WC from the east-wing end of level 3 or alter the circulation footprint.

## Reference-file note

This document preserves the architectural reading of the four images. Their original image files have not been added to the repository because this turn exposed them as conversation attachments rather than local project paths. For precise tracing or side-by-side review, keep the original attachments available or add approved copies under `art_references/` in a later asset-handling step.

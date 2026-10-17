# Art Bible — Night 1 visual migration

**Direction:** Vietnamese-school, first-person, PS2-inspired low-poly horror. The supplied five images in `art_references/` are **concept targets**, not runtime assets. Preserve the story and existing puzzle/state implementation while migrating presentation from the current Node2D scenes to real 3D geometry.

## Character lock

- Hoàng: Vietnamese male student, approximately 16–17, tall/slender; black falling fringe, reserved face, white short-sleeved school shirt, dark navy trousers, worn white sneakers, black backpack. No red shirt or cap. Reuse one rigged GLB across scenes.
- An: female-student silhouette; pallid/desaturated, long dark hair, distinct from Hoàng. Her mirror appearance is limited to the reflection viewport and is absent from the physical restroom room.
- NPCs: consistent low-poly human proportions and shared skeleton/action vocabulary. Each named character needs recognizable silhouette and clothing beyond a material recolor before final approval.
- Reference likeness is **not locked to a real photograph**: only the supplied stylized Hoàng concept is accessible in this project.

## Production targets (guidelines, not proven budgets)

| Element | Geometry target | Texture target |
|---|---:|---:|
| Main character | 2k–6k triangles; silhouette over facial detail | 512–1024 px atlas |
| NPC | 1.5k–5k triangles | 512 px atlas |
| Large modular building piece | 12–250 triangles before trims | 256–512 px tileable |
| Close hero prop / chess set | 100–1k triangles | 256–512 px |
| Small repeated prop | 12–150 triangles, instance where possible | shared 256 px |

The current original procedural GLBs/materials are an **early visual slice**; do not infer they meet these targets or the reference image quality without polygon/performance measurement.

## Materials and color

- Materials: aged plaster and damp lower wall, old ceramic tile, painted metal, worn wood, clouded glass, school-uniform fabric, paper and CRT plastic. Reuse the seven original 256 px school textures in `assets/materials/school/` where appropriate; add controlled variation at high-visibility locations.
- Night base: blue-gray ambient and weak fluorescent pools. Ordinary danger: localized muted red. Supernatural story beats may flood the first-person world with an oppressive, eerie red wash (not a flat opaque screen); keep geometry, “CỨU TÔI” and the navigable path readable. Ghost: pale/desaturated. Memory: gradual warm amber.
- Avoid wet/high-gloss surfaces everywhere, excessive bloom, opaque fog and chromatic aberration. The supplied reference images are mood/composition targets, not promises of photorealism.

## Scale, camera and framing

- Model in meters: approximate 1.7–1.8 m student, 2.8–3.5 m interior ceiling, 1.0–1.3 m classroom door width, clear 1.2 m or wider intended route.
- First-person camera at Hoàng's eye height, normally 70–80° field of view, near plane around 0.08 m. Hide the player body in ordinary view; render a separate body in reflections when the story requires it. Avoid camera clipping and preserve readable clues, sightlines and HUD at 960×540.
- Hallway: long vanishing point, classrooms/noticeboard on right, dark courtyard openings on left, red depth cue. Restroom: mirror is the focus, with cubicles and a separate 3D reflected scene. Lab: CRT rows and green pools with navigable center aisle. Chess club: An and the board as focal point; warm light increases with returned keepsakes.

## School Environment Style Lock — supplied references A–C

These three approved images are the visual targets for the night courtyard (A), corridor (B), and classroom (C). Match their Vietnamese public-school architecture, camera staging, and restrained PS2-era low-poly rendering; do not interpret them as generic dark-horror mood boards.

- **Palette:** cold blue/teal night shadows; dirty ivory upper plaster; desaturated blue-gray lower wall band; old reddish-brown tile/terrazzo; dark wood and near-black window glass. Keep small warm amber pools at the gate and isolated red supernatural accents.
- **Geometry:** simple square columns, long narrow corridor with repeated classroom bays, two-storey school frontage, broad uncluttered courtyard, divided dark window panes, flat concrete ceilings, and modest Vietnamese classroom furniture. Favor clean blocky silhouettes over noisy detail.
- **Surface treatment:** low-resolution, soft, slightly mottled plaster and worn wood; dampness is localized. Floor reflections are subtle and broken, never mirror-polished. Reuse the school texture set and keep material response matte/rough.
- **Lighting:** moonlit exterior with restrained gate lanterns; cool fluorescent pools at regular intervals in the corridor; dim cool ceiling fixtures in class. Preserve strong alternating light falloff and readable routes, signage, and interaction targets. Avoid flat ambient fill, heavy bloom, and all-over red.
- **Signage and props:** legible Vietnamese labels on aged enamel/paper boards; classroom numbers and stair/restroom wayfinding use a consistent dark backing and pale lettering. Use period-appropriate desks, fans, noticeboards, flag/banner, benches, and fire equipment sparingly.
- **Reuse:** the same plaster bands, wood, dark metal, glass, tile, sign scale, and fluorescent fixture language must carry between courtyard, corridor, classroom, stairs, and adjacent rooms. Keep collision, navigation, triggers, and interaction volumes independent of decorative meshes.
- **Runtime gates:** review Godot runtime captures at 960×540 against A–C. A concept render, editor viewport, or node-presence assertion is not visual signoff; record any scene not captured or not yet matching.

## Latest PS2 Corridor Reference — rendering priority update

The latest user-supplied in-game screenshot is the leading rendering target for the school redesign. It refines the earlier night-school references toward a darker, more visibly PS2-era corridor treatment. The floorplans and canonical story remain the authorities for layout and room placement; this screenshot does not authorize changing the campus footprint or gameplay routes.

- **Surface palette:** stained, muted cream-gray upper plaster; worn blue-green dado; near-black divided glazing and old dark wood doors; scuffed brown floor; rough, low-resolution textures with nearest filtering where they read cleanly.
- **Corridor shape:** preserve the plan's open courtyard-facing galleries and overall footprint. Use repeated square concrete crossbeams/portals over the covered gallery runs to evoke the screenshot's compressed corridor rhythm without enclosing the courtyard side or blocking sightlines.
- **Lighting:** deep blue-green ambient shadow, weak cool fluorescent pools, and decisive falloff between fixtures. Keep route edges and Vietnamese signs legible; avoid bright uniform fill, glossy wet floors, heavy bloom, and all-over red.
- **Wayfinding / danger accents:** dark enamel-style signboards with pale Vietnamese lettering; a subdued red PCCC/fire cabinet may carry a small red indicator glow. Keep red localized to practical safety equipment or story beats.
- **Room-story lock:** preserve the canonical story placement of the chess club on level 3 and the men's WC at the end of the east wing on level 3, even where supplied plan labels suggest a different room use.

## Naming and verification

- Reusable gameplay visual scenes: `scenes/visual/<place>_3d.tscn`; scripts: `scripts/visual/<place>_3d.gd`; GLB names use lowercase snake_case; material resource names use `M_` prefix.
- Only real mesh/material/transform assets count as 3D. A Blender render is a **preview**, a Godot SubViewport image is a **runtime capture**, and automated harnesses establish only the assertions they execute.
- Final visual signoff requires side-by-side review against the supplied concepts, camera/collision tests with actual input, performance capture on a target machine, and consistent quality throughout all 15 scenes.

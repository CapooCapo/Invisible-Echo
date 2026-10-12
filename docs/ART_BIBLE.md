# Art Bible — Night 1 visual migration

**Direction:** Vietnamese-school, third-person, PS2-inspired low-poly horror. The supplied five images in `art_references/` are **concept targets**, not runtime assets. Preserve the story and existing puzzle/state implementation while migrating presentation from the current Node2D scenes to real 3D geometry.

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
- Night base: blue-gray ambient and weak fluorescent pools. Danger: localized muted red, not a full red screen. Ghost: pale/desaturated. Memory: gradual warm amber. Keep readable paths and interactive objects visible.
- Avoid wet/high-gloss surfaces everywhere, excessive bloom, opaque fog and chromatic aberration. The supplied reference images are mood/composition targets, not promises of photorealism.

## Scale, camera and framing

- Model in meters: approximate 1.7–1.8 m student, 2.8–3.5 m interior ceiling, 1.0–1.3 m classroom door width, clear 1.2 m or wider intended route.
- Third-person camera over Hoàng's shoulder, 60–70° field of view, near plane around 0.08 m. No walls/props cutting through camera. Preserve sightline to the objective and readable HUD at 960×540.
- Hallway: long vanishing point, classrooms/noticeboard on right, dark courtyard openings on left, red depth cue. Restroom: mirror is the focus, with cubicles and a separate 3D reflected scene. Lab: CRT rows and green pools with navigable center aisle. Chess club: An and the board as focal point; warm light increases with returned keepsakes.

## Naming and verification

- Reusable gameplay visual scenes: `scenes/visual/<place>_3d.tscn`; scripts: `scripts/visual/<place>_3d.gd`; GLB names use lowercase snake_case; material resource names use `M_` prefix.
- Only real mesh/material/transform assets count as 3D. A Blender render is a **preview**, a Godot SubViewport image is a **runtime capture**, and automated harnesses establish only the assertions they execute.
- Final visual signoff requires side-by-side review against the supplied concepts, camera/collision tests with actual input, performance capture on a target machine, and consistent quality throughout all 15 scenes.

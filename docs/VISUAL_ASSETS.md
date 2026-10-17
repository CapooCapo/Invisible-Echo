# Visual asset inventory

| Asset | Role | Provenance | Current gate |
|---|---|---|---|
| `assets/characters/hoang/hoang.glb` | Rigged Hoàng, 12 animation clips | Original Blender generation in `tools/generate_hoang.py`; zipped source alongside | Imported and shown in Godot runtime in hallway/restroom/lab/chess; animation **transitions and foot placement not verified** |
| `assets/characters/an/an.glb` | Rigged An, 6 clips | Original Blender generation in `tools/generate_an.py`; zipped source alongside | Imported and visible in mirror/chess room; animation and likeness need review |
| `assets/characters/npcs/*.glb` | Bảo, Huân, Lân, Minh, three bullies | Original variants built from project-owned Hoàng base by `tools/generate_npcs.py` | Seven GLBs exported/structurally checked; three bullies visible in restroom runtime, other four **not integrated** |
| `assets/materials/school/*.png` | Five 256 px school surface textures | Original procedural textures in `tools/generate_school_textures.py` | Used by 3D rooms; tiling and PBR balance need visual polish |
| `assets/props/school/restroom_toilet_cistern.glb` | Toilet, cistern, seat and flush details used in both WC Nam cubicles | Project-authored Blender model; reproducible source in `restroom_toilet_cistern_source.blend` and `tools/create_restroom_fixture_models.py` | Imported and used; room-scale visual quality and collision clearance not yet visually verified |
| `assets/props/school/restroom_wall_basin_faucet.glb` | Basin and faucet used at the twin WC vanity | Project-authored Blender model; reproducible source in `restroom_wall_basin_faucet_source.blend` and `tools/create_restroom_fixture_models.py` | Imported and used; fit/detail review remains open |
| `assets/props/school/restroom_wall_urinal.glb` | Wall urinals in WC Nam | Project-authored Blender model; reproducible source in `restroom_wall_urinal_source.blend` and `tools/create_restroom_fixture_models.py` | Imported and used; fit/detail review remains open |
| `assets/props/school/psx_school_kit_free/` | `ceiling_light.glb`, classroom `class_paint.png` and `class_dado.png`, plus the referenced `atlas.png` | Selected assets from PSX School Kit Free by heyheythere, v1.0.3, CC BY 4.0; see adjacent `LICENSE.txt` and `SOURCE.txt` | Wall and base-band textures are used by the school environment; the ceiling fixture replaces the simple diffuser mesh while existing room lighting remains. Textures retain native dimensions, are imported losslessly without mipmaps, and are point-filtered. No collision/navigation changes; game-scene appearance is not verified in this pass |
| `scenes/visual/hallway_3d.tscn` | School corridor and letter beat | Original Godot geometry | Godot runtime capture; controller integration for opening beats |
| `scenes/visual/restroom_3d.tscn` | Stalls, sinks, real 3D mirror apparition | Original Godot geometry | Godot runtime captures; controller integration for restroom/mirror beats |
| `scenes/visual/computer_lab_3d.tscn` | CRT classroom and task computer | Original Godot geometry | Godot runtime capture; controller integration status in `VISUAL_PROGRESS.md` |
| `scenes/visual/chess_club_3d.tscn` | Board, trophies, An, warm-memory lighting | Original Godot geometry | Godot runtime capture; controller integration status in `VISUAL_PROGRESS.md` |

Reference concepts live in `docs/art_references/` and Blender previews in `docs/qa/blender_previews/`. Neither is a gameplay environment nor evidence of a Godot render. See `ASSET_LICENSES.md` for provenance and `VISUAL_QA.md` for actual checks.

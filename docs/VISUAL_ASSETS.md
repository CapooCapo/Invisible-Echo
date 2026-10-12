# Visual asset inventory

| Asset | Role | Provenance | Current gate |
|---|---|---|---|
| `assets/characters/hoang/hoang.glb` | Rigged Hoàng, 12 animation clips | Original Blender generation in `tools/generate_hoang.py`; zipped source alongside | Imported and shown in Godot runtime in hallway/restroom/lab/chess; animation **transitions and foot placement not verified** |
| `assets/characters/an/an.glb` | Rigged An, 6 clips | Original Blender generation in `tools/generate_an.py`; zipped source alongside | Imported and visible in mirror/chess room; animation and likeness need review |
| `assets/characters/npcs/*.glb` | Bảo, Huân, Lân, Minh, three bullies | Original variants built from project-owned Hoàng base by `tools/generate_npcs.py` | Seven GLBs exported/structurally checked; three bullies visible in restroom runtime, other four **not integrated** |
| `assets/materials/school/*.png` | Five 256 px school surface textures | Original procedural textures in `tools/generate_school_textures.py` | Used by 3D rooms; tiling and PBR balance need visual polish |
| `scenes/visual/hallway_3d.tscn` | School corridor and letter beat | Original Godot geometry | Godot runtime capture; controller integration for opening beats |
| `scenes/visual/restroom_3d.tscn` | Stalls, sinks, real 3D mirror apparition | Original Godot geometry | Godot runtime captures; controller integration for restroom/mirror beats |
| `scenes/visual/computer_lab_3d.tscn` | CRT classroom and task computer | Original Godot geometry | Godot runtime capture; controller integration status in `VISUAL_PROGRESS.md` |
| `scenes/visual/chess_club_3d.tscn` | Board, trophies, An, warm-memory lighting | Original Godot geometry | Godot runtime capture; controller integration status in `VISUAL_PROGRESS.md` |

Reference concepts live in `docs/art_references/` and Blender previews in `docs/qa/blender_previews/`. Neither is a gameplay environment nor evidence of a Godot render. See `ASSET_LICENSES.md` for provenance and `VISUAL_QA.md` for actual checks.

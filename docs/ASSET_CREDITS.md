# Asset provenance

## Original assets

- `assets/audio/ambience/school_night.wav`, `computer_room.wav`: synthesized for this project using deterministic Python standard-library waveform generation.
- `assets/audio/sfx/*.wav`: synthesized for this project using deterministic Python standard-library waveform generation.
- Earlier environments, props, UI and character silhouettes: drawn in GDScript at runtime. The in-progress 3D visual pass adds original Blender GLBs, procedural 256 px textures and Godot 3D geometry; see `ASSET_LICENSES.md` and `VISUAL_ASSETS.md`.

## Third-party assets

- `assets/props/school/psx_school_kit_free/`: selected `ceiling_light.glb`, `class_paint.png`, `class_dado.png`, and the referenced `atlas.png` from **PSX School Kit Free**, by **heyheythere**, version **1.0.3**. Source: https://heyheythere.itch.io/psx-school-kit-free. Licensed under **CC BY 4.0**; see the included `LICENSE.txt` and `SOURCE.txt`.
- Required game credit: **PSX School Kit Free by heyheythere - https://heyheythere.itch.io/psx-school-kit-free - CC BY 4.0**

- Two Poly Haven CC0 HDRIs are retained under `assets/sky/` as provenance-verified candidates. Neither is used by the current production sky: Kloppenheim retains a bright disk at the tested low energy, and Qwantani Night Pure Sky produced a bright cyan horizon in the same-view comparison. No required credit; provenance and hashes are in `assets/sky/SOURCE.md`.
- The active night sky uses a project-generated star cover (`tools/generate_night_sky_stars.py`) and Godot's procedural gradient; no external star texture is included.
- Recheck provenance and add per-file license notes before integrating any future external asset.

## Release QA inventory (2026-10-11)

- Audio files present: two ambience tracks and six SFX WAVs; all eight load under `tests/test_audio_assets.gd`.
- Existing cues include school-night/computer-room ambience, letter, mirror sting, puzzle solved, keepsake, death, and chase heartbeat.
- No third-party asset was downloaded or added during release QA. The required listen/mix review is still pending; several requested dedicated cues are absent (see `docs/RELEASE_QA.md`).
- Godot engine licensing notices remain in `docs/licenses/`; this asset inventory does not replace those engine notices.

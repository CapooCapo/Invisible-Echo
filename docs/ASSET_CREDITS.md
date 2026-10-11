# Asset provenance

## Original assets

- `assets/audio/ambience/school_night.wav`, `computer_room.wav`: synthesized for this project using deterministic Python standard-library waveform generation.
- `assets/audio/sfx/*.wav`: synthesized for this project using deterministic Python standard-library waveform generation.
- Environments, props, UI and character silhouettes: drawn in GDScript at runtime.

No third-party assets, fonts, sample packs, external chess engine, or licensed services are included. Therefore there are no third-party attribution requirements for the current project contents. Recheck provenance and add per-file license notes before integrating any future external asset.

## Release QA inventory (2026-10-11)

- Audio files present: two ambience tracks and six SFX WAVs; all eight load under `tests/test_audio_assets.gd`.
- Existing cues include school-night/computer-room ambience, letter, mirror sting, puzzle solved, keepsake, death, and chase heartbeat.
- No third-party asset was downloaded or added during release QA. The required listen/mix review is still pending; several requested dedicated cues are absent (see `docs/RELEASE_QA.md`).
- Godot engine licensing notices remain in `docs/licenses/`; this asset inventory does not replace those engine notices.

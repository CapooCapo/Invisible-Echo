# Task Board

| Status | Task | Evidence / acceptance |
|---|---|---|
| DONE (logic) | Godot bootstrap + opening scenes 01–04 | First-slice harness 16/16; main-scene headless smoke passes. |
| PARTIAL | GUI review | Real GUI captures confirm the opening letter and diary puzzle render Vietnamese text legibly. Full keyboard route and other scenes not verified. |
| DONE (logic) | Shared GameState / checkpoint routing | JSON serialization and disk round-trip harness 10/10; saved scene 09 route harness passes. |
| DONE (logic) | Scenes 05–08 | Board clue, diary, circuit BFS, patrol/LOS/hiding/distraction, chase, rewards; harness 27/27. |
| DONE (logic) | Scenes 09–11 | 1804, clip ordering, immutable A/B choice, evidence links, rewards; harness 16/16. |
| DONE (logic) | Scenes 12–15 | Return all six items, legal one-move checkmate, resign/retry, two ending branches, Night 2 unlock; chess 18/18 and resolution 10/10. |
| DONE (resource) | Original audio content | 2 synthesized ambience WAVs and 6 SFX are wired to interactions; resource harness 8/8. Listening/mix quality not checked. |
| DONE | Independent focused code review | Reviewer APPROVED Linux package path, chess resign/retry checkpoint, duplicate SFX removal, and extended chess rules coverage. |
| DONE (headless) | Logic regression suite | 105 assertions across seven suites; editor import and main-scene smoke also pass. |
| DONE (export) | Desktop builds | Standard Linux and Windows presets exported with checksum-verified Godot 4.7.2 templates; Linux build launched headlessly. Windows PE format confirmed, but execution is not verified on this Linux host. |
| TODO | Full GUI playthrough and sound check | Verify 01–15, timer/retry, all minigames, branch choices, glyphs, audio, and final screen using live input. |
| DONE | Local source checkpoint | Source and automated verification committed locally as `38ae1bd`; no push. |

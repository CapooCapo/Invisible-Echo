# Task Board

| Status | Task | Evidence / acceptance |
|---|---|---|
| DONE (logic) | Godot bootstrap + opening scenes 01–04 | First-slice harness 16/16; main-scene headless smoke passes. |
| PARTIAL | GUI review | Compatibility-renderer screenshots confirm scene 01 letter and scene 06 diary text are legible; actual input confirmed only the opening letter interaction. Full routes and other scenes not verified. See `docs/RELEASE_QA.md`. |
| DONE (logic) | Shared GameState / checkpoint routing | JSON serialization and disk round-trip harness 10/10; saved scene 09 route harness passes. |
| DONE (logic) | Scenes 05–08 | Board clue, diary, circuit BFS, patrol/LOS/hiding/distraction, chase, rewards; harness 27/27. |
| DONE (logic) | Scenes 09–11 | 1804, clip ordering, immutable A/B choice, evidence links, rewards; harness 16/16. |
| DONE (logic) | Scenes 12–15 | Return all six items, legal one-move checkmate, resign/retry, two ending branches, Night 2 unlock; chess 18/18 and resolution 10/10. |
| PARTIAL (resource) | Original audio content | 2 synthesized ambience WAVs and 6 SFX load (8/8 resource checks), but listening/mix is not checked and dedicated cues for several requested events are missing. See `docs/RELEASE_QA.md`. |
| DONE | Independent focused code review | Reviewer APPROVED Linux package path, chess resign/retry checkpoint, duplicate SFX removal, and extended chess rules coverage. |
| DONE (headless) | Logic regression suite | 105 assertions across seven suites; editor import and main-scene smoke also pass. |
| DONE (export) | Desktop builds | Standard Linux and Windows presets exported with checksum-verified Godot 4.7.2 templates; Linux build launched headlessly. Windows PE format confirmed, but execution is not verified on this Linux host. |
| HUMAN PLAYTEST REQUIRED | Full GUI playthrough and sound check | Verify 01–15, timer/retry, all minigames, branch choices, glyphs, audio, checkpoint load and final screens using live input; verify Windows runtime on Windows. Use `docs/PLAYTEST_HANDOFF.md`. |
| TODO | Menu/settings and polish gaps | No title/New Game/Continue/Settings UI; several named SFX and a turn-around animation still need a product decision/implementation. |
| DONE | Local source checkpoint | Source and automated verification committed locally as `38ae1bd`; no push. |

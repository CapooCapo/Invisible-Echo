# Release QA — Đêm 1

**Verdict: HUMAN_PLAYTEST_REQUIRED — not release-ready yet.** This report distinguishes implementation, automated checks, visual evidence, and real-player input. Passing logic tests do not close GUI, audio, Windows runtime, or full-route gates.

## Baseline and save safety

- Project: `/home/giahoang/dev/an-tieng-gay-trong-dem`
- QA baseline: `main` at `b0d5cd9`; source tree was clean before this report and handoff were added.
- Engine: Godot `4.7.2.stable.arch_linux.ed1daf0bf`, Linux x86_64.
- Main user save: `~/.local/share/godot/app_userdata/An Tiếng Gáy Trong Đêm/an_tieng_gay_trong_dem_save.json`, at `scene_05 / notice_board` before QA. A byte-for-byte backup was made at `an_tieng_gay_trong_dem_save.json.pre-release-qa-20261011`. Both SHA-256 values remained `dd67287561abbffe79d253b3dcca95aed255f8e62a9a8d195df55f3e1b2db50e` after QA; the main save is unchanged.
- Harnesses and GUI runs used dedicated `XDG_DATA_HOME` / `XDG_CONFIG_HOME` paths. They did not use the main save. QA profiles and screenshots were retained; no cleanup was performed.

## Verification results

| Gate | Result | Evidence |
|---|---|---|
| Automated logic | **PASS** | Re-ran all seven Godot harnesses in isolated XDG paths: first slice 16, school chapter 27, digital mystery 16, GameState 10, chess rules 18, resolution 10, audio resources 8 = **105/105 assertions**. All exited 0. |
| Editor import | **PASS** | `godot --headless --editor --path <project> --quit` completed without errors. |
| Main-scene smoke | **PASS** | `godot --headless --path <project> --quit-after 3` completed without errors. |
| Current title-menu main scene | **PASS (headless startup only)** | Godot 4.7.2 editor import and `--headless --path <project> --quit-after 120` both exit 0 with `res://scenes/title_menu.tscn` configured. Interactive title/menu save flow remains **NOT VERIFIED**. |
| Linux executable + PCK | **PASS (isolated headless startup; GUI still partial)** | Corrected `tools/build_linux.sh` to use the official 4.7.2 Linux release template with adjacent `builds/an-tieng-gay-trong-dem-linux.pck`. Launched the rebuilt executable from the project root with only isolated XDG paths and no `--path`/`--main-pack` override. The resulting QA save recorded `scene_01 / hallway_letter`. Earlier, the broken runtime+raw-PCK-concat artifact opened Project Manager; it was replaced. This validates that the replacement loads the game in headless mode, not full GUI rendering or human playability. |
| Linux template artifact | **PASS (format only in this QA)** | `builds/an-tieng-gay-trong-dem-template.x86_64` is ELF x86-64. Previous project evidence records a headless launch; this QA did not separately rerun that artifact. |
| Windows build | **NOT VERIFIED at runtime** | `builds/an-tieng-gay-trong-dem.exe` is PE32+ x86-64. No Windows runtime was available. |
| Actual GUI | **PARTIAL** | Godot rendered on the existing Hyprland/Xwayland desktop with OpenGL Compatibility (Mesa Intel). A real keyboard movement plus `E` interaction opened the letter; the isolated save recorded `letter_read`. See [scene 01 hallway](qa/screenshots/scene01-hallway.png) and [letter interaction](qa/screenshots/scene01-letter.png). |
| Visual inspection | **PARTIAL** | Letter and diary UI show readable Vietnamese glyphs at 1896×1018. [Scene 06 diary UI](qa/screenshots/scene06-diary-ui.png) is a visual capture only; its route was not validated. A 960×540 graphical harness also captured and inspected the Scene 13 mode selector, full Normal board/HUD, resignation prompt, and Bad Ending. Camera, animation, lighting, collision, navigation, and remaining-scene readability are **not verified**. |
| Full manual routes | **NOT VERIFIED** | No reliable input-driven run from New Game through both endings, all puzzles/chess, death/retry, and checkpoint reloads was completed. Some diagnostic captures from a later GUI sequence were black or showed a different scene than expected; they are excluded from evidence. One isolated QA profile reached `scene_06 / locker_a17` with uncertain input provenance; it was retained and not reused. |
| Audio playback / mix | **NOT VERIFIED** | Resource tests load all eight WAV files; static callsites exist for ambience, letter, mirror, puzzle, keepsake, death, and chase heartbeat. No reliable listen/mix evaluation was completed. |
| Assets and licensing | **PASS (inventory only)** | `docs/ASSET_CREDITS.md` identifies code-drawn visuals and standard-library synthesized audio, with no third-party art, fonts, samples, chess engine, or paid service. No external assets were added during QA. |
| Git hygiene | **PASS at baseline** | Baseline was clean on `main`; generated builds and QA runs are under ignored `builds/`. `git diff --check` is part of the final doc check. |

## Release gaps / known issues

0. **Linux delivery uses a two-file package.** Keep the release executable and its adjacent PCK together. The prior malformed single-file build opened Project Manager and was replaced; the corrected pair loads scene 01 in an isolated headless startup. Its GUI playability still needs human confirmation.
1. **Title menu implemented; startup verified, interaction not verified.** `project.godot` launches the title screen with Continue (enabled only after a supported save loads), New Game (confirmation before replacing an existing save), and Quit. Godot 4.7.2 import and configured main-scene headless launch pass; interactive save/route behavior remains unverified. Settings UI remains absent.
2. **Audio remains partial.** The resignation Bad Ending now calls the existing iron-stick scrape WAV, and a graphical probe confirmed that its stream loads and plays. No human listening test was performed; call-site coverage for other requested beats (other stick-scrape moments, footsteps, school bell, flickering light, door slam, chess-boss cue, and ending transitions) remains **NOT VERIFIED**. Do not mark audio complete based on resource loading alone.
3. **Mirror turn-around is text-only.** The apparition is drawn in the mirror during the reflection beat; no separate turn animation was verified in the inspected code.
4. **Persistence is checkpoint-level, not a complete live-state snapshot.** `docs/PROGRESS.md` notes that some intermediate evidence-board state and live chess position do not persist; chess reload restarts at its challenge checkpoint.
5. **Scene 13 chess modes implemented and targeted-tested.** Story retains its one-move mate puzzle; Normal starts a full legal match with easy AI; Challenge uses bounded search. Retry, draw/loss, resignation Bad Ending, and win-to-morning were checked. Post-layout results: chess rules 20/20 (including halfmove-clock preservation), resolution 16/16, mode runtime 32/32, and graphical captures at 960×540. Full manual route/playtest remains open.
6. **Windows runtime and audio listening remain unverified.** Neither fact can be inferred from export/file format or WAV resource loading.
7. **App-data name still uses the older spelling.** The player-facing title now follows the canonical “AN — Tiếng Gậy Trong Đêm”; `application/config/name` remains “An Tiếng Gáy Trong Đêm” to preserve the existing Godot app-data directory. Do not rename it casually without save migration or a preserved data-directory name.

## Evidence classifications

- **IMPLEMENTED:** project flow/docs describe 15 scenes, six keepsakes, puzzles, stealth/chase, three chess modes, two endings, and Night 2 unlock flag.
- **AUTOMATED_TESTED:** 105 assertions plus editor import, main-scene smoke, and Linux self-contained headless smoke in this QA.
- **VISUALLY_VERIFIED:** scene 01 hallway/letter and a scene 06 diary UI snapshot only.
- **MANUALLY_PLAYTESTED:** only the opening letter approach/interact was confirmed with actual keyboard input in an isolated profile. Full gameplay routes are **not verified**.
- **RELEASE_READY:** **NO**. Human playtest, title-menu/save flow runtime checks, audio evaluation, Windows runtime, settings, and listed release gaps remain open.

## Next required action

Use [PLAYTEST_HANDOFF.md](PLAYTEST_HANDOFF.md) with a human player. First exercise Continue and confirmed New Game using an isolated profile; then complete the 15-scene checklist, both choice branches/endings, death/retry, save/load, chess modes, audio notes, and Windows runtime on a Windows host. Keep `RELEASE_READY` unset until those gates and product gaps are resolved.

---
name: godot-genre-horror
description: Horror game design and implementation guidance for tension pacing, atmosphere, sensory threats, fairness, and player feedback. Use when designing or coding horror beats and encounters.
---

# Horror design for this game

Use `UPSTREAM_SOURCE.md.txt` and its references for horror-design ideas and implementation patterns. This game is horror, but the source's universal-sounding rules are heuristics, not requirements.

- Preserve the established narrative, player capabilities, encounter rules, checkpoints, and gameplay documents. Do not add scarcity, sanity meters, safe rooms, a stalking Director, or combat merely because the upstream blueprint describes them.
- Favor readable navigation, anticipation, sound/lighting cues, and player agency when they fit the approved scene. A dark floor that prevents basic navigation is not useful atmosphere.
- Treat all bundled scripts as unintegrated examples. Some assume 2D or particular AI/inventory systems; adapt only after checking current project architecture, dependencies, and gameplay fit. Never copy the whole “dual brain” stack by default.
- The upstream skill chain names related skills that are not installed. Do not assume those skills or their scripts exist; use the installed Godot skill, project docs, and official Godot documentation instead.
- Balance tension and relief against the intended story beat; don't force a formula onto every scene.

Project art and story references take precedence over generic horror formulas. Provenance and license: [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

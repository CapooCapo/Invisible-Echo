---
name: godot
description: "Godot 4.x engineering for this game: inspect and edit GDScript, scenes, resources, shaders, audio, assets, imports, gameplay, and validation. Use for implementation or debugging in this Godot project."
---

# Godot project workflow

Use this skill for technical Godot work in this repository. Upstream source and bundled examples are preserved in `UPSTREAM_SOURCE.md.txt`, `scripts/`, `templates/`, and `references/`; open only what the task needs.

## Project authority and compatibility

- Target engine: Godot 4.7.2. Confirm `godot --version` if API compatibility matters.
- For story, mechanics, visuals, and architecture, respect the current project files and the user's latest approved references. In particular, keep `docs/ART_BIBLE.md` and `docs/SCHOOL_ARCHITECTURE_MAP.md` authoritative for the school's look and layout; don't let generic starter templates replace existing project conventions.
- Preserve current gameplay systems, save/checkpoint behavior, and scene integration unless the task explicitly changes them. Do not scaffold over this project.
- Host-native Godot automation may not be available. If so, prefer the installed Godot CLI and direct project inspection. Do not claim visual verification from headless output alone.

## Safe use of upstream helpers

- Treat bundled scripts and templates as source examples, not automatically trusted project code. Before running a helper, read its implementation and exact arguments, confirm the task authorizes its write scope, and protect existing user work. Never run a broad rewrite/import/move/export operation just because this skill recommends it.
- Some helpers create, overwrite, move, or remove project resources/configuration. Preview or inspect first; do not run destructive or wide-scope helpers without explicit task authorization.
- Optional image cleanup helpers may need Pillow and NumPy. Do not install packages or access paid/external services automatically; use them only when required and already available.
- Keep bundled tools and examples under `.agents/skills/`; never attach them to gameplay scenes or copy their `class_name` scripts into the game without reviewing compatibility.
- Follow repository and user constraints over upstream absolute wording. Record actual commands and results; mark unrun checks `not verified`.

For provenance and license, see [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

---
name: godot-gdscript-mastery
description: GDScript code review and implementation in Godot 4, especially typing, signals, node lifecycle, Callable binding, await, and safe collections. Use when writing or refactoring game scripts.
---

# GDScript practices for this project

Consult the relevant sections and examples in `UPSTREAM_SOURCE.md.txt`, `references/`, and `scripts/` when a task touches these language patterns.

- Use upstream examples as focused references, not mandatory architecture. Match the project's existing ownership, naming, typing, and signal conventions; avoid sweeping style migrations unrelated to the task.
- Preserve existing public APIs and scene hookups. In particular, do not apply “Signal Up, Call Down” mechanically where established gameplay integration would be broken; describe the tradeoff and make scoped changes.
- Bundled `class_name` scripts are examples, not project modules. Do not copy or attach them without checking naming collisions, dependencies, engine version, and the actual game behavior.
- `@tool` EditorScripts are utilities, not runtime code. Read their full source and inspect their target paths before running; never point a project-wide analyzer at files outside the authorized scope.
- Verify the changed script with the narrowest appropriate Godot parse/runtime check when requested or required by the task, and report unrun checks honestly.

Project-level rules and the Godot 4.7.2 target take precedence over upstream `NEVER`/`MANDATORY` language. For source and license details, see [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

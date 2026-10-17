---
name: godot-genre-puzzle
description: Puzzle game design and implementation guidance for readable rules, experimentation, feedback, solvability, and soft-lock prevention. Use when designing or coding an environmental or logic puzzle.
---

# Puzzle design for this game

Use `UPSTREAM_SOURCE.md.txt`, its references, and examples to inform puzzle design and code reviews.

- Apply the player-facing principles—clear affordances, useful feedback, fair experimentation, understandable rules, and avoiding accidental soft-locks—when they fit the puzzle and narrative.
- This project includes environmental/story puzzles, not necessarily grid puzzles. Do not introduce `Vector2i` grids, `UndoRedo`, match-three logic, or a separate grid architecture unless the specific puzzle needs them.
- Do not promise universal undo/reset: preserve intended consequence, checkpoint, and save behavior from the game design. Offer undo/backtracking where it supports the puzzle without undermining story or encounter stakes.
- Treat scripts as isolated examples with possible 2D assumptions; inspect dependencies and test the specific mechanic before integration. The upstream skill chain lists peer skills that are not installed; do not assume their availability.
- Keep puzzle state owned by the established game systems and preserve scene/gameplay integration.

Upstream `NEVER`/`MANDATORY` statements are guidance, not higher-priority project requirements. Provenance and license: [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

# Sprint 03 — School Exploration (Scenes 05–08)

This design resolves interaction details for implementation while preserving the supplied story and order. Each challenge is keyboard-first, restartable, and provides feedback for both valid and invalid actions.

## Scene 05 — Notice board

- The board is a dedicated inspectable hotspot; interaction opens a legible close-up panel, not a full-screen cutscene.
- Clicking/pressing E on the redacted portrait reveals `NGUYỄN NGỌC AN — GIẢI NHẤT CỜ VUA`; turning/inspecting the reverse reveals `18/04` and `A-17`.
- Persist `an_identity_known=true` and `locker_clue=A-17`; objective advances to the locker.

## Scene 06 — Diary reconstruction / Keepsake 1

- Find locker A-17 and press E; show six shuffled fragments in a six-slot board.
- Each fragment is an ordered half-entry; placing two compatible pieces into the same dated row completes one entry. Date order is 03/09 → 12/09 → 18/09.
- Entries reveal the 100-point test, false cheating allegation and ignored plea. Reset/rearrange is always allowed; wrong placements remain visible and can be corrected.
- Completion unlocks the test page. Collecting it exactly once adds `math_test` and plays a brief mother-memory vignette.

## Scene 07 — Circuit rotation / Keepsake 2

- Use a deterministic 4×4 grid with a source and stair-lock endpoints; rotate orthogonal wire pieces with E/click.
- Success is based on graph connectivity from source to target through joined ports, not on matching a decorative target snapshot. Disconnected/invalid paths never grant success.
- Provide a reset control and a non-spoiling hint after repeated idle attempts. On success, lights and stair door change state; the adjacent display opens.
- Collect the chess medal once as `chess_medal` and show its short podium memory.

## Scene 08 — Patrol, clue and chase / Keepsake 3

- Guard state machine: `PATROL → SUSPICIOUS → CHASE → SEARCH → PATROL`; player movement, hide zones and throwable distraction can interrupt detection.
- Vision cones are visible at readable distance and suspicion is communicated before chase. Detection uses line-of-sight/range rather than screen position alone.
- An gestures toward a movable box. Interact to reveal `knight_keychain`; collect once as `knight_keychain` and show the gift memory.
- A guarded reveal starts a short, telegraphed obstacle chase to the computer room; contact resets to the last local checkpoint rather than a dead-end loop. Entering the room advances to scene 09.

## Acceptance checks

1. Scene 05 reveals identity/date/locker clue and persists the objective gate.
2. Diary pieces can be placed/reordered; incorrect state is recoverable; correct sequence unlocks one and only one `math_test`.
3. Circuit endpoint connectivity rejects a disconnected path, accepts a connected path, can reset, and unlocks exactly one `chess_medal`.
4. Patrol detects only within its cone/visibility rules; hiding or distraction can break pursuit; search returns to patrol; no permanent chase lock.
5. Box interaction yields exactly one `knight_keychain`; memory and inventory state agree.
6. Chase can fail/retry and succeed into scene 09.
7. Every scene transition has a valid checkpoint, objective, and keyboard route; all three rewards appear in inventory in the canonical order.

## Risks to monitor

- Do not equate “three items found” with proof that their UI/interaction works; test the actual input path.
- Test source-to-target circuit topology, including rotations, instead of accepting any 16-cell state.
- Keep the chase challenging but fair and avoid instant detection at transition spawn.
- Temporary visuals are acceptable for this sprint only if clearly coherent; no external assets until individual licenses are verified.

# AN — Tiếng Gậy Trong Đêm: Chapter 01 Game Flow

## Design intent

Build the supplied story as an exploration-first 2D top-down cinematic horror adventure. Keep all 15 canonical scenes and six keepsakes in order. Dialogue and memories are short, playable spaces carry the pacing, and every non-ending branch rejoins the main route. This is the implementation flow, not a replacement script.

## Main flow

```mermaid
flowchart TD
  S01[01 · 17:10 School hall<br/>Explore → pick up letter] --> S02[02 · 07:15 Classroom<br/>Four matching letters → 23:00 invitation]
  S02 --> S03{03 · Toilet corridor<br/>Hide within 3 seconds}
  S03 -->|Miss / caught| D[YOU DIED → retry checkpoint]
  D --> S03
  S03 -->|Hide| S04[04 · Mirror<br/>An appears → investigate her]
  S04 --> S05[05 · Notice board<br/>An's photo → date 18/04 → locker A-17]
  S05 --> S06[06 · Locker A-17<br/>Reassemble 6 diary scraps]
  S06 --> K1((Keepsake 1<br/>Math test 100/100))
  K1 --> S07[07 · Electrical room<br/>Route power through 4×4 circuit]
  S07 --> K2((Keepsake 2<br/>Chess medal))
  K2 --> S08[08 · Patrol hall<br/>Stealth → knight keychain → chase]
  S08 --> K3((Keepsake 3<br/>Knight keychain))
  K3 --> S09[09 · Computer room<br/>Enter 1804 → restore camera clips]
  S09 --> K4((Keepsake 4<br/>Photo with mother))
  K4 --> S10[10 · Anonymous post<br/>Investigate evidence and Minh messages]
  S10 --> C{Decision recorded}
  C -->|A · Publish unedited| A[Unverified accusation spreads<br/>Night 2 consequence flag]
  C -->|B · Verify and warn| B[Limit rumor<br/>Threat still exists flag]
  A --> K5((Keepsake 5<br/>Minh's thanks))
  B --> K5
  K5 --> S11[11 · Evidence board<br/>Prove 3 linked conclusions]
  S11 --> K6((Keepsake 6<br/>Chess-club sketch))
  K6 --> S12[12 · Chess club<br/>Return all 6 keepsakes to An]
  S12 --> S13{13 · Chess challenge<br/>Story / Normal / Challenge}
  S13 -->|Loss or draw| R[An invites another try]
  R --> S13
  S13 -->|Resign| BAD[BAD ENDING<br/>The One Who Turned Away]
  S13 -->|Checkmate An| S14[14 · Three memory lights<br/>Truth → An asks Hoàng to help Minh]
  S14 --> S15[15 · 07:10 Classroom<br/>Choice-specific aftermath → message]
  S15 --> N2[Chapter 01 complete<br/>Night 2 unlocked · Coming Soon]
```

## Scene contracts

| Scene | Player-facing goal / interaction | Gate and persistent result |
|---|---|---|
| 01 — Lá thư bí ẩn | Walk to the envelope, press E, read it; hear the upstairs knock | Letter read; intro checkpoint |
| 02 — Cứu tôi | Read classroom plea and matching letters; accept 23:00 meeting | Night 1 begins |
| 03 — Ba giây | Reach and enter a toilet stall during a real 3-second timer | Retry checkpoint on failure; survive flag on success |
| 04 — Chiếc gương | Witness reflection and follow An's gesture to the board | “Find the mysterious girl” objective |
| 05 — Bảng tin | Inspect defaced photo and reverse | An identity, 18/04, A-17 clue |
| 06 — Nhật ký bị xé | Collect six paper pieces and place them in diary order | Memory 1, mother recollection |
| 07 — Phòng điện | Rotate 16 circuit tiles to connect supply to stair lock | Stair door and display unlocked; Memory 2 |
| 08 — Hành lang truy đuổi | Read patrol cones, crouch/hide, distract; take An's hint; escape chase | Memory 3 and computer-room destination |
| 09 — Máy tính duy nhất | Enter 1804; order corrupted camera clips; inspect accident report | Memory 4 and evidence retained |
| 10 — Bài đăng bí ẩn | Compare drafts, timestamps, account clues; inspect An–Minh conversation | Memory 5; persist publish-raw vs verify-and-warn choice |
| 11 — Bảng suy luận | Connect evidence into three required conclusions | Memory 6 and club-room objective |
| 12 — Phòng cờ vua | Place each collected keepsake into its matching slot | Six memories returned; chess unlocked |
| 13 — Ván cờ cuối cùng | Pick a mode and play legal chess | Loss/draw retry; resign bad ending; checkmate unlocks final memories |
| 14 — Ký ức cuối cùng | Visit three memory lights and receive black king | Truth acknowledged; black king inventory item |
| 15 — Người tiếp theo | Wake at school and see branch-specific Minh aftermath | Chapter 01 complete; Night 2 unlocked, no Night 2 story content |

## State model and checkpoints

- `chapter`: `night_1` until scene 15; then `night_1_complete` and `night_2_unlocked`.
- `scene_id` and `checkpoint_id`: resume scene-level progress without replaying completed sequences.
- `inventory.keepsakes`: six stable IDs (`math_test`, `chess_medal`, `knight_keychain`, `mother_photo`, `minh_thanks`, `chess_club_sketch`); never duplicate.
- `evidence`: diary, camera/report, historical post, Minh draft/message, board conclusions.
- `decision.minh_post`: `unresolved`, `publish_raw`, or `verify_warn`; choice is immutable after scene 10 confirmation.
- `ending`: `none`, `bad_turn_away`, or `good_remembered`; a loss/draw is not an ending.
- Checkpoint after each scene gate and before the 3-second event / chess mode. Save under Godot `user://`; missing or invalid data should load the latest safe checkpoint/default state rather than strand the player.

## Feedback, pacing, and fairness

- The three-second event must start on a clear audio/visual cue, allow movement immediately, identify the stall as a valid hiding spot, and keep retry one action away.
- Stealth uses readable enemy vision and suspicion states; hiding and distraction must break pursuit. Chase obstacles are telegraphed, with a retryable checkpoint.
- Evidence-board and diary puzzles confirm what has been placed and give non-spoiling hints after repeated idle time; they do not require pixel-precise mouse input.
- Preserve uncertainty around An's final accident: the camera establishes a chase and missing evidence, not an invented culprit or definitive account beyond the supplied story.
- Choice B limits the rumor; it does not magically remove the threat. Both branches still ask the player to help Minh.
- Chess uses actual legal moves and permits unlimited retry on loss/draw. Resign is a separate explicit action before ending.

## First vertical slice

The first implementation milestone covers scenes 01–04: letter interaction and reading, the next-morning story transition, the timed hiding event with retry, and the mirror/An objective. Later puzzles remain TODO until this slice imports, launches and is reviewed.

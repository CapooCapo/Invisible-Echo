# Room Mapping — approved plans vs active Godot builder

**Status:** evidence map; schematic plan dimensions are not treated as surveyed dimensions.  
**Coordinate basis:** project school origin `(0,0,0)`, +X east, -Z north, +Y up.  
**Active source:** `scripts/visual/school_environment_3d.gd` instantiated by `NightSchool3D`.

## Source and measurement rules

The four conversation-supplied images were reviewed: floor 1 (`image---ae7a14d0-b9d2-43fe-b58e-0eb99e7564fd.png`), floor 2 (`image---a768795d-7265-4215-835e-4d1b1a4bb9c2.png`), floor 3 (`image---4eb40c78-9dc4-4912-8f81-56f0e516c1b2.png`), and roof (`image---553ae2b6-6826-4414-854e-3b2977de3458.png`). These are schematic top-down plans with a scale bar, not dimensioned CAD drawings or elevation schedules. Current center coordinates/room footprints below come from the Godot builder; **they are actual implementation values, not presumed approved-plan dimensions**.

Code uses +X east, -Z north; the north bar is at Z≈-27 and galleries at Z≈-22, so the plan’s top/north direction maps to negative Z. `FLOOR_HEIGHT=3.2`; level roots are Y=0/3.2/6.4 and `Rooftop` Y=9.6. Room shell floors are commonly centered at root Y+0.06, hence manifest center Ys of 0.06/3.26/6.46. The U-shaped building is assembled from a 48×9.5 m north bar and 12×28 m west/east wings. Upper floors keep the central courtyard open.

## Mapping state definitions

- **MISSING:** no current implementation found for an approved-plan requirement.
- **BLOCKOUT:** shell-only rough geometry; no evidence of modeled use.
- **MODELED:** room shell and at least functional interior objects are generated. This does not imply successful navigation.
- **PLAYABLE:** verified with the production controller entering/reaching the usable room. Not assigned unless actually tested.
- **VISUALLY_VERIFIED:** a specific current Godot runtime view was inspected. This is scoped to that captured viewpoint, not a whole-room or parity sign-off.

All 28 rows below have room-specific runtime captures in `builds/visual-qa/rooms-audit-release-20261015-v8/` (files are numbered in the same row order). They are therefore **VISUALLY_VERIFIED at one captured view** and **MODELED**. No general room is labelled PLAYABLE solely because a capture or node exists. There is a separate manually input-driven standalone test of the Stair-C→WC route; it is not the full production story route.

## Floor 1 — Ground

| Room ID | Plan requirement / bay | Active node and center (x,y,z) | Implemented footprint | Classification / note |
|---|---|---|---:|---|
| `F1-PRINCIPAL` | Principal office, plan’s south west-wing bay | `PHÒNG HIỆU TRƯỞNG` `(-16,0,-18)` | 4×6 m | MODELED; VISUALLY_VERIFIED (`01_ground.png`). **ARCH-002:** placed in north bay, opposite plan. |
| `F1-DOAN` | Đoàn office, plan’s north west-wing bay | `PHÒNG ĐOÀN` `(-18.75,0,-8)` | 10.5×6 m | MODELED; VISUALLY_VERIFIED (`02_ground.png`). **ARCH-002:** placed in south bay, opposite plan. |
| `F1-NOTICE` | Noticeboard | `BẢNG TIN` `(-17,0,-27)` | 5×7 m | MODELED; VISUALLY_VERIFIED (`03_ground.png`). |
| `F1-CLASS-3` | Classroom 3, north bar | `LỚP HỌC 3` `(-11,0,-27)` | 7×7 m | MODELED; VISUALLY_VERIFIED (`04_ground.png`). |
| `F1-TEACHERS` | Teachers’ room, north bar | `PHÒNG GIÁO VIÊN` `(-5,0,-27)` | 5×7 m | MODELED; VISUALLY_VERIFIED (`05_ground.png`). |
| `F1-CLASS-4` | Classroom 4, north bar | `LỚP HỌC 4` `(6.5,0,-27)` | 7×7 m | MODELED; VISUALLY_VERIFIED (`06_ground.png`). |
| `F1-WC` | WC shown on floor-1 plan | `WC TẦNG 1` `(14,0,-27)` | 6×7 m | MODELED; VISUALLY_VERIFIED (`07_ground.png`). Position represented in plan. |
| `F1-CLASS-1` | Classroom 1, east wing | `LỚP HỌC 1` `(16,0,-17)` | 4×6 m | MODELED; VISUALLY_VERIFIED (`08_ground.png`). |
| `F1-CLASS-2` | Classroom 2, east wing | `LỚP HỌC 2` `(19,0,-7)` | 10×6 m | MODELED; VISUALLY_VERIFIED (`09_ground.png`). |
| `F1-STAIR-A` | Stair A, west core | `StairCoreA` base `(-21,0,-22.5)` | core approx. 5×9 m | MODELED; runtime views exist. Route to roof passes standalone; route into story gallery not fully verified. Plan axis mismatch. |
| `F1-STAIR-B` | Stair B, central/north core | `StairCoreB` base `(0,0,-22.5)` | core approx. 5×9 m | MODELED; runtime views exist. Route to level 3 reaches north gallery, but east-wing story route fails at rail. |
| `F1-STAIR-C` | Stair C, east core | `StairCoreC` base `(21,0,-22.5)` | core approx. 5×9 m | MODELED; runtime views exist. Standalone C→WC route succeeds; plan axis mismatch. |
| `F1-COURTYARD` | Courtyard, stage, fountain, flagpole and gate | `SharedGroundOnlyCourtyard` and ground objects | n/a | Ground objects occur once; source tests assert stage/fountain/flagpole each once. Gameplay traversal not a room classification. |

The office-size asymmetry is in the active code; supplied plans do not provide dimensions sufficient to establish whether it is intentional. The clear evidence is the swapped **room assignment**.

## Floor 2 — Level2 (Y=3.2 m)

| Room ID | Plan requirement / bay | Active node and center (x,y,z) | Implemented footprint | Classification / note |
|---|---|---|---:|---|
| `F2-CLUB-1` | Club 1, west wing | `PHÒNG CLB 1` `(-18.75,3.2,-15)` | 10.5×6 m | MODELED; VISUALLY_VERIFIED (`10_level2.png`). |
| `F2-CLUB-2` | Club 2, west wing | `PHÒNG CLB 2` `(-18.75,3.2,-8)` | 10.5×6 m | MODELED; VISUALLY_VERIFIED (`11_level2.png`). |
| `F2-STAFF-WC` | Teachers’ WC | `WC GIÁO VIÊN` `(-17,3.2,-27)` | 5×7 m | MODELED; VISUALLY_VERIFIED (`12_level2.png`). |
| `F2-LIBRARY` | Library | `THƯ VIỆN` `(-10,3.2,-27)` | 8×7 m | MODELED; VISUALLY_VERIFIED (`13_level2.png`). |
| `F2-CLUB-3` | Plan’s third club room | `PHÒNG CLB` `(-4,3.2,-27)` | 4×7 m | MODELED; VISUALLY_VERIFIED (`14_level2.png`). Bay exists; ordinal naming missing (ARCH-004). Chess designation source conflict is in DESIGN_CONFLICTS. |
| `F2-CHEMISTRY` | Chemistry practice room | `THỰC HÀNH HÓA` `(6,3.2,-27)` | 7×7 m | MODELED; VISUALLY_VERIFIED (`15_level2.png`). |
| `F2-STORAGE` | Storage | `NHÀ KHO` `(14,3.2,-27)` | 6×7 m | MODELED; VISUALLY_VERIFIED (`16_level2.png`). |
| `F2-PRACTICAL` | Practical room, east wing | `PHÒNG THỰC HÀNH` `(16,3.2,-17)` | 4×6 m | MODELED; VISUALLY_VERIFIED (`17_level2.png`). |
| `F2-COMPUTER` | Computer room, east wing | `PHÒNG TIN HỌC` `(19,3.2,-7)` | 10×6 m | MODELED; VISUALLY_VERIFIED (`18_level2.png`). |
| `F2-STAIR-A/B/C` | Three aligned stairs | `StairCoreA/B/C`, base X=-21/0/+21, Z=-22.5 | see staircase report | MODELED; all three cores exist. Floor-2 staff WC exists; no student WC or teachers’ room is generated here, matching the brief. |

## Floor 3 — Level3 (Y=6.4 m)

| Room ID | Plan requirement / bay | Active node and center (x,y,z) | Implemented footprint | Classification / note |
|---|---|---|---:|---|
| `F3-VOC-1` | Vocational room 1, west wing | `PHÒNG HỌC NGHỀ 1` `(-16,6.4,-18)` | 4×6 m | MODELED; VISUALLY_VERIFIED (`19_level3.png`). |
| `F3-VOC-2` | Vocational room 2, west wing | `PHÒNG HỌC NGHỀ 2` `(-18.75,6.4,-8)` | 10.5×6 m | MODELED; VISUALLY_VERIFIED (`20_level3.png`). |
| `F3-NOTICE` | Floor-3 noticeboard | `BẢNG TIN TẦNG 3` `(-17,6.4,-27)` | 5×7 m | MODELED; VISUALLY_VERIFIED (`21_level3.png`). |
| `F3-CLASS-3` | Classroom 3 | `LỚP HỌC 3` `(-11,6.4,-27)` | 7×7 m | MODELED; VISUALLY_VERIFIED (`22_level3.png`). |
| `F3-CLASS-GENERIC` | Generic classroom | `PHÒNG HỌC` `(-5,6.4,-27)` | 5×7 m | MODELED; VISUALLY_VERIFIED (`23_level3.png`). Plan does not specify its use beyond school/classroom space. |
| `F3-CLASS-4` | Classroom 4 | `LỚP HỌC 4` `(6.5,6.4,-27)` | 7×7 m | MODELED; VISUALLY_VERIFIED (`24_level3.png`). |
| `F3-CHESS` | Chess club per story/Art Bible; plan bay is unnamed | `CLB CỜ VUA` `(14,6.4,-27)` | 6×7 m | MODELED; VISUALLY_VERIFIED (`25_level3.png`). Placement has source-document gap; do not move without canonical story evidence. |
| `F3-CLASS-1` | Classroom 1, east wing | `LỚP HỌC 1` `(16,6.4,-17)` | 4×6 m | MODELED; VISUALLY_VERIFIED (`26_level3.png`). |
| `F3-CLASS-2` | Classroom 2, east wing | `LỚP HỌC 2` `(19,6.4,-7)` | 10×6 m | MODELED; VISUALLY_VERIFIED (`27_level3.png`). |
| `F3-WC-MALE` | Required by current story/audit request; absent as a labelled room from plan | `WC NAM` `(19,6.4,1)` | 10×6 m | MODELED; VISUALLY_VERIFIED (`28_level3.png` plus yaw detail). Door opens to east-wing corridor; no direct Stair C opening in source. Current standalone Stair-C→WC input route passed; production B→east route remains blocked earlier. Plan amendment is unresolved (CONFLICT_FOUND). |
| `F3-STAIR-A/B/C` | Three aligned cores and floor-3 landings | `StairCoreA/B/C` | see staircase report | MODELED. Standalone core tests pass; main-story gallery route is not complete. |

The F3 WC addition does not make the stair open directly into a restroom. The code places Classroom 1, Classroom 2, and WC Nam on the east side with a corridor opening; however, production-story access is blocked at the separate north-gallery junction before the player reaches that corridor.

## Roof

| Room ID | Plan requirement | Active node | Classification / note |
|---|---|---|---|
| `RF-SURFACE` | Open roof walks / slab | `Rooftop/North roof walk`, `West roof walk`, `East roof walk` | MODELED; captured stair-to-roof views exist. Full production movement and plan overlay not independently signed off. |
| `RF-RAILS` | Perimeter and atrium safety rails | Multiple `Rooftop/* safety rail` generated colliders | MODELED; source creates outer and atrium rails. Detailed rail safety/clearance audit remains required after circulation is reconciled. |
| `RF-STAIR-A/B/C` | Three aligned exits | Three final landings and `Stair exit -21/0/21` labels | MODELED; standalone ascent/descent test passes. Plan alignment exists in core centers; stair A/C flight axis conflicts with plan arrows. |
| `RF-UNPROGRAMMED` | No classroom, stage or function room | No such roof room generated | No extra room found in active roof builder. Ground stage remains below/at courtyard level. |

## Missing-room and access conclusions

- No clearly missing room from the named plan program was found in the active source; the main observed discrepancies are the swapped floor-1 offices, identity loss in the floor-2 club label, and the floor-3 story WC plan gap.
- Current source generates a three-story U-shaped building, one ground courtyard, three aligned stair cores, and an open upper void. This confirms geometry exists, not that all rooms/routes are playable.
- A floor-2 teachers’ room and student WC were not found; their absence matches the current requirement.
- Every captured room view is runtime evidence for that camera and frame only. Room-wide visual matching, all entrances, camera clearance, and free movement remain unverified except for explicitly documented routes.

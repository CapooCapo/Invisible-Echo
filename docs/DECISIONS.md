# Decisions

| Date | Decision | Rationale |
|---|---|---|
| 2026-10-11 | Target `~/dev/an-tieng-gay-trong-dem`, not system `/dev` | The requested project path is absent and `~/dev` is the existing development directory; `/dev` is the Linux device filesystem. |
| 2026-10-11 | Start with 2D top-down cinematic horror | User directive prefers it when it improves completion probability; installed Godot 4.7.2 supports the scope without extra engine dependencies. |
| 2026-10-11 | Keep Godot project dependency-light and use code-drawn/original assets first | No external asset license has been checked yet; avoid licensing debt while making a playable slice. |
| 2026-10-11 | Choice branches rejoin after recording consequence state | Both routes must continue; preserve branch differences for the morning and Night 2 flag without inventing Night 2 content. |
## 2026-10-11 — Chess rules implementation source

- Preflight found a pure-GDScript Godot chess rules asset under AGPLv3; its asset listing says source distribution is required unless a paid license is obtained. That does not fit the zero-cost/no-unsolicited-copyleft constraint, so it will not be vendored.
- A separate MIT Godot chess UI depends on a standalone UCI engine and Go server, so it does not fit the self-contained desktop game without extra binaries.
- Decision: implement and independently test a small in-project GDScript rules engine for the bespoke story modes; preserve license boundaries and keep the project dependency-free.

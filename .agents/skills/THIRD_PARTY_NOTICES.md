# Third-party skill sources

These project-local skills are vendored for local agent use. Their upstream source files and bundled references/scripts are preserved without modification; the local `SKILL.md` files are compatibility routers written for this project. Upstream `SKILL.md` content is stored as `UPSTREAM_SOURCE.md.txt` to keep the local router as the discovered entry point. The original relative resource paths remain intact.

## haxqer/godot-skill

- Source: [GitHub repository](https://github.com/haxqer/godot-skill), pinned revision `037c03e9858ae748bf66c010aeb9942dbe9b93d6`.
- Vendored path: [`godot/`](godot/); original skill source: [`godot/UPSTREAM_SOURCE.md.txt`](godot/UPSTREAM_SOURCE.md.txt).
- License: MIT; exact upstream license at [`godot/LICENSE`](godot/LICENSE).
- Selected because it provides broad Godot 4.7 scene, script, resource, asset, debugging, and validation workflows.

## thedivergentai/Game-Design-Agentic-Skills

- Source: [GitHub repository](https://github.com/thedivergentai/Game-Design-Agentic-Skills), pinned revision `eca389a58929b6624d5af1e857de4b76827b8802`.
- License: LGPL-3.0; exact upstream license at [`LICENSES-LGPL-3.0.txt`](LICENSES-LGPL-3.0.txt).
- Vendored skill source files: [`godot-gdscript-mastery/UPSTREAM_SOURCE.md.txt`](godot-gdscript-mastery/UPSTREAM_SOURCE.md.txt), [`godot-genre-horror/UPSTREAM_SOURCE.md.txt`](godot-genre-horror/UPSTREAM_SOURCE.md.txt), [`godot-genre-puzzle/UPSTREAM_SOURCE.md.txt`](godot-genre-puzzle/UPSTREAM_SOURCE.md.txt), and [`godot-3d-world-building/UPSTREAM_SOURCE.md.txt`](godot-3d-world-building/UPSTREAM_SOURCE.md.txt), with their upstream references and example scripts.

The local routers deliberately narrow the source guidance to the project's Godot version, architecture, story, approved school maps, and PS2-inspired horror art direction. The skills' linked peer domains are not included unless listed above.

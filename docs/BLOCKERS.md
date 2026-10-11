# Blockers

## Development

No blocker prevents continued gameplay implementation. Godot 4.7.2 is installed.

## Verification limitation

GUI/rendering QA is blocked for now: the host has no active `DISPLAY`/`WAYLAND_DISPLAY`, `Xvfb`/`xvfb-run` is absent, and the headless movie-capture attempt crashed inside Godot's dummy renderer before writing an image. The official Arch `xorg-server-xvfb` package is available, but non-interactive `sudo` requires a password, so no system package was installed. Headless code/input tests can continue, but GUI visuals, glyph coverage, and a real-player playthrough must remain `NOT VERIFIED` until a display server is available.

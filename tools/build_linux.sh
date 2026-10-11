#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="$(command -v -- "${GODOT_BIN:-godot}")"
release_name="an-tieng-gay-trong-dem-linux.x86_64"
pack_path="$project_root/builds/an-tieng-gay-trong-dem.pck"
binary_path="$project_root/builds/$release_name"

cd "$project_root"
version="$($godot_bin --headless --version)"
if [[ "$version" != 4.7.2.stable* ]]; then
	printf 'Expected Godot 4.7.2 stable; found %s\n' "$version" >&2
	exit 1
fi

mkdir -p builds
"$godot_bin" --headless --path . --editor --quit
"$godot_bin" --headless --path . --export-pack "Linux/X11" "$pack_path"
cp -- "$godot_bin" "$binary_path"
if command -v strip >/dev/null 2>&1; then
	strip --strip-unneeded "$binary_path"
fi
cat -- "$pack_path" >> "$binary_path"
chmod +x "$binary_path"
printf 'Built %s\n' "$binary_path"

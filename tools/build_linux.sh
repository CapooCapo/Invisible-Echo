#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="$(command -v -- "${GODOT_BIN:-godot}")"
release_name="an-tieng-gay-trong-dem-linux.x86_64"
pack_name="${release_name%.x86_64}.pck"
pack_path="$project_root/builds/$pack_name"
binary_path="$project_root/builds/$release_name"
template_path="${GODOT_LINUX_TEMPLATE:-$project_root/builds/templates/linux_release.x86_64}"

cd "$project_root"
version="$($godot_bin --headless --version)"
if [[ "$version" != 4.7.2.stable* ]]; then
	printf 'Expected Godot 4.7.2 stable; found %s\n' "$version" >&2
	exit 1
fi

if [[ ! -f "$template_path" ]]; then
	template_path="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable/linux_release.x86_64"
fi
if [[ ! -f "$template_path" ]]; then
	printf 'Godot 4.7.2 Linux release template not found. Set GODOT_LINUX_TEMPLATE or install the official export templates.\n' >&2
	exit 1
fi
template_version="$("$template_path" --version 2>/dev/null || true)"
if [[ "$template_version" != 4.7.2.stable* ]]; then
	printf 'Expected a Godot 4.7.2 stable Linux release template; found %s at %s\n' "${template_version:-no version output}" "$template_path" >&2
	exit 1
fi

mkdir -p builds
"$godot_bin" --headless --path . --editor --quit
"$godot_bin" --headless --path . --export-pack "Linux/X11" "$pack_path"
cp -- "$template_path" "$binary_path"
chmod +x "$binary_path"
printf 'Built %s with adjacent data pack %s\n' "$binary_path" "$pack_path"

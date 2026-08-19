# Project Skyroll

Project Skyroll is an original 3D surface-puzzle game built with Godot 4.7.1 Forward+ and Blender 5.2 LTS. Guide the horned spirit Aeri through the bright Ancient Sky Temple and across the tops, walls, and undersides of floating structures.

## Included

- 30 data-driven surface mazes across Sunken Temple, Cloud Machinery, and Ember Orbit.
- Deterministic rolling across top, side, and underside faces with local gravity, 90-degree turns, buffered input, edge wrapping, two-cell jumps, falls, ice, hazards, and collapsing faces.
- Strict timer, required keys, optional fruit, three-medal results, sequential progression, and unlimited retries.
- Main menu, story intro, world/level selection, pause, results, options, keyboard rebinding, and gamepad support.
- Versioned atomic save data and an offline platform adapter ready to be replaced by a Steam implementation.
- A 27-asset Blender-authored release kit: mossy World 1 temple stone and ruins, authored gameplay tiles, the horned-spirit Aeri, collectibles, portals, broad cloud banks, and world-specific landmarks. CC0 PBR source maps remain reproducible through the checksum-pinned asset manifest.
- Branded 512 px application icon and boot splash, custom UI, credits and license notice, atmospheric lighting, sky motes, and an original Skyroll menu backdrop. No Kula World assets are included.
- Original procedural ambient music and collectible, portal, and failure chimes routed through Music/SFX buses.

## Run

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/) and its export templates.
2. Import `project.godot` in Godot.
3. Press **F6/F5**, or run:

```powershell
godot --path .
```

Keyboard controls: `W/S` roll, `A/D` turn, `Space` jump, `R` restart, `Esc` pause. An Xbox-style controller is supported with D-pad, A, Y, Start, and right stick.

## Tests

```powershell
godot --headless --path . -s res://tests/test_runner.gd
```

The 1,699-assertion suite validates grid rules, all 30 level definitions and reachability, progression, save migration, every production GLB budget, and gameplay scene construction.

## Art pipeline

Blender 5.2 LTS source, reproducible GLB exports, asset provenance, triangle budgets, previews, and Godot validation are documented in [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md). Publishing handoff items are listed in [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/blender/build_art_pipeline.ps1
```

## Windows build

Install the matching export templates, then use the included `Windows Desktop` preset:

```powershell
godot --headless --path . --export-release "Windows Desktop"
```

The output is written to `builds/windows/ProjectSkyroll.exe`.

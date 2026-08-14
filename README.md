# Project Skyroll

Project Skyroll is an original, colorful 3D surface-puzzle game built with Godot 4.7.1. Guide Aeri across the tops, walls, and undersides of floating structures, collect every key, and reach the exit before time runs out.

## Included

- 30 data-driven surface mazes across Sunken Temple, Cloud Machinery, and Ember Orbit.
- Deterministic rolling across top, side, and underside faces with local gravity, 90-degree turns, buffered input, edge wrapping, two-cell jumps, falls, ice, hazards, and collapsing faces.
- Strict timer, required keys, optional fruit, three-medal results, sequential progression, and unlimited retries.
- Main menu, story intro, world/level selection, pause, results, options, keyboard rebinding, and gamepad support.
- Versioned atomic save data and an offline platform adapter ready to be replaced by a Steam implementation.
- A 27-asset Blender-authored release kit: three distinct block families, authored gameplay tiles, Aeri, collectibles, portals, broad cloud banks, and world-specific landmarks. Runtime art uses generated photoreal albedo scans for weathered crate wood, aged metal, and basalt, with those source images kept outside the exported runtime package.
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

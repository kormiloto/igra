# AGENT.md

## Project identity

- Project name: `Project Skyroll`
- Workspace root: `C:\Users\korisnik\Documents\Kulaworld`
- Genre: original 3D surface-puzzle / rolling-ball game inspired by the feel of PlayStation-era floating puzzle games, but using original assets and code
- Engine baseline: `Godot 4.7.1`
- Art pipeline baseline: `Blender 5.2.0 LTS`
- Primary Windows export: `builds/windows/ProjectSkyroll.exe`
- Current date context for this file: `August 12, 2026`

## High-level game summary

`Project Skyroll` is a 3D puzzle game where the player controls a rolling ball named `Aeri` across the tops, sides, and undersides of floating blocks. The game contains:

- 30 data-driven levels
- 3 worlds:
  - `Sunken Temple`
  - `Cloud Machinery`
  - `Ember Orbit`
- mechanics for rolling, turning, jumping, local gravity, falls, ice, hazards, collapse tiles, keys, optional fruit, timer, medals, progression, pause/options, save data, keyboard/gamepad

## What the user wanted from this conversation

The user repeatedly asked for the game to move away from a simple/cartoon look and toward a more professional, sale-ready, more realistic presentation. The visual direction evolved through the conversation like this:

1. Initial request: make the game look graphically better and more professional.
2. User feedback: existing shapes looked too primitive and toy-like.
3. User specifically disliked:
   - circular/target-like marks on top of blocks
   - clouds that looked like blobs or cartoon puffs
   - blocks that did not read as stone/real surfaces
   - fruit that looked like a cartoon
   - portal signs and portal silhouettes that felt weak
   - the player ball looking like a toy instead of a believable ball
4. User requested:
   - realistic textures
   - a `Blender -> Godot production pipeline`
   - a fully `sale-ready` look
   - a football / soccer-ball style player ball
5. User supplied reference images and then supplied a local folder of new designs:
   - `C:/Users/korisnik/Documents/Kulaworld/output/realistic_game_assets`
6. User later switched models multiple times in Codex and asked to continue without losing context.

## Important visual preferences from the user

The user's preferences, stated across multiple turns, should be treated as active art direction unless explicitly changed:

- "professional" and "sale-ready"
- less cartoon, less toy-like
- more like real materials "as if alive / in real life"
- stronger silhouettes visible from the gameplay camera
- fruit should feel organic, not like a stylized prop
- portals should feel designed, not generic rings or weak symbols
- clouds should not look like white blobs
- player ball should read clearly as a football / soccer ball

## User-supplied design references

The user provided a source design set now stored here:

- `assets/source/design_refs/realistic_game_assets/`

This folder contains 15 JPG reference renders plus `REFERENCE_MAP.md`.

Reference mapping:

- `01_wooden_crate` -> W1 block language
- `02_teal_orange_barrier` -> W2 trim/safety accents
- `03_copper_floor_plate` -> W1/W2 plate detail language
- `04_dark_metal_cube` -> W2 cube surface
- `05_glowing_stone_cube` -> W3 cube surface
- `06_spike_trap` -> W3 hazard spikes
- `07_red_x_pressure_pad` -> W3 collapse tile
- `08_ice_spike_plate` -> W2 ice tile
- `09_stone_sphere` -> alternate ball / stone reference
- `10_red_apple` -> Sunfruit direction
- `11_cyan_energy_orb` -> Sky Core direction
- `12_hanging_hoop_obstacle` -> landmark / obstacle silhouette
- `13_green_training_island` -> W1 landmark direction
- `14_cyan_portal_island` -> W2 portal/landmark direction
- `15_purple_crystal_island` -> W3 portal/landmark direction

These references are source-only and are not intended to ship as loose runtime art.

## Main technical work completed in this conversation

### 1. Blender-Godot production pipeline

The project already had a pipeline, but it was substantially used and pushed forward during this conversation. The main generator is:

- `tools/blender/build_environment_kit.py`

This script now builds a deterministic 27-asset release kit and exports runtime GLBs to:

- `assets/3d/environment/`

It also produces:

- `assets/3d/previews/sale_ready_kit.png`
- `assets/ui/app_icon.png`
- `assets/source/blender/skyroll_sale_ready_kit.blend`
- `assets/3d/environment/asset_report.json`

### 2. Runtime portal material fix

One important issue found during debugging: gameplay runtime code was overriding portal materials in a way that flattened or darkened the authored portal look too aggressively.

File changed:

- `scripts/grid_board.gd`

Behavior now:

- only energy-like portal surfaces are visually suppressed when inactive
- active portal visuals preserve the authored GLB materials more faithfully
- this avoids losing important portal detail in gameplay

### 3. Art direction changes implemented in assets

The Blender kit was updated to better match the user direction:

- `W1` blocks now read as weathered crate-like forms with wood/iron language instead of plain cartoon stone
- `Aeri` now reads as a football / soccer ball
- `Sunfruit` was pushed toward a more organic apple-like silhouette
- `portal_w1`, `portal_w2`, `portal_w3` were redesigned toward more authored, stronger ring/vortex presentations
- `cloud_bank_a/b/c` were pushed toward long muted cloud banks rather than round puffs
- `landmark_w2` and `landmark_w3` received stronger portal-island silhouettes
- spikes, collapse, and world materials were adjusted to better match the new reference set

### 4. Windows export cleanup

The Windows export preset was updated so that source-only folders are excluded from the final shipped build.

File changed:

- `export_presets.cfg`

Current excluded content includes:

- `tests/*`
- `tools/*`
- `output/*`
- `assets/source/*`
- `assets/3d/previews/*`
- `assets/3d/environment/asset_report.json`

## Current key files

### Project / docs

- `README.md`
- `docs/ART_PIPELINE.md`
- `docs/RELEASE_CHECKLIST.md`
- `export_presets.cfg`

### Runtime gameplay

- `scripts/grid_board.gd`
- `scripts/gameplay.gd`
- `scripts/grid_mover.gd`
- `scripts/surface_rules.gd`

### Art generation

- `tools/blender/build_environment_kit.py`
- `tools/blender/build_art_pipeline.ps1`
- `tools/blender/asset_manifest.json`

### Runtime assets

- `assets/3d/environment/*.glb`
- `assets/3d/previews/sale_ready_kit.png`
- `assets/ui/app_icon.png`

## Current art pipeline facts

- Blender source file: `assets/source/blender/skyroll_sale_ready_kit.blend`
- Runtime GLBs count: `27`
- Build report file: `assets/3d/environment/asset_report.json`
- Preview file: `assets/3d/previews/sale_ready_kit.png`
- App icon file: `assets/ui/app_icon.png`

Generated photoreal albedo inputs live in:

- `assets/source/textures/generated/`

Known generated source textures:

- `w1_terracotta_albedo.png`
- `w2_aged_metal_albedo.png`
- `w3_basalt_albedo.png`

Even though one texture name still says `terracotta`, the first world direction was pushed toward weathered crate wood using authored geometry/material treatment.

## Current runtime asset snapshot

From `assets/3d/environment/asset_report.json` as of `August 12, 2026`:

- `w1_block_a/b/c`: `3240 triangles`, `4 materials`
- `w2_block_a/b/c`: `1404 triangles`, `3 materials`
- `w3_block_a/b/c`: `540 triangles`, `2 materials`
- `w1_tile_normal`: `324 triangles`, `2 materials`
- `w2_tile_normal`: `1212 triangles`, `2 materials`
- `w2_tile_ice`: `1392 triangles`, `4 materials`
- `w3_tile_normal`: `108 triangles`, `1 material`
- `w3_tile_hazard`: `1352 triangles`, `3 materials`
- `w3_tile_collapse`: `756 triangles`, `3 materials`
- `sky_core`: `880 triangles`, `3 materials`
- `sunfruit`: `2660 triangles`, `4 materials`
- `portal_w1/w2/w3`: `2480 triangles`, `4 materials`
- `aeri`: `4948 triangles`, `3 materials`
- `cloud_bank_a`: `1208 triangles`, `2 materials`
- `cloud_bank_b`: `1000 triangles`, `2 materials`
- `cloud_bank_c`: `1016 triangles`, `2 materials`
- `landmark_w1`: `3380 triangles`, `5 materials`
- `landmark_w2`: `3550 triangles`, `6 materials`
- `landmark_w3`: `1746 triangles`, `4 materials`

## Commands used and expected workflow

### Rebuild Blender assets

Preferred one-command build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/blender/build_art_pipeline.ps1
```

Direct Blender generator call:

```powershell
blender --background --python tools/blender/build_environment_kit.py
```

### Reimport in Godot

```powershell
godot --headless --path . --import
```

### Run tests

```powershell
godot --headless --path . -s res://tests/test_runner.gd
```

### Export Windows build

```powershell
godot --headless --path . --export-release "Windows Desktop"
```

Output:

- `builds/windows/ProjectSkyroll.exe`

## Latest verification performed in this conversation

The following checks were completed successfully on `August 12, 2026`:

- Blender asset rebuild completed successfully
- Godot reimport completed successfully
- test suite passed with `1699 Skyroll surface assertions`
- Windows release export completed successfully

Latest known Windows executable at the time this file was written:

- `builds/windows/ProjectSkyroll.exe`
- timestamp observed: `August 12, 2026 11:43`

## Debugging notes discovered during this conversation

- Multiple old Godot processes were found running simultaneously at one point, which could make the user think nothing changed because an older editor/game instance was still open.
- The complaint "nothing changed" was partially explained by runtime material overrides and partially by the difference between Blender preview updates and actual in-game visibility.
- The headless preview capture script:
  - `tests/capture_world_previews.gd`
  had previously timed out in earlier work and was not the most reliable signal during this conversation.

## Files changed during this conversation

At minimum, these files were directly changed:

- `tools/blender/build_environment_kit.py`
- `scripts/grid_board.gd`
- `export_presets.cfg`
- `README.md`
- `docs/ART_PIPELINE.md`

And this file was newly created:

- `AGENT.md`

## Guidance for future agents / models

If continuing visual work on this project, keep these priorities:

1. Preserve the user's non-cartoon, sale-ready direction.
2. Prefer stronger silhouettes over subtle texture-only improvements, because the gameplay camera is relatively distant.
3. When the user says something still looks "toy-like", inspect shape language first, not only material color.
4. Rebuild through the Blender pipeline instead of hand-editing exported GLBs.
5. After art changes:
   - run Godot import
   - run tests
   - export a fresh Windows build
6. Be careful with old open Godot or EXE processes when visually validating results.
7. Treat `assets/source/design_refs/realistic_game_assets/` as the main style reference library unless the user replaces it.

## Open visual opportunities

Likely next quality improvements if the user wants to push further:

- make `W2` and `W3` block surfaces feel less clean and more materially complex
- push roughness / edge breakup further on close-visible assets
- add stronger gameplay capture verification for real in-game comparisons
- refine portal energy treatment inside authored materials for even more premium presentation
- continue iterating on fruit realism and landmark island believability if the user still feels they are not fully there


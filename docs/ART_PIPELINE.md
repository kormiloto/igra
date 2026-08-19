# Skyroll sale-ready Blender–Godot pipeline

The release art is a deterministic, editable Blender kit rather than runtime primitive placeholders. The same command rebuilds every GLB, the Aeri application icon, the visual QA sheet, and the Godot validation suite. World 1 uses the bright `Ancient Sky Temple` direction with a Forward+ desktop renderer.

The realistic design reference library is stored in `assets/source/design_refs/realistic_game_assets/`. The 15 JPG renders are source-only visual targets mapped to the Blender assets in `REFERENCE_MAP.md`; they are not shipped as flat runtime images.

## Production layout

```text
assets/
  source/
    .gdignore
    blender/skyroll_sale_ready_kit.blend
    textures/polyhaven/rough_block_wall/    # retained CC0 reference source
    textures/polyhaven/mossy_stone_wall/    # 2K CC0 W1 block/ruin PBR maps
    textures/polyhaven/rock_tile_floor/      # 2K CC0 W1 paving PBR maps
    models/polyhaven/rock_face_02_1k/        # CC0 island underside source
    models/polyhaven/fern_02_1k/             # CC0 optimized foliage source
    textures/sky/sunflowers_puresky_4k.hdr  # CC0 W1 sky/lighting source
    textures/generated/                    # photoreal albedo scans for release materials
  3d/
    environment/*.glb                       # 27 runtime assets
    environment/asset_report.json
    previews/sale_ready_kit.png
  ui/app_icon.png
tools/blender/
  asset_manifest.json
  fetch_source_assets.ps1
  build_environment_kit.py
  build_art_pipeline.ps1
```

## One-command build

Requirements: Blender 5.2 LTS, Godot 4.7.1 with matching export templates, and PowerShell 5+.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/blender/build_art_pipeline.ps1
```

The build performs these gates:

1. Verifies every retained external reference map against the pinned checksum.
2. Starts Blender from a factory-clean, headless session.
3. Rebuilds three distinct block kits, six gameplay tiles, the horned-spirit Aeri, collectibles, portals, clouds, and world landmarks.
4. Enforces per-asset triangle and material budgets from `asset_manifest.json`.
5. Renders `sale_ready_kit.png` and the transparent 512 px application icon.
6. Imports the GLBs in Godot and runs the full game test suite.

## Runtime kit

| Group | Assets | Art direction |
|---|---:|---|
| Sunken Temple | 6 | Mossy ancient stone, chipped paving, sparse foliage, cyan crystal and gold orbit details |
| Cloud Machinery | 7 | Navy machinery, cyan circuits, brass trim, prismatic ice |
| Ember Orbit | 8 | Basalt, obsidian, magma fissures, hazard and collapse states |
| Shared | 6 | Aeri, Sky Core, Sunfruit, and three broad cloud banks |

All gameplay-critical surfaces are Blender-authored. Collision and movement remain deterministic and grid-driven in Godot, so art cannot change puzzle topology.

## Source and licensing rules

- Blender source uses Z up; GLB import converts it to Godot Y up.
- Runtime assets use stable origins, applied scale, authored bevels, back-face culling, and bounded material counts.
- Raw source and the recoverable legacy kit remain under `assets/source/.gdignore` and are not included in exports.
- The retained Poly Haven reference maps are CC0 and checksum-pinned. Generated albedo scans are source-side material inputs and are not copied as loose runtime files; the GLBs embed the authored release material data.
- World 1 sources are `mossy_stone_wall`, `rock_tile_floor`, `rock_face_02`, `fern_02`, `food_apple_01`, and `sunflowers_puresky`; their URLs and checksums are pinned in `asset_manifest.json`.
- QA outputs are `output/qa/world1_ancient_sky_temple.png`, `output/qa/horned_spirit_closeup.png`, and `output/qa/world1_gameplay_forward_plus.png`.
- Forward+ keeps the full glow/SSAO/volumetric profile on discrete GPUs. Intel integrated graphics use the automatic FSR performance profile (50% internal 3D scale, three cloud meshes, no MSAA/SSAO/volumetrics/glow); the UI and QA output remain 1920x1080. The W1L05 benchmark averaged 65.7 FPS on Intel UHD Graphics 620 with VSync disabled.
- New assets require a manifest budget, a Godot resource test, Blender preview inspection, and real gameplay captures for all affected worlds.

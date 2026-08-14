# Architecture

## Runtime flow

`boot.tscn` loads `App`, which owns menus and creates a `Gameplay` instance for the selected `LevelDefinition`. Gameplay constructs a surface-face board, mover, gravity-aligned camera, lighting, and HUD at runtime.

## Data contracts

- `SurfaceCell`: one walkable face, identified by a cube coordinate and one of six axis-aligned normals.
- `LevelDefinition`: immutable runtime description containing the surface graph, intended route, local spawn orientation, keys, fruit, exit, timings, and special faces.
- `SurfaceRules`: pure face-neighbor logic for same-plane steps, convex edge wraps, concave transitions, turns, and jumps.
- `GridBoard`: authoritative surface availability and interaction lookup. Rendered cubes never determine valid movement.
- `GridMover`: Idle/Turning/Rolling/Jumping/Falling/Dead state machine carrying local `up/forward/right` orientation and a one-action input buffer.
- `SaveManager`: versioned JSON save with temporary-file replacement and migration defaults.
- `PlatformService`: offline achievements/statistics contract. A Steam adapter should preserve these method names.

## Adding authored levels

The current catalog produces 30 deterministic levels in code so the project is playable without external assets. Authored levels can replace individual `_make_level` results while retaining the same `LevelDefinition` contract and automated validation.

## Steam adapter

Replace the autoload script behind `PlatformService` with an implementation that forwards `unlock_achievement`, `set_stat`, and `flush` to the selected Godot Steamworks extension. The gameplay and UI must not reference a Steam SDK directly. Achievement identifiers are centralized in `ACHIEVEMENTS`.

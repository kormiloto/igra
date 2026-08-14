extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_surface_rules()
	_test_catalog()
	_test_progression()
	_test_save_migration()
	_test_art_pipeline()
	_test_input_buffer()
	await _test_gameplay_boot()
	if failures.is_empty():
		print("PASS: %d Skyroll surface assertions" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _test_surface_rules() -> void:
	_expect(SurfaceRules.is_orientation_valid(SurfaceRules.UP, SurfaceRules.NORTH), "Initial orientation must be valid")
	_expect(SurfaceRules.turn_right(SurfaceRules.UP, SurfaceRules.NORTH) == SurfaceRules.EAST, "Right turn must follow local up")
	_expect(SurfaceRules.turn_left(SurfaceRules.UP, SurfaceRules.NORTH) == SurfaceRules.WEST, "Left turn must follow local up")

	var same_cells := {
		SurfaceRules.cell_key(Vector3i.ZERO, SurfaceRules.UP): {"active": true},
		SurfaceRules.cell_key(SurfaceRules.NORTH, SurfaceRules.UP): {"active": true}
	}
	var same := SurfaceRules.movement_result(same_cells, Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH)
	_expect(same.found and same.transition == "same", "Adjacent coplanar face must be a same-plane step")

	var convex_cells := {
		SurfaceRules.cell_key(Vector3i.ZERO, SurfaceRules.UP): {"active": true},
		SurfaceRules.cell_key(Vector3i.ZERO, SurfaceRules.NORTH): {"active": true}
	}
	var convex := SurfaceRules.movement_result(convex_cells, Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH)
	_expect(convex.found and convex.transition == "convex", "Outer cube edge must wrap to the side face")
	_expect(convex.normal == SurfaceRules.NORTH and convex.forward == SurfaceRules.DOWN, "Convex wrap must rotate local gravity and forward")

	var concave_cells := {
		SurfaceRules.cell_key(Vector3i.ZERO, SurfaceRules.UP): {"active": true},
		SurfaceRules.cell_key(SurfaceRules.NORTH, SurfaceRules.SOUTH): {"active": true}
	}
	var concave := SurfaceRules.movement_result(concave_cells, Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH)
	_expect(concave.found and concave.transition == "concave", "Inner edge must climb the adjacent face")
	_expect(concave.normal == SurfaceRules.SOUTH and concave.forward == SurfaceRules.UP, "Concave transition must rotate orientation")

func _test_catalog() -> void:
	var levels := LevelCatalog.all_levels()
	_expect(levels.size() == 30, "Catalog must contain exactly 30 levels")
	var ids := {}
	for level in levels:
		_expect(not ids.has(level.id), "Duplicate level id: %s" % level.id)
		ids[level.id] = true
		_expect(level.cells.size() >= 6, "%s has too few surface faces" % level.id)
		_expect(level.route.size() == level.cells.size(), "%s route and surface count diverge" % level.id)
		_expect(level.time_limit > level.par_time, "%s time limit must exceed par" % level.id)
		_expect(level.keys.size() >= 2, "%s needs at least two keys" % level.id)
		_expect(level.exit_key != level.route[0], "%s exit overlaps spawn" % level.id)
		var cell_keys := {}
		var normals := {}
		for cell in level.cells:
			_expect(not cell_keys.has(cell.key()), "%s has a duplicate surface face" % level.id)
			cell_keys[cell.key()] = {"active": true}
			normals[str(cell.normal)] = true
			_expect(cell.normal.length_squared() == 1, "%s has a non-cardinal normal" % level.id)
		_expect(_objectives_reachable(level, cell_keys), "%s objectives are not reachable through the surface graph" % level.id)
		for special_key in level.special_tiles:
			_expect(special_key not in level.keys and special_key not in level.fruits, "%s special face overlaps a pickup" % level.id)
			if level.special_tiles[special_key] == "hazard":
				_expect(_hazard_is_jumpable(level, special_key, cell_keys), "%s contains a hazard that cannot be cleared by jumping" % level.id)
	var level_two_normals := {}
	for cell in levels[1].cells:
		level_two_normals[str(cell.normal)] = true
	_expect(level_two_normals.size() >= 2, "Level 2 must introduce a second gravity orientation")
	var level_three := LevelCatalog.get_level("W1L03")
	var level_three_normals := {}
	for cell in level_three.cells:
		level_three_normals[str(cell.normal)] = true
	_expect(level_three_normals.size() >= 3, "Level 3 must reach top, side, and underside orientations")

func _hazard_is_jumpable(level: LevelDefinition, hazard_key: String, cell_map: Dictionary) -> bool:
	var index := level.route.find(hazard_key)
	if index <= 0 or index >= level.route.size() - 1:
		return false
	var previous := level.cell_by_key(level.route[index - 1])
	var hazard := level.cell_by_key(hazard_key)
	var following := level.cell_by_key(level.route[index + 1])
	if previous == null or hazard == null or following == null:
		return false
	if previous.normal != hazard.normal or hazard.normal != following.normal:
		return false
	var forward := hazard.cube - previous.cube
	var jump := SurfaceRules.jump_result(cell_map, previous.cube, previous.normal, forward)
	return jump.found and jump.cube == following.cube and jump.normal == following.normal

func _objectives_reachable(level: LevelDefinition, cell_map: Dictionary) -> bool:
	var queue: Array[Dictionary] = [{"cube": level.spawn_cube, "normal": level.spawn_normal, "forward": level.spawn_forward}]
	var visited_states := {}
	var visited_cells := {}
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		var cell_key := SurfaceRules.cell_key(state.cube, state.normal)
		var state_key := "%s@%s" % [cell_key, str(state.forward)]
		if visited_states.has(state_key):
			continue
		visited_states[state_key] = true
		visited_cells[cell_key] = true
		for turned_forward in [
			SurfaceRules.turn_left(state.normal, state.forward),
			SurfaceRules.turn_right(state.normal, state.forward)
		]:
			queue.append({"cube": state.cube, "normal": state.normal, "forward": turned_forward})
		for direction_sign in [-1, 1]:
			var result := SurfaceRules.movement_result(cell_map, state.cube, state.normal, state.forward, direction_sign)
			if result.found:
				queue.append({"cube": result.cube, "normal": result.normal, "forward": result.forward})
		var jump := SurfaceRules.jump_result(cell_map, state.cube, state.normal, state.forward)
		if jump.found:
			queue.append({"cube": jump.cube, "normal": jump.normal, "forward": jump.forward})
	for target in level.keys + level.fruits + [level.exit_key]:
		if not visited_cells.has(target):
			return false
	return true

func _test_progression() -> void:
	_expect(LevelCatalog.next_level_id("W1L01") == "W1L02", "Levels must unlock sequentially")
	_expect(LevelCatalog.next_level_id("W1L10") == "W2L01", "World completion must unlock the next world")
	_expect(LevelCatalog.next_level_id("W3L10").is_empty(), "Final level must not unlock an invalid level")
	_expect(LevelCatalog.get_level("W9L99") == null, "Unknown ids must be rejected")

func _test_save_migration() -> void:
	var manager = load("res://autoload/save_manager.gd").new()
	var migrated: Dictionary = manager._migrate_and_merge({
		"version": 0,
		"unlocked_levels": ["W1L01", "W1L02"],
		"results": {"W1L01": {"completed": true, "medals": 2}},
		"settings": {"master_volume": 0.5}
	})
	_expect(migrated.version == manager.SAVE_VERSION, "Save migration must update version")
	_expect(migrated.unlocked_levels.size() == 2, "Save migration must retain unlocks")
	_expect(is_equal_approx(migrated.settings.master_volume, 0.5), "Save migration must retain settings")
	manager.free()

func _test_art_pipeline() -> void:
	var assets := {
		"res://assets/3d/environment/w1_block_a.glb": 3500,
		"res://assets/3d/environment/w1_block_b.glb": 3500,
		"res://assets/3d/environment/w1_block_c.glb": 3500,
		"res://assets/3d/environment/w2_block_a.glb": 4500,
		"res://assets/3d/environment/w2_block_b.glb": 4500,
		"res://assets/3d/environment/w2_block_c.glb": 4500,
		"res://assets/3d/environment/w3_block_a.glb": 4000,
		"res://assets/3d/environment/w3_block_b.glb": 4000,
		"res://assets/3d/environment/w3_block_c.glb": 4000,
		"res://assets/3d/environment/w1_tile_normal.glb": 3000,
		"res://assets/3d/environment/w2_tile_normal.glb": 3500,
		"res://assets/3d/environment/w2_tile_ice.glb": 4000,
		"res://assets/3d/environment/w3_tile_normal.glb": 3000,
		"res://assets/3d/environment/w3_tile_hazard.glb": 4000,
		"res://assets/3d/environment/w3_tile_collapse.glb": 3500,
		"res://assets/3d/environment/sky_core.glb": 4500,
		"res://assets/3d/environment/sunfruit.glb": 3500,
		"res://assets/3d/environment/portal_w1.glb": 5500,
		"res://assets/3d/environment/portal_w2.glb": 5500,
		"res://assets/3d/environment/portal_w3.glb": 5500,
		"res://assets/3d/environment/aeri.glb": 7000,
		"res://assets/3d/environment/cloud_bank_a.glb": 8000,
		"res://assets/3d/environment/cloud_bank_b.glb": 8000,
		"res://assets/3d/environment/cloud_bank_c.glb": 8000,
		"res://assets/3d/environment/landmark_w1.glb": 14000,
		"res://assets/3d/environment/landmark_w2.glb": 14000,
		"res://assets/3d/environment/landmark_w3.glb": 14000
	}
	for path in assets:
		_expect(ResourceLoader.exists(path), "Missing production art asset: %s" % path)
		var scene := load(path) as PackedScene
		_expect(scene != null, "Art asset must import as PackedScene: %s" % path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		var stats := _mesh_stats(instance)
		_expect(stats.meshes > 0, "Art asset contains no mesh: %s" % path)
		_expect(stats.triangles > 0 and stats.triangles <= int(assets[path]), "%s triangle budget exceeded: %d/%d" % [path, stats.triangles, assets[path]])
		instance.free()

func _mesh_stats(node: Node) -> Dictionary:
	var stats := {"meshes": 0, "triangles": 0}
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			stats.meshes += 1
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var arrays := mesh_instance.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				stats.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	for child in node.get_children():
		var child_stats := _mesh_stats(child)
		stats.meshes += child_stats.meshes
		stats.triangles += child_stats.triangles
	return stats

func _test_input_buffer() -> void:
	var board := GridBoard.new()
	board.cells = {
		SurfaceRules.cell_key(Vector3i.ZERO, SurfaceRules.UP): {"active": true},
		SurfaceRules.cell_key(SurfaceRules.EAST, SurfaceRules.UP): {"active": true}
	}
	root.add_child(board)
	var mover := GridMover.new()
	mover.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(mover)
	mover.setup(LevelCatalog.get_level("W1L01"), board)
	mover.request_action("right")
	mover.request_action("forward")
	_expect(mover.buffered_action == "forward", "Busy mover must buffer one action")
	mover._update_action(1.0)
	_expect(mover.state == GridMover.MoveState.ROLLING, "Buffered action must begin after turning")
	mover._update_action(1.0)
	_expect(mover.surface_cube == SurfaceRules.EAST, "Buffered roll must finish on the exact surface cell")
	mover.free()
	board.free()

func _test_gameplay_boot() -> void:
	var gameplay := Gameplay.new()
	gameplay.setup(LevelCatalog.get_level("W1L03"))
	gameplay.process_mode = Node.PROCESS_MODE_DISABLED
	gameplay.audio_enabled = false
	root.add_child(gameplay)
	await process_frame
	await process_frame
	_expect(gameplay.board != null, "Gameplay must create a surface board")
	_expect(gameplay.player != null, "Gameplay must create Aeri")
	_expect(gameplay.camera != null and gameplay.camera.current, "Gameplay must create an active gravity-aligned camera")
	_expect(gameplay.board.key_pickups.size() == gameplay.level.keys.size(), "Gameplay must spawn every key")
	_expect(gameplay.player.visual != null and gameplay.player.visual.name == "Aeri", "Gameplay must use the authored Aeri model")
	_expect(gameplay.board.exit_holder != null, "Gameplay must instantiate the authored world portal")
	gameplay.free()
